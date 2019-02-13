require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift(File.expand_path("../../", __FILE__))
require "test-unit"
require "fluent/test"
require "fluent/test/driver/input"
require "fluent/test/helpers"
require 'webmock/test_unit'

Test::Unit::TestCase.include(Fluent::Test::Helpers)
Test::Unit::TestCase.extend(Fluent::Test::Helpers)

api_response = open(File.expand_path('../v1.json', __FILE__))

WebMock.stub_request(:get, "https://localhost:10250/api").
    with(
        headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip, deflate',
            'Host'=>'localhost:10250',
        }).
    to_return(status: 200, body: api_response, headers: {})