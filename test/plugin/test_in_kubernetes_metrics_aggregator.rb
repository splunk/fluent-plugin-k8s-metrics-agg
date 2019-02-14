require 'helper'
require 'fluent/plugin/in_kubernetes_metrics_aggregator.rb'

class KubernetesMetricsAggInputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers
  @@metricsHelper = MetricsHelper.new

  def setup
    Fluent::Test.setup
    @@metricsHelper.create_driver(ZERO_CONFIG)

  end

  def teardown

  end

  @@metricsHelper.stub_api_10250
  @@metricsHelper.stub_api_10255

  ZERO_CONFIG = %[]

  BASIC_CONFIG = %[
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10255
  ]

  ADVANCED_CONFIG_NO_CERTS = %[
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10255
      tag test.tag.check
      interval 2m
      insecure_ssl true
      cluster_name awesome_cluster

  ]

  ADVANCED_CONFIG_CERTS = %[
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10255

  ]

  sub_test_case 'default parameter configuration' do
    test 'test default params' do
      d = @@metricsHelper.create_driver(ZERO_CONFIG)
      assert_equal 'https://localhost', d.instance.kubernetes_url
      assert_equal 10250 , d.instance.kubelet_port
      assert_equal 'kubernetes.metrics.*',  d.instance.tag
      assert_equal '15s', d.instance.interval
      assert_nil d.instance.kubeconfig
      assert_nil d.instance.client_cert
      assert_nil d.instance.client_key
      assert_nil d.instance.ca_file
      assert_false d.instance.insecure_ssl
      assert_nil d.instance.bearer_token_file
      assert_equal '/var/run/secrets/kubernetes.io/serviceaccount', d.instance.secret_dir
      assert_equal 'cluster_name', d.instance.cluster_name
    end
  end

  sub_test_case 'modify parameter changes' do
    test 'test kubelet_port and supplied kubernetes URL parameters' do
      d = @@metricsHelper.create_driver(BASIC_CONFIG)
      assert_equal 'https://node.fakedestination.com', d.instance.kubernetes_url
      assert_equal 10255 , d.instance.kubelet_port
    end

    test 'test tag and interval parameters' do
      d = @@metricsHelper.create_driver(ADVANCED_CONFIG_NO_CERTS)
      assert_equal 'test.tag.check', d.instance.tag
      assert_equal 120 , d.instance.interval
    end

    test 'test insecure_ssl and cluster_name parameters ' do
     d = @@metricsHelper.create_driver(ADVANCED_CONFIG_NO_CERTS)
     assert_true d.instance.insecure_ssl
     assert_equal 'awesome_cluster' , d.instance.cluster_name
    end
  end

  #TODO:ADD Certificate and Bearer token tests.




end