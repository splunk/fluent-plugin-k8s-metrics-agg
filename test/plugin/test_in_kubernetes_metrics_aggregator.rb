require 'helper'
require 'fluent/plugin/in_kubernetes_metrics_aggregator.rb'

class KubernetesMetricsAggInputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  def teardown

  end

  ZERO_CONFIG = %[]

  BASIC_CONFIG = %[
      kubernetes_url https://node.fakedestination.com
  ]

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::KubernetesMetricsAggregatorInput).configure(conf)
  end
    sub_test_case 'default parameter configuration' do
      test 'test default params' do
        d = create_driver(ZERO_CONFIG)
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
end