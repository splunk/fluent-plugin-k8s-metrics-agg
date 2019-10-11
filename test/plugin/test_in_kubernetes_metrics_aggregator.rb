require 'helper'
require 'fluent/plugin/in_kubernetes_metrics_aggregator.rb'

class KubernetesMetricsAggInputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers
  include PluginTestHelper

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
      interval 5s
      tag kube.*
  ]).freeze

  TIMEOUT_TEST_CONFIG = %([
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10255
      interval 5s
      tag kube.*
  ]).freeze

  setup do
    Fluent::Test.setup

    ENV['KUBERNETES_SERVICE_HOST'] = "node.fakedestination.com"
    ENV['KUBERNETES_SERVICE_PORT'] = "10255"
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
      stub_k8s_init_requests

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
      stub_k8s_init_requests

      d = create_driver(ADVANCED_CONFIG_NO_CERTS)
      assert_equal 'https://node.fakedestination.com', d.instance.kubernetes_url
      assert_equal 10_255, d.instance.kubelet_port
    end

    test 'test tag and interval parameters' do
      stub_k8s_init_requests

      d = create_driver(ADVANCED_CONFIG_NO_CERTS)
      assert_equal 'test.tag.check', d.instance.tag
      assert_equal 120, d.instance.interval
    end

    test 'test insecure_ssl and cluster_name parameters ' do
      stub_k8s_init_requests

      d = create_driver(ADVANCED_CONFIG_NO_CERTS)
      assert_true d.instance.insecure_ssl
      assert_equal 'awesome_cluster', d.instance.cluster_name
    end
  end

  sub_test_case 'Test metrics exist' do
    test 'Testing all expected metrics are emitted' do
      stub_k8s_requests

      hash_map_test = {}

      d = create_driver(METRIC_TEST_CONFIG)
      d.run timeout: 12, expect_emits: 200, shutdown: false

      d.events.each do |tag, time, record|
        hash_map_test[tag] = tag, time, record
      end

      # Test metrics exist, limits_request_scraper - limits
      assert_true hash_map_test.key?('kube.namespace.cpu.limit')
      assert_true hash_map_test.key?('kube.namespace.memory.limit')
      assert_true hash_map_test.key?('kube.container.cpu.limit')
      assert_true hash_map_test.key?('kube.pod.cpu.limit')
      assert_true hash_map_test.key?('kube.cluster.memory.limit')
      assert_true hash_map_test.key?('kube.pod.memory.limit')
      assert_true hash_map_test.key?('kube.cluster.cpu.limit')

      # Test metrics exist, limits_request_scraper - request
      assert_true hash_map_test.key?('kube.cluster.memory.request')
      assert_true hash_map_test.key?('kube.container.memory.request')
      assert_true hash_map_test.key?('kube.pod.memory.request')
      assert_true hash_map_test.key?('kube.namespace.memory.request')
      assert_true hash_map_test.key?('kube.container.cpu.request')
      assert_true hash_map_test.key?('kube.namespace.cpu.request')
      assert_true hash_map_test.key?('kube.pod.cpu.request')
      assert_true hash_map_test.key?('kube.cluster.cpu.request')

      # Test metrics exist, node_scraper/resource_usage_scraper 1
      assert_true hash_map_test.key?('kube.node.cpu.capacity')
      assert_true hash_map_test.key?('kube.node.memory.capacity')
      assert_true hash_map_test.key?('kube.node.memory.allocatable')
      assert_true hash_map_test.key?('kube.node.cpu.utilization')
      assert_true hash_map_test.key?('kube.node.memory.reservation')
      assert_true hash_map_test.key?('kube.node.memory.utilization')

      # Test metrics exist, node_scraper/resource_usage_scraper 2
      assert_true hash_map_test.key?('kube.namespace.memory.usage')
      assert_true hash_map_test.key?('kube.cluster.memory.usage')
      assert_true hash_map_test.key?('kube.namespace.cpu.usage')
      assert_true hash_map_test.key?('kube.node.cpu.allocatable')
      assert_true hash_map_test.key?('kube.node.cpu.reservation')
      assert_true hash_map_test.key?('kube.cluster.cpu.usage')

      d.instance_shutdown
    end
  end

  sub_test_case 'Test handles request timeouts' do

    test 'Testing event count with nodes call timeout' do
      stub_k8s_requests(nodes_timeout: true)

      namespace_event_count = 0
      pod_event_count = 0
      node_event_count = 0

      d = create_driver(TIMEOUT_TEST_CONFIG)
      # Should run for two intervals, the first call to node 1 which has the only 'default' namespace pod should timeout the first time
      d.run timeout: 12, expect_emits: 500, shutdown: false

      d.events.each do |tag, _time, record|
        # Limit to one events that should be emitted once per interval
        if tag == 'kube.pod.cpu.limit' && record['name'] == 'new-metrics-test-final-splunk-kubernetes-metrics-fgszl'
          pod_event_count += 1
        end
        if tag == 'kube.namespace.cpu.usage' && record['name'] == 'kube-system'
          namespace_event_count += 1
        end
        if tag == 'kube.node.cpu.capacity' && record['node'] == 'generics-aws-node-one'
          node_event_count += 1
        end
      end

      # 2 intervals - first call times out but timer continues emitting successfully next interval
      assert_equal 1, node_event_count, 'Number of node events emitted was wrong'
      # 2 intervals - first call times out but timer continues emitting successfully next interval
      assert_equal 1, namespace_event_count, 'Number of namespace events emitted was wrong'
      # 2 intervals - not timeouts
      assert_equal 2, pod_event_count, 'Number of pod events emitted was wrong'

      d.instance_shutdown
    end

    test 'Testing event count with pods call timeout' do
      stub_k8s_requests(pods_timeout: true)

      pod_event_count = 0
      node_event_count = 0

      d = create_driver(TIMEOUT_TEST_CONFIG)
      # Should run for two intervals, the first call to node 1 which has the only 'default' namespace pod should timeout the first time
      d.run timeout: 12, expect_emits: 500, shutdown: false

      d.events.each do |tag, _time, record|
        # Limit to one events that should be emitted once per interval
        if tag == 'kube.pod.cpu.limit' && record['name'] == 'new-metrics-test-final-splunk-kubernetes-metrics-fgszl'
          pod_event_count += 1
        end

        if tag == 'kube.node.cpu.utilization' && record['node'] == 'generics-aws-node-one'
          node_event_count += 1
        end
      end

      # 2 intervals - first call times out but timer continues emitting successfully next interval
      assert_equal 1, pod_event_count, 'Number of pod events emitted was wrong'
      # 2 intervals - not timeouts
      assert_equal 2, node_event_count, 'Number of namespace events emitted was wrong'

      d.instance_shutdown
    end

    test 'Testing event count with node summary call timeout' do
      stub_k8s_requests(node_summary_timeout: true)

      namespace_event_count = 0
      pod_event_count = 0

      d = create_driver(TIMEOUT_TEST_CONFIG)
      # Should run for two intervals, the first call to node 1 which has the only 'default' namespace pod should timeout the first time
      d.run timeout: 12, expect_emits: 500, shutdown: false

      d.events.each do |tag, _time, record|
        # Limit to one events that should be emitted once per interval
        if tag == 'kube.namespace.cpu.usage' && record['name'] == 'kube-system'
          namespace_event_count += 1
        end
        if tag == 'kube.pod.cpu.limit' && record['name'] == 'new-metrics-test-final-splunk-kubernetes-metrics-fgszl'
          pod_event_count += 1
        end
      end

      # 2 intervals - first call times out but timer continues emitting successfully next interval
      assert_equal 1, namespace_event_count, 'Number of namespace events emitted was wrong'
      # 2 intervals - not timeouts
      assert_equal 2, pod_event_count, 'Number of pod events emitted was wrong'

      d.instance_shutdown
    end

  end
end
