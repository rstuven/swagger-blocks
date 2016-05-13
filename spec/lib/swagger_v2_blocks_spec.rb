require 'json'
require 'swagger/blocks'

# TODO Test data originally based on the Swagger UI example data

RESOURCE_LISTING_JSON_V2 = open(File.expand_path('../swagger_v2_api_declaration.json', __FILE__)).read

class PetControllerV2
  include Swagger::Blocks

  swagger_root host: 'petstore.swagger.wordnik.com' do
    swagger '2.0'
    info version: '1.0.0' do
      title 'Swagger Petstore'
      description 'A sample API that uses a petstore as an example to ' \
                        'demonstrate features in the swagger-2.0 specification'
      termsOfService 'http://helloreverb.com/terms/'
      contact name: 'Wordnik API Team'
      license name: 'MIT'
    end
    basePath '/api'
    schemes ['http']
    consumes ['application/json']
    produces ['application/json']
    security_definition :api_key, type: :apiKey, name: :api_key, in: :header
    security_definition :petstore_auth do
      type :oauth2
      authorizationUrl 'http://swagger.io/api/oauth/dialog'
      flow :implicit
      scopes 'write:pets' => 'modify pets in your account' do
        key 'read:pets', 'read your pets'
      end
    end
    tag name: 'pet' do
      description 'Pets operations'
      externalDocs do
        description 'Find more info here'
        url 'https://swagger.io'
      end
    end
  end

  swagger_path '/pets' do
    operation :get do
      description 'Returns all pets from the system that the user has access to'
      operationId 'findPets'
      produces [
        'application/json',
        'application/xml',
        'text/xml',
        'text/html',
      ]
      parameter :tags, in: :query, required: false do
        description 'tags to filter by'
        type :array
        items do
          type :string
        end
        collectionFormat :csv
      end
      parameter :limit, in: :query, required: false, type: :integer do
        description 'maximum number of results to return'
        format :int32
      end
      response 200 do
        description 'pet response'
        schema type: :array do
          items '$ref': :Pet
        end
      end
      response :default do
        description 'unexpected error'
        schema '$ref': :ErrorModel
      end
    end
    operation :post do
      description 'Creates a new pet in the store.  Duplicates are allowed'
      operationId 'addPet'
      produces [
        'application/json'
      ]
      parameter :pet, in: :body do
        description 'Pet to add to the store'
        required true
        schema '$ref': :PetInput
      end
      response 200 do
        description 'pet response'
        # Wrong form here, but checks that #/ strings are not transformed.
        schema '$ref': '#/parameters/Pet'
      end
      response :default, description: 'unexpected error' do
        schema '$ref': :ErrorModel
      end
    end
  end

  swagger_path '/pets/{id}' do
    parameter name: :id, in: :path do
      description 'ID of pet'
      required true
      type :integer
      format :int64
    end
    operation :get do
      description 'Returns a user based on a single ID, if the user does not have access to the pet'
      operationId 'findPetById'
      produces [
        'application/json',
        'application/xml',
        'text/xml',
        'text/html',
      ]
      response 200 do
        description 'pet response'
        schema'$ref': :Pet
      end
      response :default do
        description 'unexpected error'
        schema '$ref': :ErrorModel
      end
      security api_key: []
      security do
        key :petstore_auth, ['write:pets', 'read:pets']
      end
    end
    operation :delete do
      description 'deletes a single pet based on the ID supplied'
      operationId 'deletePet'
      response 204 do
        description 'pet deleted'
      end
      response :default do
        description 'unexpected error'
        schema '$ref': :ErrorModel
      end
    end
  end

end

class PetV2
  include Swagger::Blocks

  swagger_schema :Pet, required: [:id, :name] do
    property :id do
      type :integer
      format :int64
    end
    property :name do
      type :string
    end
    property :colors do
      type :array
      items do
        type :string
      end
    end
  end

  swagger_schema :PetInput do
    allOf do
      schema '$ref': :Pet
      schema do
        required [:name]
        property :id do
          type :integer
          format :int64
        end
        property :name do
          type :string
        end
        property :nestedObject do
          type :object
          property :name do
            type :string
          end
        end
        property :arrayOfObjects do
          type :array
          items do
            type :object
            property :name do
              type :string
            end
            property :age do
              type :integer
            end
          end
        end
      end
    end
  end
end

class ErrorModelV2
  include Swagger::Blocks

  swagger_schema :ErrorModel do
    required [:code, :message]
    property :code do
      type :integer
      format :int32
    end
    property :message do
      type :string
    end
  end
end

describe 'Swagger::Blocks v2' do
  describe 'build_json' do
    it 'outputs the correct data' do
      swaggered_classes = [
        PetControllerV2,
        PetV2,
        ErrorModelV2
      ]
      actual = Swagger::Blocks.build_root_json(swaggered_classes)
      actual = JSON.parse(actual.to_json)  # For access consistency.
      data = JSON.parse(RESOURCE_LISTING_JSON_V2)

      # Multiple expectations for better test diff output.
      expect(actual['info']).to eq(data['info'])
      expect(actual['paths']).to be
      expect(actual['paths']['/pets']).to be
      expect(actual['paths']['/pets']).to eq(data['paths']['/pets'])
      expect(actual['paths']['/pets/{id}']).to be
      expect(actual['paths']['/pets/{id}']['get']).to be
      expect(actual['paths']['/pets/{id}']['get']).to eq(data['paths']['/pets/{id}']['get'])
      expect(actual['paths']).to eq(data['paths'])
      expect(actual['definitions']).to eq(data['definitions'])
      expect(actual).to eq(data)
    end
    it 'is idempotent' do
      swaggered_classes = [PetControllerV2, PetV2, ErrorModelV2]
      actual = JSON.parse(Swagger::Blocks.build_root_json(swaggered_classes).to_json)
      actual = JSON.parse(Swagger::Blocks.build_root_json(swaggered_classes).to_json)
      data = JSON.parse(RESOURCE_LISTING_JSON_V2)
      expect(actual).to eq(data)
    end
    it 'errors if no swagger_root is declared' do
      expect {
        Swagger::Blocks.build_root_json([])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
    it 'errors if mulitple swagger_roots are declared' do
      expect {
        Swagger::Blocks.build_root_json([PetControllerV2, PetControllerV2])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
    it 'errors if calling build_api_json' do
      expect {
        Swagger::Blocks.build_api_json('fake', [PetControllerV2])
      }.to raise_error(Swagger::Blocks::NotSupportedError)
    end
  end
end
