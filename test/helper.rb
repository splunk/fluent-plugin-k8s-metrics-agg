require 'simplecov'
require 'fluent/plugin/in_kubernetes_metrics_aggregator.rb'
SimpleCov.start

$LOAD_PATH.unshift(File.expand_path("../../", __FILE__))
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

  def k8s_url(path='api')
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
    WebMock.stub_request(:get, "https://localhost:10250/api").
        with(
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip, deflate',
                'Host'=>'localhost:10250'
            }).
        to_return(status: 200, body: open(File.expand_path('../v1.json', __FILE__)) , headers: {})
  end

  def stub_api_port_10255
    WebMock.stub_request(:get, "https://node.fakedestination.com:10255/api").
        with(
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip, deflate',
                'Host'=>'node.fakedestination.com:10255'
            }).
        to_return(status: 200, body: open(File.expand_path('../v1.json', __FILE__)) , headers: {})
  end

  def stub_k8s_v1
    File.open(File.expand_path('v1.json', __dir__)).tap do |f|
      stub_request(:get, "#{k8s_url}/v1")
        .to_return(body: f.read)
    end
  end

  def stub_k8s_api
    File.open(File.expand_path('api.json', __dir__)).tap do |f|
      stub_request(:get, k8s_url)
        .to_return(body: f.read)
    end
  end

  def stub_k8s_api_pods
    File.open(File.expand_path('pods.json', __dir__)).tap do |f|
      stub_request(:get, k8s_url + '/v1/pods')
        .to_return(body: f.read)
    end
  end

  def stub_k8s_api_nodes
    File.open(File.expand_path('/nodes.json', __dir__)).tap do |f|
      stub_request(:get, k8s_url + '/v1/nodes')
        .to_return(body: f.read)
    end
  end

  def stub_kubelet_summary_api_node1
    File.open(File.expand_path('node1.json', __dir__)).tap do |f|
      stub_request(:get, kubelet_summary_api_url_node1.to_s)
        .to_return(body: f.read)
    end
  end

  def stub_kubelet_summary_api_node2
    File.open(File.expand_path('node2.json', __dir__)).tap do |f|
      stub_request(:get, kubelet_summary_api_url_node2.to_s)
        .to_return(body: f.read)
    end
  end

  def stub_kubelet_summary_api_node3
    File.open(File.expand_path('node3.json', __dir__)).tap do |f|
      stub_request(:get, kubelet_summary_api_url_node3.to_s)
        .to_return(body: f.read)
    end
  end

  def stub_k8s_requests
    stub_api_port_10250
    stub_api_port_10255
    stub_k8s_api
    stub_k8s_api_pods
    stub_k8s_api_nodes
    stub_kubelet_summary_api_node1
    stub_kubelet_summary_api_node2
    stub_kubelet_summary_api_node3
  end
end
