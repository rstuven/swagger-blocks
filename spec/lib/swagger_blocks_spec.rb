require 'json'
require 'swagger/blocks'

# Test data originally based on the Swagger UI example data:
# https://github.com/wordnik/swagger-codegen/blob/master/src/test/resources/petstore-1.2/api-docs
RESOURCE_LISTING_JSON = open(File.expand_path('../swagger_resource_listing.json', __FILE__)).read
# https://github.com/wordnik/swagger-codegen/blob/master/src/test/resources/petstore-1.2/pet
API_DECLARATION_JSON = open(File.expand_path('../swagger_api_declaration.json', __FILE__)).read

class PetController
  include Swagger::Blocks

  swagger_root swaggerVersion: '1.2'do
    apiVersion '1.0.0'
    info title: 'Swagger Sample App' do
      description "This is a sample server Petstore server.  You can find out more about Swagger \n    at <a href=\"http://swagger.wordnik.com\">http://swagger.wordnik.com</a> or on irc.freenode.net, #swagger.  For this sample,\n    you can use the api key \"special-key\" to test the authorization filters"
      termsOfServiceUrl 'http://helloreverb.com/terms/'
      keys \
        contact: 'apiteam@wordnik.com',
        license: 'Apache 2.0'
      licenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html'
    end
    api path: '/pet', description: 'Operations about pets'
    api do
      path '/user'
      description 'Operations about user'
    end
    api do
      path '/store'
      description 'Operations about store'
    end
    authorization :oauth2, type: 'oauth2' do
      scope scope: 'email', description: 'Access to your email address'
      scope do
        scope 'pets'
        description 'Access to your pets'
      end
      grant_type :implicit, tokenName: 'access_token' do
        login_endpoint do
          url 'http://petstore.swagger.wordnik.com/oauth/dialog'
        end
      end
      grant_type :authorization_code do
        token_request_endpoint clientSecretName: 'client_secret' do
          url 'http://petstore.swagger.wordnik.com/oauth/requestToken'
          clientIdName 'client_id'
        end
        token_endpoint tokenName: 'access_code' do
          url 'http://petstore.swagger.wordnik.com/oauth/token'
        end
      end
    end
  end

  # All swagger_api_root declarations with the same key will be merged.
  swagger_api_root :pets, swaggerVersion: '1.2' do
    apiVersion '1.0.0'
    basePath 'http://petstore.swagger.wordnik.com/api'
    resourcePath '/pet'
    produces [
      'application/json',
      'application/xml',
      'text/plain',
      'text/html',
    ]
    api do
      path '/pet/{petId}'
      operation method: 'GET' do
        summary 'Find pet by ID'
        notes 'Returns a pet based on ID'
        type :Pet
        nickname :getPetById
        parameter name: :petId do
          paramType :path
          description 'ID of pet that needs to be fetched'
          required true
          type :integer
          format :int64
          minimum '1.0'
          maximum '100000.0'
        end
        response_message do
          key :code, 400
          key :message, 'Invalid ID supplied'
        end
        response_message do
          key :code, 404
          key :message, 'Pet not found'
        end
      end
    end
  end

  swagger_api_root :pets do
    api do
      path '/pet/{petId}'
      operation method: 'PATCH' do
        summary 'partial updates to a pet'
        notes ''
        type :array
        nickname :partialUpdate
        items '$ref': :Pet
        produces [
          'application/json',
          'application/xml',
        ]
        consumes [
          'application/json',
          'application/xml',
        ]
        authorization :oauth2 do
          scope do
            scope 'test:anything'
            description 'anything'
          end
        end
        parameter :petId, paramType: :path do
          description 'ID of pet that needs to be fetched'
          required true
          type :string
        end
        parameter :body do
          paramType :body
          description 'Pet object that needs to be added to the store'
          required true
          type :Pet
        end
        response_message code: 400 do
          key :message, 'Invalid tag value'
        end
      end
    end
  end

  swagger_api_root :pets do
    api do
      path '/pet/findByStatus'
      operation method: 'GET' do
        summary 'Finds Pets by status'
        notes 'Multiple status values can be provided with comma seperated strings'
        type :array
        nickname :findPetsByStatus
        items :'$ref' => :Pet
        parameter :status do
          paramType :query
          description 'Status values that need to be considered for filter'
          defaultValue 'available'
          required true
          type :string
          enum [
            'available',
            'pending',
            'sold',
          ]
        end
        response_message code: 400, message: 'Invalid status value'
      end
    end
  end
end


class StoreController
  include Swagger::Blocks

  swagger_api_root :stores do
    api do
      path '/store'
    end
  end
end


class UserController
  include Swagger::Blocks

  swagger_api_root :users do
    api do
      path '/user'
    end
  end
end


class TagModel
  include Swagger::Blocks

  swagger_model :Tag do
    id :Tag
    property :id do
      type :integer
      format :int64
    end
    property :name do
      type :string
    end
  end
end


class OtherModelsContainer
  include Swagger::Blocks

  swagger_model :Pet, id: :Pet do
    required [:id, :name]
    property :id do
      type :integer
      format :int64
      description 'unique identifier for the pet'
      minimum '0.0'
      maximum '100.0'
    end
    property :category, '$ref': :Category
    property :name do
      type :string
    end
    property :photoUrls do
      type :array
      items do
        type :string
      end
    end
    property :tags do
      type :array
      items '$ref': :Tag
    end
    property :status do
      type :string
      description 'pet status in the store'
      enum [:available, :pending, :sold]
    end
  end

  swagger_model :Category do
    id :Category
    property :id do
      type :integer
      format :int64
    end
    property :name do
      type :string
    end
  end
end


class BlankController; end


describe 'Swagger::Blocks v1' do
  describe 'build_root_json' do
    it 'outputs the correct data' do
      swaggered_classes = [
        PetController,
        UserController,
        StoreController,
        TagModel,
        OtherModelsContainer,
      ]
      actual = Swagger::Blocks.build_root_json(swaggered_classes)

      # Multiple expectations for better test diff output.
      actual = JSON.parse(actual.to_json)  # For access consistency.
      data = JSON.parse(RESOURCE_LISTING_JSON)
      expect(actual['info']).to eq(data['info'])
      expect(actual['authorizations']).to eq(data['authorizations'])
      actual['apis'].each_with_index do |api_data, i|
        expect(api_data).to eq(data['apis'][i])
      end
      expect(actual).to eq(data)
    end
    it 'is idempotent' do
      swaggered_classes = [PetController, UserController, StoreController]
      actual = JSON.parse(Swagger::Blocks.build_root_json(swaggered_classes).to_json)
      actual = JSON.parse(Swagger::Blocks.build_root_json(swaggered_classes).to_json)
      data = JSON.parse(RESOURCE_LISTING_JSON)
      expect(actual).to eq(data)
    end
    it 'errors if no swagger_root is declared' do
      expect {
        Swagger::Blocks.build_root_json([])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
    it 'errors if mulitple swagger_roots are declared' do
      expect {
        Swagger::Blocks.build_root_json([PetController, PetController])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
    it 'does not error if given non-swaggered classes' do
      Swagger::Blocks.build_root_json([PetController, BlankController])
    end
  end
  describe 'build_api_json' do
    it 'outputs the correct data' do
      swaggered_classes = [
        PetController,
        UserController,
        StoreController,
        TagModel,
        OtherModelsContainer,
      ]
      actual = Swagger::Blocks.build_api_json(:pets, swaggered_classes)

      # Multiple expectations for better test diff output.
      actual = JSON.parse(actual.to_json)  # For access consistency.
      data = JSON.parse(API_DECLARATION_JSON)
      expect(actual['apis'][0]).to be
      expect(actual['apis'][0]['operations']).to be
      expect(actual['apis'][0]['operations'][0]).to be
      expect(actual['apis'][0]['operations'][1]).to be
      expect(actual['apis'][0]['operations'][0]).to eq(data['apis'][0]['operations'][0])
      expect(actual['apis'][0]['operations'][1]).to eq(data['apis'][0]['operations'][1])
      expect(actual['apis'][0]['operations']).to eq(data['apis'][0]['operations'])
      expect(actual['apis']).to eq(data['apis'])
      expect(actual['models']).to eq(data['models'])
      expect(actual).to eq(data)
    end
    it 'is idempotent' do
      swaggered_classes = [
        PetController,
        UserController,
        StoreController,
        TagModel,
        OtherModelsContainer,
      ]
      actual = JSON.parse(Swagger::Blocks.build_api_json(:pets, swaggered_classes).to_json)
      actual = JSON.parse(Swagger::Blocks.build_api_json(:pets, swaggered_classes).to_json)
      data = JSON.parse(API_DECLARATION_JSON)
      expect(actual).to eq(data)
    end
    it 'errors if no swagger_root is declared' do
      expect {
        Swagger::Blocks.build_root_json([])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
    it 'errors if multiple swagger_roots are declared' do
      expect {
        Swagger::Blocks.build_root_json([PetController, PetController])
      }.to raise_error(Swagger::Blocks::DeclarationError)
    end
  end
end
