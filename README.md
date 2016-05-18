# Swagger::Blocks

[![Build Status](https://travis-ci.org/fotinakis/swagger-blocks.svg?branch=master)](https://travis-ci.org/fotinakis/swagger-blocks)
[![Gem Version](https://badge.fury.io/rb/swagger-blocks.svg)](http://badge.fury.io/rb/swagger-blocks)

Swagger::Blocks is a DSL for pure Ruby code blocks that can be turned into JSON.

It helps you write API docs in the [Swagger](https://helloreverb.com/developers/swagger) style in Ruby and then automatically build JSON that is compatible with [Swagger UI](http://petstore.swagger.wordnik.com/#!/pet).

## Features

* Supports **live updating** by design. Change code, refresh your API docs.
* **Works with all Ruby web frameworks** including Rails, Sinatra, etc.
* **100% support** for all features of the [Swagger 2.0](https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md) and [Swagger 1.2](https://github.com/wordnik/swagger-spec/blob/master/versions/1.2.md) specs.
* Flexible—you can use Swagger::Blocks anywhere, split up blocks to fit your style preferences, etc. Since it's pure Ruby and serves definitions dynamically, you can easily use initializers/config objects to change values or even **show different APIs based on environment**.
* 1:1 naming with the Swagger spec—block names and nesting should match almost exactly with the swagger spec, with rare exceptions to make things more convenient.

## Swagger UI demo

http://petstore.swagger.io/

![swagger-sample](https://cloud.githubusercontent.com/assets/75300/5822830/4769805c-a08c-11e4-9efe-d57cf0f752e0.png)

## Installation

Add this line to your application's Gemfile:

    gem 'swagger-blocks'

Or install directly with `gem install swagger-blocks`.

## Swagger 2.0 example (Rails)

This is a simplified example based on the objects in the Petstore [Swagger Sample App](http://petstore.swagger.wordnik.com/#!/pet). For a more complex and complete example, see the [swagger_v2_blocks_spec.rb](https://github.com/fotinakis/swagger-blocks/blob/master/spec/lib/swagger_v2_blocks_spec.rb) file, or see the [v1.2 docs](https://github.com/fotinakis/swagger-blocks/blob/master/README_v1_2.md).

Also note that **Rails is not required**, you can use Swagger::Blocks in plain Ruby objects.

### PetsController

```Ruby
class PetsController < ActionController::Base
  include Swagger::Blocks

  swagger_path '/pets/{id}' do
    operation :get do
      description 'Returns a single pet if the user has access'
      operationId 'findPetById'
      tags [
        'pet'
      ]
      parameter :id, in: :path do
        description 'ID of pet to fetch'
        required true
        type :integer
        format :int64
      end
      response 200 do
        description 'pet response'
        schema '$ref': :Pet
      end
      response :default do
        description 'unexpected error'
        schema '$ref': :ErrorModel
      end
    end
  end
  swagger_path '/pets' do
    operation :get do
      description 'Returns all pets from the system that the user has access to'
      operationId 'findPets'
      produces [
        'application/json',
        'text/html',
      ]
      tags [
        'pet'
      ]
      parameter :tags, in: :query do
        description 'tags to filter by'
        required false
        type :array
        items do
          type :string
        end
        collectionFormat :csv
      end
      parameter :limit, in: :query do
        description 'maximum number of results to return'
        required false
        type :integer
        format :int32
      end
      response 200 do
        description 'pet response'
        schema do
          type :array
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
      tags [
        'pet'
      ]
      parameter :pet, in: :body do
        description 'Pet to add to the store'
        required true
        schema '$ref': :PetInput
      end
      response 200 do
        description 'pet response'
        schema '$ref': :Pet
      end
      response :default do
        description 'unexpected error'
        schema '$ref': :ErrorModel
      end
    end
  end

  # ...
end
```

### Models

#### Pet model

```Ruby
class Pet < ActiveRecord::Base
  include Swagger::Blocks

  swagger_schema :Pet do
    required [:id, :name]
    property :id do
      type :integer
      format :int64
    end
    property :name do
      type :string
    end
    property :tag do
      type :string
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
      end
    end
  end

  # ...
end
```

#### Error model

``` Ruby
class ErrorModel  # Notice, this is just a plain ruby object.
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
```

### Docs controller

To integrate these definitions with Swagger UI, we need a docs controller that can serve the JSON definitions.

```Ruby
resources :apidocs, only: [:index]
```

```Ruby
class ApidocsController < ActionController::Base
  include Swagger::Blocks

  swagger_root do
    swagger '2.0'
    info do
      version '1.0.0'
      title 'Swagger Petstore'
      description 'A sample API that uses a petstore as an example to ' \
                        'demonstrate features in the swagger-2.0 specification'
      termsOfService 'http://helloreverb.com/terms/'
      contact name: 'Wordnik API Team' do
        url 'http://developer.wordnik.com'
      end
      license name: 'MIT' do
      end
    end
    tag name: 'pet' do
      description 'Pets operations'
      externalDocs do
        description 'Find more info here'
        url 'https://swagger.io'
      end
    end
    host 'petstore.swagger.wordnik.com'
    basePath '/api'
    consumes ['application/json']
    produces ['application/json']
  end

  # A list of all classes that have swagger_* declarations.
  SWAGGERED_CLASSES = [
    PetsController,
    Pet,
    ErrorModel,
    self,
  ].freeze

  def index
    render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
  end
end
```

The special part of this controller is this line:

```Ruby
render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
```

That is the only line necessary to build the full [root Swagger object](https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#schema) JSON and all definitions underneath it. You simply pass in a list of all the "swaggered" classes in your app.

Now, simply point Swagger UI at `/apidocs` and everything should Just Work™. If you change any of the Swagger block definitions, you can simply refresh Swagger UI to see the changes.

### Security handling

To support Swagger's definitions for API key auth or OAuth2, use `security_definition` in your `swagger_root`:

```Ruby
  swagger_root do
    swagger '2.0'

    # ...

    security_definition :api_key, in: :header do
      type :apiKey
    end
    security_definition :petstore_auth do
      type :oauth2
      authorizationUrl 'http://swagger.io/api/oauth/dialog'
      flow :implicit
      scopes do
        key 'write:pets', 'modify pets in your account'
        key 'read:pets', 'read your pets'
      end
    end
  end
```

You can then apply [security requirement objects](https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#securityRequirementObject) to the entire `swagger_root`, or to individual operations:

```Ruby
  swagger_path '/pets/{id}' do
    operation :get do

      # ...

      security do
        key :api_key, []
      end
      security do
        key :petstore_auth, ['write:pets', 'read:pets']
      end
    end
  end
```

#### Nested complex objects

The `key` block simply takes the value you give and puts it directly into the final JSON object. So, if you need to set more complex objects, you can just do:

```ruby
  key :foo, {some_complex: {nested_object: true}}
```

#### Inline keys

It is possible to omit numerous `key` calls using inline hash keys on any block.

All three calls are equivalent:

```ruby
parameter do
  key :paramType, :path
  key :name, :petId
  key :description, 'ID of pet that needs to be fetched'
  key :type, :string
end
```

```ruby
parameter name: :petId, paramType: :path do
  key :description, 'ID of pet that needs to be fetched'
  key :type, :string
end
```

```ruby
parameter paramType: :path,
          name: :petId,
          description: 'ID of pet that needs to be fetched',
          type: :string
```

These inline keys can be used on any block, not just `parameter` blocks.

#### Key methods

Also, there are methods defined for most keys (exceptions are `$ref` `name`, `method` and `in`).

The following call is equivalent to the calls in the previous section.

```ruby
parameter :petId do
  paramType :path
  description 'ID of pet that needs to be fetched'
  type :string
end
```

#### Writing JSON to a file

If you are not serving the JSON directly and need to write it to a file for some reason, you can easily use `build_root_json` for that as well:

```Ruby
swagger_data = Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
File.open('swagger.json', 'w') { |file| file.write(swagger_data.to_json) }
```

#### Overriding attributes

If certain attributes must be customized on-the-fly, you can merge a hash containing the customized values on the returned JSON. You can wrap ```build_root_json``` inside your own method:

```Ruby
def build_and_override_root_json(overrides = {})
  Swagger::Blocks.build_root_json(SWAGGERED_CLASSES).merge(overrides)
end
```

### Swagger 1.2 example (Rails)

See the [v1.2 docs](https://github.com/fotinakis/swagger-blocks/blob/master/README_v1_2.md).

## Reference

See the [swagger_v2_blocks_spec.rb](https://github.com/fotinakis/swagger-blocks/blob/master/spec/lib/swagger_v2_blocks_spec.rb) for examples of more complex features and declarations possible.

## Contributing

1. Fork it ( https://github.com/fotinakis/swagger-blocks/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

Throw a ★ on it! :)

## Filing issues

**Please DO [file an issue](https://github.com/fotinakis/swagger-blocks/issues)**:

- If you find a bug or some part of the Swagger 2.0 spec that swagger-blocks does not support.
- To propose and discuss a code change before submitting a PR for it.
- To talk about anything related specifically to swagger-blocks, not Swagger itself.

**Please DO NOT file an issue**:

- If you have a question about Swagger or Swagger UI. We simply cannot support all Swagger-related questions. Check out the http://swagger.io/community/ for help.

## Release notes

* v1.3.3: Bugfix to allow `parameter` inside `swagger_path`.
* v1.3.2: Bugfix to allow `property` inside `items` for rare extended schema uses.
* v1.3.1: Bugfix to allow nested objects via `property` nested in `property`.
* v1.3.0: Added support for condensed syntax via inline keys on every block.
* v1.2.0: Improved support for `$ref` Path Item Object parameters.
* v1.1.3: Rename tags directive to tag for consistency.
* v1.1.2: Bugfix for security definition support.
* v1.1.1: Bugfix for tags node support.
* v1.1: Support for Swagger 2.0 spec.
* v1.0.1: Make backwards-compatible with Ruby 1.9.3.
* v1.0.0: Initial major release.

## Credits

Thanks to [@ali-graham](https://github.com/ali-graham) for contributing support for Swagger 2.0.

Original idea inspired by [@richhollis](https://github.com/richhollis/)'s [swagger-docs](https://github.com/richhollis/swagger-docs/) gem.
