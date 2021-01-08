#!/usr/bin/env bash

set -euo pipefail

function get_auth() {
    registry=$1
    echo -n '"'"$registry"'": { "auth": "'"$(echo "$BREW_IMAGE_REGISTRY_USERNAME:$(<$BREW_IMAGE_REGISTRY_TOKEN_PATH)" | tr -d '\n' | base64 -i -w 0)"'" }'
}

function get_auths() {
    registries=('brew.registry.redhat.io' 'registry.redhat.io' 'registry.stage.redhat.io' 'registry-proxy.engineering.redhat.com' 'registry-proxy-stage.engineering.redhat.com')
    auths='{'
    for registry in "${registries[@]}"; do
        auths+=$(get_auth $registry)','
    done
    auths+='} '
    echo -n "$auths"
}

authfile=/tmp/authfile
trap 'rm -rf /tmp/authfile*' EXIT SIGINT SIGTERM

echo "getting authfile from cluster"
oc get secret/pull-secret -n openshift-config -o json | jq -r '.data.".dockerconfigjson"' | base64 -d >"$authfile"

echo "injecting credentials for brew image registry into authfile"
jq -c '.auths + '"$(get_auths)"' | {"auths": .}' "$authfile" >"${authfile}.new"

echo "updating cluster pull secret from authfile"
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson="${authfile}.new"
