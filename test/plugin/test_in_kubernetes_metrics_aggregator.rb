require 'helper'
require 'fluent/plugin/in_kubernetes_metrics_aggregator.rb'

class KubernetesMetricsAggInputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  def teardown

  end

  CONFIG = %[
      kubernetes_url https://node.fakedestination.com
      kubelet_port 10_255
  ]

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::KubernetesMetricsAggregatorInput).configure(conf)
  end

  sub_test_case 'configuration' do
    test 'basic configuration' do
      d = create_driver(CONFIG)
      puts d
      assert_equal 'localhost', d.instance.kubernetes_url
    end
  end

end