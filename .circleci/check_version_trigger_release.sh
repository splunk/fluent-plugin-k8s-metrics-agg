#!/usr/bin/env bash
set -e

#!/usr/bin/env bash
LATEST_COMMIT=$(git rev-parse HEAD)
VERSION_COMMIT=$(git log -1 --format=format:%H VERSION)
if [ $VERSION_COMMIT = $LATEST_COMMIT ];
    then
        if [ -s VERSION ] # Check if content is empty
            then 
                VERSION=`cat VERSION`
                echo "VERSION is changed to $VERSION" 
            else 
                echo "[ERROR] VERSION file is empty."
                exit 1
        fi 
        git config user.email "splunk-oss-admin@splunk.com"
        git config user.name "splunk-oss-admin"
        # Checkout develop and pull latest
        git checkout develop
        git pull origin develop
        # merge it to master branch
        git checkout master
        git merge --no-edit -X theirs develop
        git push
        # cut release branch from master
        git checkout -b release/$VERSION
        git push https://$RELEASE_GITHUB_USER:$RELEASE_GITHUB_PASS@github.com/splunk/fluent-plugin-k8s-metrics-agg.git release/$VERSION
fi
