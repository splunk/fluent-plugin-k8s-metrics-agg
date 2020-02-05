require 'simplecov'
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

  def stub_api_port_10255
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api')
           .with(
             headers: {
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_return(status: 200,
                      body: File.open(File.expand_path('../v1.json', __FILE__)))
  end

  def stub_api_v1
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1')
           .with(
             headers: {
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_return(status: 200,
                      body: File.open(File.expand_path('../v1.json', __FILE__)))
  end

  def stub_api_pods(timeout=false)
    get_pods = WebMock.stub_request(:get,
                                    'https://node.fakedestination.com:10255/api/v1/pods')
                   .with(
                       headers: {
                           'Host' => 'node.fakedestination.com:10255'
                       }
                   )
    if timeout
      get_pods = get_pods.to_timeout.then
    end

    get_pods.to_return(status: 200,
                       body: File.open(File.expand_path('../pods.json', __FILE__)))
  end

  def stub_api_node_1
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1/nodes/generics-aws-node-one:10255/proxy/stats/summary')
           .with(
             headers: {
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_return(status: 200,
                      body: File.open(File.expand_path('../node1.json', __FILE__)))
  end

  def stub_api_node_2(timeout=false)
    get_node_summary = WebMock.stub_request(:get,
                                            'https://node.fakedestination.com:10255/api/v1/nodes/generics-aws-node-two:10255/proxy/stats/summary')
           .with(
             headers: {
               'Host' => 'node.fakedestination.com:10255'
             }
           )

    if timeout
      get_node_summary = get_node_summary.to_timeout
    end

    get_node_summary.to_return(status: 200,
                      body: File.open(File.expand_path('../node2.json', __FILE__)))
  end

  def stub_api_node_3
    WebMock.stub_request(:get,
                         'https://node.fakedestination.com:10255/api/v1/nodes/generics-aws-node-three:10255/proxy/stats/summary')
           .with(
             headers: {
               'Host' => 'node.fakedestination.com:10255'
             }
           )
           .to_return(status: 200,
                      body: File.open(File.expand_path('../node3.json', __FILE__)))
  end

  def stub_api_nodes(timeout=false)
    get_nodes = WebMock.stub_request(:get, 'https://node.fakedestination.com:10255/api/v1/nodes')
                    .with(
                        headers: {
                            'Host' => 'node.fakedestination.com:10255'
                        }
                    )

    if timeout
      get_nodes = get_nodes.to_timeout.times(2) # Nodes endpoint is called from two timers so must fail in both cases
    end

    get_nodes.to_return(status: 200,
               body: File.open(File.expand_path('../nodes.json', __FILE__)))
  end

  def stub_k8s_init_requests
    WebMock.reset!

    stub_api_port_10255
  end

  def stub_k8s_requests(nodes_timeout: false, node_summary_timeout: false, pods_timeout: false)
    WebMock.reset!

    stub_api_port_10255
    stub_api_v1
    stub_api_pods(pods_timeout)
    stub_api_nodes(nodes_timeout)
    stub_api_node_1
    stub_api_node_2(node_summary_timeout)
    stub_api_node_3
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
