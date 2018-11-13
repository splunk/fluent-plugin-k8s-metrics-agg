require "helper"
require "fluent/plugin/in_kubernetes_metrics_aggregator.rb"

class KubernetesMetricsInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  private

    def create_driver(conf)
      Fluent::Test::Driver::Input.new(Fluent::Plugin::KubernetesMetricsInput).configure(conf)
    end
end