require 'simplecov'
require 'fluent/plugin/in_kubernetes_metrics_aggregator.rb'
SimpleCov.start

$LOAD_PATH.unshift(File.expand_path("../../", __FILE__))
require "test-unit"
require "fluent/test"
require "fluent/test/driver/input"
require "fluent/test/helpers"
require 'webmock/test_unit'

Test::Unit::TestCase.include(Fluent::Test::Helpers)
Test::Unit::TestCase.extend(Fluent::Test::Helpers)

class MetricsHelper
  def create_driver(conf)
    @@driver = Fluent::Test::Driver::Input.new(Fluent::Plugin::KubernetesMetricsAggregatorInput).configure(conf)
    #return @@driver
  end

  def stub_api_10250
    WebMock.stub_request(:get, "https://localhost:10250/api").
        with(
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip, deflate',
                'Host'=>'localhost:10250'
            }).
        to_return(status: 200, body: open(File.expand_path('../v1.json', __FILE__)) , headers: {})
  end

  def stub_api_10255
    WebMock.stub_request(:get, "https://node.fakedestination.com:10255/api").
        with(
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip, deflate',
                'Host'=>'node.fakedestination.com:10255'
            }).
        to_return(status: 200, body: open(File.expand_path('../v1.json', __FILE__)) , headers: {})
  end
end