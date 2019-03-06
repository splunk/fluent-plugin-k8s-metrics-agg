#!/usr/bin/env bash
set -e
echo "Building docker image..."
cp /tmp/pkg/fluent-plugin-k8s-metrics-agg-*.gem docker
VERSION=`cat VERSION`
docker build --build-arg VERSION=$VERSION --no-cache -t splunk/fluent-plugin-k8s-metrics-agg:metrics-aggregator ./docker
docker tag splunk/fluent-plugin-k8s-metrics-agg:metrics-aggregator splunk/${DOCKERHUB_REPO_NAME}:${VERSION}
echo "Push docker image to splunk dockerhub..."
docker login --username=$DOCKERHUB_ACCOUNT_ID --password=$DOCKERHUB_ACCOUNT_PASS
docker push splunk/${DOCKERHUB_REPO_NAME}:${VERSION} | awk 'END{print}'
echo "Docker image pushed successfully to docker-hub."