#!/bin/bash

set -euo pipefail

KUBECONFIG_CODEENGINE=/home/sascha/.bluemix/plugins/code-engine/sascha-br-sao-ea226316-8b3a-4ff0-9100-408b6e5110d2.yaml
KUBECONFIG_ARGOCD=/tmp/argocd.yaml

read -r namespace server token <<<"$(KUBECONFIG="${KUBECONFIG_CODEENGINE}" kubectl config view -o json | jq -r '[ .contexts[0].context.namespace, .clusters[0].cluster.server, .users[0].user."auth-provider".config."id-token" ] | @tsv')"

#echo "[DEBUG] Namespace: ${namespace}"
#echo "[DEBUG] Server: ${server}"
#echo "[DEBUG] Token: ${token}"

hostname="${server/https:\/\//}"

#echo "[DEBUG] Host: $hostname"

projectName="$(KUBECONFIG="${KUBECONFIG_CODEENGINE}" kubectl get namespace "${namespace}" -o json | jq -r '.metadata.annotations."ce-project-displayname"')"

#echo "[DEBUG] Project: ${projectName}"

cat <<EOF | KUBECONFIG="${KUBECONFIG_ARGOCD}" kubectl apply --server-side -f -
apiVersion: v1
kind: Secret
metadata:
  name: cluster-${hostname}
  namespace: argocd
  annotations:
    managed-by: argocd.argoproj.io
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: ${projectName}
  namespaces: ${namespace}
  server: ${server}
  config: |
    {
      "bearerToken": "${token}",
      "tlsClientConfig": {
        "insecure": false
      }
    }
EOF
