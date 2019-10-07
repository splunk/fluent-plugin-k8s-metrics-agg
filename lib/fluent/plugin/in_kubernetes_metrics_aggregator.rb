# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'time'

require 'fluent/plugin/input'
require 'kubeclient'
require 'multi_json'
module Fluent
  module Plugin
    class KubernetesMetricsAggregatorInput < Fluent::Plugin::Input
      @@namespace_usage_metrics_map = {}
      @@node_requests_limits_metrics_map = {}

      @@namespace_resource_usage_metrics_map = {}
      @@node_resource_usage_metrics_map = {}

      class UsageMetricsUnit
        def initialize
          @cpu_limit = 0
          @cpu_request = 0
          @memory_limit = 0
          @memory_request = 0
        end

        def add_usage_metrics(cpu_limit, cpu_request, memory_limit, memory_request)
          cpu = get_cpu_or_memory_value(cpu_limit)
          mult = get_cpu_mult(cpu_limit)
          @cpu_limit += cpu * mult
          cpu = get_cpu_or_memory_value(cpu_request)
          mult = get_cpu_mult(cpu_request)
          @cpu_request += cpu * mult
          memory = get_cpu_or_memory_value(memory_limit)
          mult = get_memory_mult(memory_limit)
          @memory_limit += memory * mult
          memory = get_cpu_or_memory_value(memory_request)
          mult = get_memory_mult(memory_request)
          @memory_request += memory * mult
        end

        def get_cpu_value_and_multiplier(cpu)
          # m cpu is assumed standard
          @cpu_mult = 1
          @cpu_mult = 1000 if cpu[-1] != 'm'
          cpu.delete('^0-9').to_i
        end

        def get_cpu_or_memory_value(resource)
          resource = resource.tr('^0-9', '').to_i
          resource
        end

        def get_cpu_mult(cpu)
          cpu_mult = 1
          cpu_mult = 1000 if cpu[-1] != 'm'
          cpu_mult
        end

        # https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#meaning-of-memory
        def get_memory_mult(memory)
          memory_mult = if memory[-2] == 'Ki'
                          0.001
                        elsif memory[-2] == 'K'
                          1.0 / 1024
                        elsif memory[-2] == 'Mi'
                          1
                        elsif memory[-2] == 'M'
                          1
                        elsif memory[-2] == 'Gi'
                          1000
                        elsif memory[-2] == 'G'
                          1024
                        elsif memory[-2] == 'Ti'
                          1_000_000
                        elsif memory[-2] == 'T'
                          1_048_576
                        elsif memory[-2] == 'Ei'
                          1_000_000_000
                        elsif memory[-2] == 'E'
                          1_073_741_824
                        else
                          0.000001
                        end
          memory_mult
        end
      end

      class ResourceUsageMetricsUnit
        def initialize
          @cpu_usage = 0
          @memory_usage = 0
        end

        def add_resource_usage_metrics(cpu_usage, memory_usage)
          @cpu_usage += cpu_usage
          @memory_usage += memory_usage
        end
      end

      Fluent::Plugin.register_input('kubernetes_metrics_aggregator', self)

      helpers :timer

      desc 'URL of the kubernetes API server.'
      config_param :kubernetes_url, :string, default: nil

      desc 'The port that kubelet is listening to.'
      config_param :kubelet_port, :integer, default: 10_250

      desc 'The tag of the event.'
      config_param :tag, :string, default: 'kubernetes.metrics.*'

      desc 'How often it pulls metrics.'
      config_param :interval, :time, default: "15s"

      desc 'Path to a kubeconfig file points to a cluster the plugin should collect metrics from. Mostly useful when running fluentd outside of the cluster. When `kubeconfig` is set, `kubernetes_url`, `client_cert`, `client_key`, `ca_file`, `insecure_ssl`, `bearer_token_file`, and `secret_dir` will all be ignored.'
      config_param :kubeconfig, :string, default: nil

      desc 'Path to the certificate file for this client.'
      config_param :client_cert, :string, default: nil

      desc 'Path to the private key file for this client.'
      config_param :client_key, :string, default: nil

      desc 'Path to the CA file.'
      config_param :ca_file, :string, default: nil

      desc "If `insecure_ssl` is set to `true`, it won't verify apiserver's certificate."
      config_param :insecure_ssl, :bool, default: false

      desc 'Path to the file contains the API token. By default it reads from the file "token" in the `secret_dir`.'
      config_param :bearer_token_file, :string, default: nil

      desc "Path of the location where pod's service account's credentials are stored."
      config_param :secret_dir, :string, default: '/var/run/secrets/kubernetes.io/serviceaccount'

      desc 'The name of the cluster, where the plugin is deployed.'
      config_param :cluster_name, :string, default: 'cluster_name'

      def configure(conf)
        super
        @mutex_node_req_lim = Mutex.new
        @mutex_node_res_usage = Mutex.new
        parse_tag
        initialize_client
      end

      def start
        super

        timer_execute :limits_request_scraper, @interval, &method(:scrape_limits_requests_metrics)
        timer_execute :node_scraper, @interval, &method(:scrape_node_metrics)
        timer_execute :resource_usage_scraper, @interval, &method(:scrape_resource_usage_metrics)

      end

      def close
        @watchers.each &:finish if @watchers

        super
      end

      private

      def parse_tag
        @tag_prefix, @tag_suffix = @tag.split('*') if @tag.include?('*')
      end

      def generate_tag(item_name)
        return @tag unless @tag_prefix

        [@tag_prefix, item_name, @tag_suffix].join
      end

      def init_with_kubeconfig(options = {})
        config = Kubeclient::Config.read @kubeconfig
        current_context = config.context

        @client = Kubeclient::Client.new(
          current_context.api_endpoint,
          current_context.api_version,
          options.merge(
            ssl_options: current_context.ssl_options,
            auth_options: current_context.auth_options
          )
        )
      end

      def init_without_kubeconfig(_options = {})
        kubernetes_url_final = nil
        # mostly borrowed from Fluentd Kubernetes Metadata Filter Plugin
        if @kubernetes_url.nil?
          # Use Kubernetes default service account if we're in a pod.
          env_host = ENV['KUBERNETES_SERVICE_HOST']
          env_port = ENV['KUBERNETES_SERVICE_PORT']
          if env_host && env_port
            kubernetes_url_final = "https://#{env_host}:#{env_port}/api/"
          end
        else
          kubernetes_url_final = "https://#{@kubernetes_url}:#{@kubelet_port}/api/"
        end

        raise Fluent::ConfigError, 'kubernetes url is not set in configuration, or environment variables' unless kubernetes_url_final

        # Use SSL certificate and bearer token from Kubernetes service account.
        if Dir.exist?(@secret_dir)
          secret_ca_file = File.join(@secret_dir, 'ca.crt')
          secret_token_file = File.join(@secret_dir, 'token')

          if @ca_file.nil? && File.exist?(secret_ca_file)
            @ca_file = secret_ca_file
          end

          if @bearer_token_file.nil? && File.exist?(secret_token_file)
            @bearer_token_file = secret_token_file
          end
        end

        ssl_options = {
          client_cert: @client_cert && OpenSSL::X509::Certificate.new(File.read(@client_cert)),
          client_key:  @client_key && OpenSSL::PKey::RSA.new(File.read(@client_key)),
          ca_file:     @ca_file,
          verify_ssl:  @insecure_ssl ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
        }

        auth_options = {}
        auth_options[:bearer_token] = File.read(@bearer_token_file) if @bearer_token_file

        @client = Kubeclient::Client.new(
            kubernetes_url_final, 'v1',
          ssl_options: ssl_options,
          auth_options: auth_options
        )

        begin
          @client.api_valid?
        rescue KubeException => kube_error
          raise Fluent::ConfigError, "Invalid Kubernetes API #{@api_version} endpoint #{kubernetes_url_final}: #{kube_error.message}"
        end
      end

      def initialize_client
        options = {
          timeouts: {
            open: 10,
            read: nil
          }
        }

        if @kubeconfig.nil?
          init_without_kubeconfig options
        else
          init_with_kubeconfig options
        end
      end

      def parse_time(metric_time)
        Fluent::EventTime.from_time Time.iso8601(metric_time)
      end

      def underscore(camlcase)
        camlcase.gsub(/[A-Z]/) { |c| "_#{c.downcase}" }
      end

      def get_cpu_mult(cpu)
        cpu_mult = 1
        cpu_mult = 1000 if cpu[-1] != 'm'
        cpu_mult
      end

      def get_cpu_value(resource)
        cpu_val = resource.tr('^0-9', '').to_i
        mult = get_cpu_mult(resource)
        cpu_val += cpu_val * mult
        cpu_val
      end

      def get_memory_mult(memory)
        memory_mult = if memory[-2] == 'Ki'
                        0.001
                      elsif memory[-2] == 'K'
                        1.0 / 1024
                      elsif memory[-2] == 'Mi'
                        1
                      elsif memory[-2] == 'M'
                        1
                      elsif memory[-2] == 'Gi'
                        1000
                      elsif memory[-2] == 'G'
                        1024
                      elsif memory[-2] == 'Ti'
                        1_000_000
                      elsif memory[-2] == 'T'
                        1_048_576 # 1024*1024
                      elsif memory[-2] == 'Ei'
                        1_000_000_000
                      elsif memory[-2] == 'E'
                        1_073_741_824 # 1024*1024*1024
                      else
                        0.000001
                      end
        memory_mult
      end

      def get_memory_value(resource)
        mem_val = resource.tr('^0-9', '').to_i
        mult = get_memory_mult(resource)
        mem_val += mem_val * mult
        mem_val
      end

      def emit_limits_requests_metrics(tag,
                                       scraped_at,
                                       labels,
                                       limits_requests_metric)
        router.emit tag + '.cpu.limit',
                    Fluent::EventTime.from_time(scraped_at),
                    labels.merge(
                      'value' => limits_requests_metric.instance_variable_get(:@cpu_limit)
                    )
        router.emit tag + '.cpu.request',
                    Fluent::EventTime.from_time(scraped_at),
                    labels.merge('value' => limits_requests_metric.instance_variable_get(:@cpu_request))
        router.emit tag + '.memory.limit',
                    Fluent::EventTime.from_time(scraped_at),
                    labels.merge('value' => limits_requests_metric.instance_variable_get(:@memory_limit))
        router.emit tag + '.memory.request',
                    Fluent::EventTime.from_time(scraped_at),
                    labels.merge('value' => limits_requests_metric.instance_variable_get(:@memory_request))
      end

      def emit_resource_usage_metrics(tag,
                                      scraped_at,
                                      labels,
                                      resource_usage_metric)
        router.emit tag + '.cpu.usage',
                    Fluent::EventTime.from_time(scraped_at),
                    labels.merge('value' => resource_usage_metric.instance_variable_get(:@cpu_usage))
        router.emit tag + '.memory.usage',
                    Fluent::EventTime.from_time(scraped_at),
                    labels.merge('value' => resource_usage_metric.instance_variable_get(:@memory_usage))
      end

      def limits_requests_api
        @limits_requests_api =
          begin
            @client.discover unless @client.discovered
            @client.rest_client['/pods'].tap do |endpoint|
              log.debug("Use URL #{endpoint.url} for scraping limits requests metrics")
            end
          end
      end

      def scrape_limits_requests_metrics
        response = limits_requests_api.get(@client.headers)
        handle_limits_requests_res(response)
      rescue StandardError => e
        log.error "Failed to scrape metrics, error=#{$ERROR_INFO}, #{e.inspect}"
        log.error_backtrace
      end

      # This method is used to handle responses from the kube apiserver api
      def handle_limits_requests_res(response)
        # Checking response codes only for a successful GET request viz., 2XX codes
        if (response.code < 300) && (response.code > 199)
          @scraped_at = Time.now
          process_limits_requests_res MultiJson.load(response.body)
        else
          log.error "ExMultiJson.load(response.body) expected 2xx from summary API, but got #{response.code}. Response body = #{response.body}"
        end
      rescue StandardError => e
        log.error "Failed to scrape metrics, error=#{$ERROR_INFO}, #{e.inspect}"
        log.error_backtrace
      end

      def process_limits_requests_res(response)
        @scraped_at = Time.now
        @mutex_node_req_lim.synchronize do
          Array(response['items']).each do |pod_json|
            pod_namespace = pod_json['metadata']['namespace']
            pod_node_name = pod_json['spec']['nodeName']
            if @@namespace_usage_metrics_map[pod_namespace].nil?
              namespace_usage_metrics = UsageMetricsUnit.new
              @@namespace_usage_metrics_map[pod_namespace] = namespace_usage_metrics
            end

            pod_containers = pod_json['spec']['containers']
            pod_usage_metrics = UsageMetricsUnit.new
            Array(pod_containers).each do |container_json|
              container_usage_metrics = UsageMetricsUnit.new
              cpu_limit = '0'
              memory_limit = '0'
              cpu_request = '0'
              memory_request = '0'
              unless container_json['resources']['limits'].nil?
                unless container_json['resources']['limits']['cpu'].nil?
                  cpu_limit = container_json['resources']['limits']['cpu']
                end
                unless container_json['resources']['limits']['memory'].nil?
                  memory_limit = container_json['resources']['limits']['memory']
                end
              end
              unless container_json['resources']['requests'].nil?
                unless container_json['resources']['requests']['cpu'].nil?
                  cpu_request = container_json['resources']['requests']['cpu']
                end
                unless container_json['resources']['requests']['memory'].nil?
                  memory_request = container_json['resources']['requests']['memory']
                end
              end
              container_usage_metrics.add_usage_metrics(cpu_limit, cpu_request, memory_limit, memory_request)
              container_labels = { 'name' => container_json['name'], 'image' => container_json['image'], 'node' => pod_json['spec']['nodeName'] }
              emit_limits_requests_metrics(generate_tag('container'), @scraped_at, container_labels, container_usage_metrics)
              pod_usage_metrics.add_usage_metrics(cpu_limit, cpu_request, memory_limit, memory_request)
            end

            pod_labels = { 'name' => pod_json['metadata']['name'], 'namespace' => pod_json['metadata']['namespace'], 'node' => pod_json['spec']['nodeName'] }
            emit_limits_requests_metrics(generate_tag('pod'), @scraped_at, pod_labels, pod_usage_metrics)
            @@namespace_usage_metrics_map[pod_namespace].add_usage_metrics(pod_usage_metrics.instance_variable_get(:@cpu_limit).to_s + ('m'), pod_usage_metrics.instance_variable_get(:@cpu_request).to_s + ('m'),
                                                                           pod_usage_metrics.instance_variable_get(:@memory_limit).to_s + ('Mi'), pod_usage_metrics.instance_variable_get(:@memory_request).to_s + ('Mi'))

            if @@node_requests_limits_metrics_map[pod_node_name].nil?
              node_name_usage_metrics = UsageMetricsUnit.new
              @@node_requests_limits_metrics_map[pod_node_name] = node_name_usage_metrics
            end
            @@node_requests_limits_metrics_map[pod_node_name].add_usage_metrics(pod_usage_metrics.instance_variable_get(:@cpu_limit).to_s + ('m'), pod_usage_metrics.instance_variable_get(:@cpu_request).to_s + ('m'),
                                                                                pod_usage_metrics.instance_variable_get(:@memory_limit).to_s + ('Mi'), pod_usage_metrics.instance_variable_get(:@memory_request).to_s + ('Mi'))
            pod_usage_metrics = nil
          end
        end
        cluster_usage_metrics = UsageMetricsUnit.new
        @@namespace_usage_metrics_map.each do |key, value|
          cluster_usage_metrics.add_usage_metrics(value.instance_variable_get(:@cpu_limit).to_s + ('m'), value.instance_variable_get(:@cpu_request).to_s + ('m'),
                                                  value.instance_variable_get(:@memory_limit).to_s + ('Mi'), value.instance_variable_get(:@memory_request).to_s + ('Mi'))
          emit_limits_requests_metrics(generate_tag('namespace'), @scraped_at, { 'name' => key }, value)
          value = nil
        end

        emit_limits_requests_metrics(generate_tag('cluster'), @scraped_at, { 'name' => @cluster_name }, cluster_usage_metrics)
        cluster_usage_metrics = nil

        @@namespace_usage_metrics_map = nil
        @@namespace_usage_metrics_map = {}
      end

      def node_api
        @node_api =
          begin
            @client.discover unless @client.discovered
            @client.rest_client['/nodes'].tap do |endpoint|
              log.debug("Use URL #{endpoint.url} for scraping node metrics")
            end
          end
      end

      def scrape_node_metrics
        response = node_api.get(@client.headers)
        handle_node_response(response)
      rescue StandardError => e
        log.error "Failed to scrape metrics, error=#{$ERROR_INFO}, #{e.inspect}"
        log.error_backtrace
      end

      # This method is used to handle responses from the kubeapiserver api
      def handle_node_response(response)
        # Checking response codes only for a successful GET request viz., 2XX codes
        if (response.code < 300) && (response.code > 199)
          @scraped_node_at = Time.now
          process_node_response MultiJson.load(response.body)
        else
          log.error "ExMultiJson.load(response.body) expected 2xx from summary API, but got #{response.code}. Response body = #{response.body}"
        end
      rescue StandardError => e
        log.error "Failed to scrape metrics, error=#{$ERROR_INFO}, #{e.inspect}"
        log.error_backtrace
      end

      def process_node_response(response)
        Array(response['items']).each do |node_json|
          node_name = node_json['metadata']['name']
          node_cpu_capacity = get_cpu_value(node_json['status']['capacity']['cpu'])
          router.emit generate_tag('node') << ('.cpu.capacity'), Fluent::EventTime.from_time(@scraped_node_at), 'node' => node_name, 'value' => node_cpu_capacity
          node_cpu_allocatable = get_cpu_value(node_json['status']['allocatable']['cpu'])
          router.emit generate_tag('node') << ('.cpu.allocatable'), Fluent::EventTime.from_time(@scraped_node_at), 'node' => node_name, 'value' => node_cpu_allocatable
          node_memory_capacity = get_memory_value(node_json['status']['capacity']['memory'])
          router.emit generate_tag('node') << ('.memory.capacity'), Fluent::EventTime.from_time(@scraped_node_at), 'node' => node_name, 'value' => node_memory_capacity
          node_memory_allocatable = get_memory_value(node_json['status']['allocatable']['memory'])
          router.emit generate_tag('node') << ('.memory.allocatable'), Fluent::EventTime.from_time(@scraped_node_at), 'node' => node_name, 'value' => node_memory_allocatable

          node_req_lim = UsageMetricsUnit.new
          node_res_usage = ResourceUsageMetricsUnit.new
          @mutex_node_req_lim.synchronize do
            next if @@node_requests_limits_metrics_map[node_name].nil?

            node_req_lim = @@node_requests_limits_metrics_map[node_name]
          end
          @mutex_node_res_usage.synchronize do
            next if @@node_resource_usage_metrics_map[node_name].nil?

            node_res_usage = @@node_resource_usage_metrics_map[node_name]
          end
          # https://github.com/kubernetes/heapster/blob/c78cc312ab3901acfe5c2f95f7a621909c8455ad/metrics/processors/node_autoscaling_enricher.go#L62
          node_cpu_utilization = node_res_usage.instance_variable_get(:@cpu_usage).to_f / 1_000_000 * node_cpu_allocatable # converting from nano cores to milli core
          router.emit generate_tag('node') << ('.cpu.utilization'), Fluent::EventTime.from_time(@scraped_node_at), 'node' => node_name, 'value' => node_cpu_utilization
          node_cpu_reservation = node_req_lim.instance_variable_get(:@cpu_request).to_f / node_cpu_allocatable
          router.emit generate_tag('node') << ('.cpu.reservation'), Fluent::EventTime.from_time(@scraped_node_at), 'node' => node_name, 'value' => node_cpu_reservation
          node_memory_utilization = node_res_usage.instance_variable_get(:@memory_usage).to_f / 1_000_000 * node_memory_allocatable # converting from bytes to megabytes
          router.emit generate_tag('node') << ('.memory.utilization'), Fluent::EventTime.from_time(@scraped_node_at), 'node' => node_name, 'value' => node_memory_utilization
          node_memory_reservation = node_req_lim.instance_variable_get(:@memory_request).to_f / node_memory_allocatable
          router.emit generate_tag('node') << ('.memory.reservation'), Fluent::EventTime.from_time(@scraped_node_at), 'node' => node_name, 'value' => node_memory_reservation
          @mutex_node_req_lim.synchronize do
            @@node_requests_limits_metrics_map = nil
            @@node_requests_limits_metrics_map = {}
          end
          @mutex_node_res_usage.synchronize do
            @@node_resource_usage_metrics_map = nil
            @@node_resource_usage_metrics_map = {}
          end
        end
      end

      def resource_usage_api
        @resource_usage_api =
          begin
            @client.discover unless @client.discovered
            @client.rest_client['/nodes'].tap do |endpoint|
              log.debug("Use URL #{endpoint.url} for scraping node metrics")
            end
          end
      end

      def scrape_resource_usage_metrics
        response = resource_usage_api.get(@client.headers)
        handle_resource_usage_response(response)
      rescue StandardError => e
        log.error "Failed to scrape metrics, error=#{$ERROR_INFO}, #{e.inspect}"
        log.error_backtrace
      end

      # This method is used to handle responses from the kubelet summary api
      def handle_resource_usage_response(response)
        # Checking response codes only for a successful GET request viz., 2XX codes
        if (response.code < 300) && (response.code > 199)
          @scraped_at = Time.now
          process_resource_usage_res MultiJson.load(response.body)
        else
          log.error "ExMultiJson.load(response.body) expected 2xx from summary API, but got #{response.code}. Response body = #{response.body}"
        end
      rescue StandardError => e
        log.error "Failed to scrape metrics, error=#{$ERROR_INFO}, #{e.inspect}"
        log.error_backtrace
      end

      def process_resource_usage_res(response)
        @scraped_node_at = Time.now
        @mutex_node_res_usage.synchronize do
          Array(response['items']).each do |node_json|
            node_name = node_json['metadata']['name']
            node_rest_client =
              begin
                @client.discover unless @client.discovered
                @client.rest_client["/nodes/#{node_name}:#{@kubelet_port}/proxy/stats/summary"].tap do |endpoint|
                  log.debug("Use URL #{endpoint.url} for scraping resource usage metrics")
                end
              end

            node_response = JSON.parse(node_rest_client.get(@client.headers))
            Array(node_response['pods']).each do |pod_json|
              pod_cpu_usage = pod_json['cpu']['usageNanoCores']/ 1_000_000
              pod_memory_usage = pod_json['memory']['usageBytes']
              pod_namespace = pod_json['podRef']['namespace']
              pod_usage = ResourceUsageMetricsUnit.new
              pod_usage.add_resource_usage_metrics(pod_cpu_usage, pod_memory_usage)
              if @@namespace_resource_usage_metrics_map[pod_namespace].nil?
                namespace_usage_metrics = ResourceUsageMetricsUnit.new
                @@namespace_resource_usage_metrics_map[pod_namespace] = pod_usage
              else
                @@namespace_resource_usage_metrics_map[pod_namespace].add_resource_usage_metrics(pod_cpu_usage, pod_memory_usage)
              end
              if @@node_resource_usage_metrics_map[node_name].nil?
                node_name_usage_metrics = ResourceUsageMetricsUnit.new
                @@node_resource_usage_metrics_map[node_name] = node_name_usage_metrics
              end
              @@node_resource_usage_metrics_map[node_name].add_resource_usage_metrics(pod_cpu_usage, pod_memory_usage)
              pod_usage = nil
            end
          end
        end

        cluster_usage_metrics = ResourceUsageMetricsUnit.new
        @@namespace_resource_usage_metrics_map.each do |key, value|
          cluster_usage_metrics.add_resource_usage_metrics(value.instance_variable_get(:@cpu_usage), value.instance_variable_get(:@memory_usage))
          emit_resource_usage_metrics(generate_tag('namespace'), @scraped_at, { 'name' => key }, value)
          value = nil
        end
        emit_resource_usage_metrics(generate_tag('cluster'), @scraped_at, { 'name' => @cluster_name }, cluster_usage_metrics)
        cluster_usage_metrics = nil

        @@namespace_resource_usage_metrics_map = nil
        @@namespace_resource_usage_metrics_map = {}
      end
    end
  end
end
