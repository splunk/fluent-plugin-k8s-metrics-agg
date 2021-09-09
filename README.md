# Fluentd Plugin for Kubernetes Metrics - Aggregator

[Fluentd](https://fluentd.org/) input plugin collects kubernetes cluster metrics from the kubeapiserver API. The API is exposed by [KubeApiServer](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/) on a kubernetes cluster.

## Installation

See also: [Plugin Management](https://docs.fluentd.org/v1.0/articles/plugin-management).

### RubyGems

```
$ gem install fluent-plugin-k8s-metrics-agg
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-k8s-metrics-agg"
```

And then execute:

```
$ bundle
```

## Plugin helpers

* [timer](https://docs.fluentd.org/v1.0/articles/api-plugin-helper-timer)

* See also: [Input Plugin Overview](https://docs.fluentd.org/v1.0/articles/input-plugin-overview)

## Fluent::Plugin::KubernetesMetricsAggregatorInput

### tag (string) (optional)

The event tag.

Default value: `kubernetes.metrics.*`.

### interval (time) (optional)

How often the plugin pulls metrcs.

Default value: `15s`.

### kubeconfig (string) (optional)

The path to a kubeconfig file points to a cluster from which the plugin should collect metrics. This is mostly useful when running fluentd outside of the cluster. When `kubeconfig` is set, the `kubernetes_url`, `client_cert`, `client_key`, `ca_file`, `insecure_ssl`, `bearer_token_file`, and `secret_dir` are ignored.

### client_cert (string) (optional)

The path to the certificate file for this client.

### client_key (string) (optional)

The path to the private key file for this client.

### ca_file (string) (optional)

The path to the CA file.

### insecure_ssl (bool) (optional)

When `insecure_ssl` is set to `true`, the plugin does not verify the apiserver's certificate.

### bearer_token_file (string) (optional)

The path to the file contains the API token. By default the plugin reads from the file "token" in the `secret_dir`.

### secret_dir (string) (optional)

The path to the location of the pod's service account credentials.

Default value: `/var/run/secrets/kubernetes.io/serviceaccount`.

### kubelet_port (integer) (optional)

The port that the kubelet is listening to.

Default value: `10255`.

### cluster_name (string) (optional)

The name of the cluster where the plugin is deployed.

Default value: `cluster_name`.

## License

See [License](LICENSE).