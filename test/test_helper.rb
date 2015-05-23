require 'active_support/core_ext/string/inflections'
require 'factory_girl'
require 'faker'
require 'simplecov'
require 'minitest/autorun'
require 'webmock/minitest'

require File.expand_path(File.join(File.dirname(__FILE__), '../test/factories'))
require File.expand_path(File.join(File.dirname(__FILE__), '../test/support/response'))

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'blockscore'

WebMock.disable_net_connect!(:allow => 'codeclimate.com')

HEADERS = {
  'Accept' => 'application/vnd.blockscore+json;version=4',
  'User-Agent' => 'blockscore-ruby/4.1.0 (https://github.com/BlockScore/blockscore-ruby)',
  'Content-Type' => 'application/json'
}

def without_authentication
  BlockScore.api_key(nil) # clear API key
end

def with_authentication
  BlockScore.api_key('sk_test_a1ed66cc16a7cbc9f262f51869da31b3')
end

def create_candidate
  create_resource(:candidate)
end

def create_company
  create_resource(:company)
end

def create_person
  create_resource(:person)
end

def create_question_set
  person = create_person
  create_resource(:question_set)
end

def create_resource(resource)
  params = FactoryGirl.create(resource)
  resource_to_class(resource).create(params)
end

# Convert a resource into the corresponding BlockScore class.
def resource_to_class(resource)
  "BlockScore::#{resource.to_s.camelcase}".constantize
end

# configure test-unit for FactoryGirl
class Minitest::Test
  include WebMock::API
  include FactoryGirl::Syntax::Methods

  def setup
    with_authentication

    stub_request(:any, /.*api\.blockscore\.com\/.*/).
      with(headers: HEADERS).
      to_return do |request|
        check_uri_for_api_key(request.uri)

        resource, id, action = request.uri.path.split('/').tap(&:shift)
        factory_name = resource_from_uri(resource)

        if FactoryGirl.factories[factory_name].nil?
          raise ArgumentError, "could not find factory #{factory_name.inspect}."
        end

        handle_test_response request, id, action, factory_name
      end
  end
end

module ResourceTest
  def self.included(base)
    base.mattr_accessor :resource
    base.resource = base.to_s[/^(\w+)ResourceTest/, 1].underscore
  end

  def test_create_resource
    response = create_resource(resource)
    assert_equal response.class, resource_to_class(resource)
  end

  def test_retrieve_resource
    r = create_resource(resource)
    response = resource_to_class(resource).send(:retrieve, r.id)
    assert_equal resource, response.object
  end

  def test_list_resource
    response = resource_to_class(resource).send(:all)
    assert_equal Array, response.class
  end

  def test_list_resource_with_count
    msg = "List #{resource} with count = 2 failed"
    response = resource_to_class(resource).send(:all, {:count => 2})
    assert_equal Array, response.class, msg
  end

  def test_list_resource_with_count_and_offset
    msg = "List #{resource} with count = 2 and offset = 2 failed"
    response = resource_to_class(resource).
      send(:all, {:count => 2, :offset => 2})
    assert_equal Array, response.class, msg
  end
end
