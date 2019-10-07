require 'helper'
require 'fluent/plugin/in_kubernetes_metrics_aggregator.rb'

class KubernetesMetricsAggInputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers
  include PluginTestHelper

  @driver = nil
  @driver_test = nil
  @@hash_map_test = {}

  ZERO_CONFIG = %([
  ]).freeze

  BASIC_CONFIG = %([
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10255
  ]).freeze

  ADVANCED_CONFIG_NO_CERTS = %([
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10255
      tag test.tag.check
      interval 2m
      insecure_ssl true
      cluster_name awesome_cluster
  ]).freeze

  ADVANCED_CONFIG_CERTS = %([
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10255
  ]).freeze

  METRIC_TEST_CONFIG = %([
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10255
      tag kube.*
  ]).freeze

  setup do
    Fluent::Test.setup
    ENV['KUBERNETES_SERVICE_HOST'] = "node.fakedestination.com"
    ENV['KUBERNETES_SERVICE_PORT'] = "10255"
    stub_k8s_requests
    @driver = create_driver(METRIC_TEST_CONFIG)
    @driver.run timeout: 30, expect_emits: 200, shutdown: false

    @driver.events.each do |tag, time, record|
      @@hash_map_test[tag] = tag, time, record
    end
  end

  def create_driver(conf = BASIC_CONFIG)
    d = Fluent::Test::Driver::Input
        .new(Fluent::Plugin::KubernetesMetricsAggregatorInput)
    with_worker_config(workers: 3, worker_id: 1) do
      d.configure(conf)
    end
  end

  sub_test_case 'default parameter configuration' do
    test 'test default params' do
      d = create_driver(ZERO_CONFIG)
      assert_equal 10_250, d.instance.kubelet_port
      assert_equal 'kubernetes.metrics.*', d.instance.tag
      assert_equal '15s', d.instance.interval
      assert_nil d.instance.kubeconfig
      assert_nil d.instance.client_cert
      assert_nil d.instance.client_key
      assert_nil d.instance.ca_file
      assert_false d.instance.insecure_ssl
      assert_nil d.instance.bearer_token_file
      assert_equal '/var/run/secrets/kubernetes.io/serviceaccount',
                   d.instance.secret_dir
      assert_equal 'cluster_name', d.instance.cluster_name
    end
  end

  sub_test_case 'modify parameter changes' do
    test 'test kubelet_port and supplied kubernetes URL parameters' do
      d = create_driver(ADVANCED_CONFIG_NO_CERTS)
      assert_equal 'https://node.fakedestination.com', d.instance.kubernetes_url
      assert_equal 10_255, d.instance.kubelet_port
    end

    test 'test tag and interval parameters' do
      d = create_driver(ADVANCED_CONFIG_NO_CERTS)
      assert_equal 'test.tag.check', d.instance.tag
      assert_equal 120, d.instance.interval
    end

    test 'test insecure_ssl and cluster_name parameters ' do
      d = create_driver(ADVANCED_CONFIG_NO_CERTS)
      assert_true d.instance.insecure_ssl
      assert_equal 'awesome_cluster', d.instance.cluster_name
    end
  end

  sub_test_case 'Test metrics exist, limits_request_scraper - limits' do
    test 'Testing kube.container.memory.limit' do
      assert_true @@hash_map_test.key?('kube.container.memory.limit')
    end

    test 'Testing kube.namespace.cpu.limit' do
      assert_true @@hash_map_test.key?('kube.namespace.cpu.limit')
    end

    test 'Testing kube.namespace.memory.limit	' do
      assert_true @@hash_map_test.key?('kube.namespace.memory.limit')
    end

    test 'Testing kube.container.cpu.limit' do
      assert_true @@hash_map_test.key?('kube.container.cpu.limit')
    end

    test 'Testing kube.pod.cpu.limit' do
      assert_true @@hash_map_test.key?('kube.pod.cpu.limit')
    end

    test 'Testing kube.cluster.memory.limit	' do
      assert_true @@hash_map_test.key?('kube.cluster.memory.limit')
    end

    test 'Testing kube.pod.memory.limit	' do
      assert_true @@hash_map_test.key?('kube.pod.memory.limit')
    end

    test 'Testing kube.cluster.cpu.limit' do
      assert_true @@hash_map_test.key?('kube.cluster.cpu.limit')
    end
  end

  sub_test_case 'Test metrics exist, limits_request_scraper - request' do
    test 'Testing kube.cluster.memory.request	' do
      assert_true @@hash_map_test.key?('kube.cluster.memory.request')
    end

    test 'Testing kube.container.memory.request' do
      assert_true @@hash_map_test.key?('kube.container.memory.request')
    end

    test 'Testing kube.pod.memory.request' do
      assert_true @@hash_map_test.key?('kube.pod.memory.request')
    end

    test 'Testing kube.namespace.memory.request	' do
      assert_true @@hash_map_test.key?('kube.namespace.memory.request')
    end

    test 'Testing kube.container.cpu.request' do
      assert_true @@hash_map_test.key?('kube.container.cpu.request')
    end

    test 'Testing kube.namespace.cpu.request' do
      assert_true @@hash_map_test.key?('kube.namespace.cpu.request')
    end

    test 'Testing kube.pod.cpu.request' do
      assert_true @@hash_map_test.key?('kube.pod.cpu.request')
    end

    test 'Testing kube.cluster.cpu.request' do
      assert_true @@hash_map_test.key?('kube.cluster.cpu.request')
    end
  end

  sub_test_case 'Test metrics exist, node_scraper/resource_usage_scraper 1' do
    test 'Testing kube.node.cpu.capacity' do
      assert_true @@hash_map_test.key?('kube.node.cpu.capacity')
    end

    test 'Testing kube.node.memory.capacity	' do
      assert_true @@hash_map_test.key?('kube.node.memory.capacity')
    end

    test 'Testing kube.node.memory.allocatable' do
      assert_true @@hash_map_test.key?('kube.node.memory.allocatable')
    end

    test 'Testing kube.node.cpu.utilization	' do
      assert_true @@hash_map_test.key?('kube.node.cpu.utilization')
    end

    test 'Testing kube.node.memory.reservation' do
      assert_true @@hash_map_test.key?('kube.node.memory.reservation')
    end

    test 'Testing kube.node.memory.utilization' do
      assert_true @@hash_map_test.key?('kube.node.memory.utilization')
    end
  end

  sub_test_case 'Test metrics exist, node_scraper/resource_usage_scraper 2' do
    test 'Testing kube.namespace.memory.usage	' do
      assert_true @@hash_map_test.key?('kube.namespace.memory.usage')
    end

    test 'Testing kube.cluster.memory.usage' do
      assert_true @@hash_map_test.key?('kube.cluster.memory.usage')
    end

    test 'Testing kube.namespace.cpu.usage' do
      assert_true @@hash_map_test.key?('kube.namespace.cpu.usage')
    end

    test 'Testing kube.node.cpu.allocatable	' do
      assert_true @@hash_map_test.key?('kube.node.cpu.allocatable')
    end

    test 'Testing kube.node.cpu.reservation	' do
      assert_true @@hash_map_test.key?('kube.node.cpu.reservation')
    end

    test 'Testing kube.cluster.cpu.usage' do
      assert_true @@hash_map_test.key?('kube.cluster.cpu.usage')
    end
  end
end
