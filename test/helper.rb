require 'simplecov'
require 'fluent/plugin/in_kubernetes_metrics_aggregator.rb'
SimpleCov.start

$LOAD_PATH.unshift(File.expand_path('..', __dir__))
require 'test-unit'
require 'fluent/test'
require 'fluent/test/driver/input'
require 'fluent/test/helpers'
require 'webmock/test_unit'

Test::Unit::TestCase.include(Fluent::Test::Helpers)
Test::Unit::TestCase.extend(Fluent::Test::Helpers)

module PluginTestHelper
  def k8s_host
    'apiserver'
  end

  def k8s_port
    '10255'
  end

  def k8s_url(path = 'api')
    "https://#{k8s_host}:#{k8s_port}/#{path}"
  end

  def kubelet_summary_api_url_node1
    k8s_url + '/v1/nodes/generics-aws-node-one:10255/proxy/stats/summary'
  end

  def kubelet_summary_api_url_node2
    k8s_url + '/v1/nodes/generics-aws-node-two:10255/proxy/stats/summary'
  end

  def kubelet_summary_api_url_node3
    k8s_url + '/v1/nodes/generics-aws-node-three:10255/proxy/stats/summary'
  end

  def stub_api_port_10250
    WebMock.stub_request(:get, 'https://node.fakedestination.com:10250/api')
           .with(
             headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip, deflate',
               'Host' => 'node.fakedestination.com:10250'
             }
           )
           .to_return(status: 200,
                      body: File.open(File.expand_path('../v1.json', __FILE__)),
                      headers: {})
  end

  def stub_api_port_10255
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api')
           .with(
             headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip, deflate',
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_return(status: 200,
                      body: File.open(File.expand_path('../v1.json', __FILE__)),
                      headers: {})
  end

  def stub_api_v1
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1')
           .with(
             headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip, deflate',
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_return(status: 200,
                      body: File.open(File.expand_path('../v1.json', __FILE__)),
                      headers: {})
  end

  def stub_api_pods
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1/pods')
           .with(
             headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip, deflate',
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_timeout
           .then
           .to_return(status: 200,
                      body: File.open(File.expand_path('../pods.json', __FILE__)),
                      headers: {})
  end

  def stub_api_node_1
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1/nodes/generics-aws-node-one:10255/proxy/stats/summary')
           .with(
             headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip, deflate',
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_timeout
           .then
           .to_return(status: 200,
                      body: File.open(File.expand_path('../node1.json', __FILE__)),
                      headers: {})
  end

  def stub_api_node_2
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1/nodes/generics-aws-node-two:10255/proxy/stats/summary')
           .with(
             headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip, deflate',
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_timeout
           .then
           .to_return(status: 200,
                      body: File.open(File.expand_path('../node2.json', __FILE__)),
                      headers: {})
  end

  def stub_api_node_3
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1/nodes/generics-aws-node-three:10255/proxy/stats/summary')
           .with(
             headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip, deflate',
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_timeout
           .then
           .to_return(status: 200,
                      body: File.open(File.expand_path('../node3.json', __FILE__)),
                      headers: {})
  end

  def stub_api_nodes
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1/nodes')
           .with(
             headers: {
               'Accept' => '*/*',
               'Accept-Encoding' => 'gzip, deflate',
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_timeout.then.to_timeout
           .then
           .to_return(status: 200,
                      body: File.open(File.expand_path('../nodes.json', __FILE__)),
                      headers: {})
  end

  def stub_k8s_requests
    stub_api_port_10250
    stub_api_port_10255
    stub_api_v1
    stub_api_pods
    stub_api_nodes
    stub_api_node_1
    stub_api_node_3
    stub_api_node_2
  end

  def get_parsed_file(file_name)
    parsed_string = nil
    File.open(File.expand_path('../' + file_name.to_s, __FILE__)).tap do |f|
      parsed_string = f.read
                       .close
    end
    parsed_string
  end
end
