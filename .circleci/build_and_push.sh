#!/usr/bin/env bash
set -e
aws ecr get-login --region $AWS_REGION --no-include-email | bash
echo "Building docker image..."
cp /tmp/pkg/fluent-plugin-k8s-metrics-agg-*.gem docker
echo "Copy latest fluent-plugin-splunk-hec gem from S3"
aws s3 cp s3://k8s-ci-artifacts/fluent-plugin-splunk-hec-${FLUENT_SPLUNK_HEC_GEM_VERSION}.gem ./docker
docker build --no-cache -t splunk/fluent-plugin-k8s-metrics-agg:metrics-aggregator ./docker
docker tag splunk/fluent-plugin-k8s-metrics-agg:metrics-aggregator $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/k8s-ci-metrics-agg:latest
echo "Push docker image to ecr..."
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/k8s-ci-metrics-agg:latest | awk 'END{print}'
echo "Docker image pushed successfully."