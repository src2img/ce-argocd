#!/bin/bash

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

KUBECONFIG_ARGOCD=/tmp/argocd.yaml

# create KinD cluster
echo "[INFO] Creating KinD cluster argocd"
rm -f "${KUBECONFIG_ARGOCD}"
kind delete cluster --name argocd || true
KUBECONFIG="${KUBECONFIG_ARGOCD}" kind create cluster --name argocd

# Install ArgoCD
echo "[INFO] Installing ArgoCD"
KUBECONFIG="${KUBECONFIG_ARGOCD}" kubectl create namespace argocd
KUBECONFIG="${KUBECONFIG_ARGOCD}" kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Limit the resources that ArgoCD looks at
echo "[INFO] Configuring ArgoCD for the limited Code Engine resources"
KUBECONFIG="${KUBECONFIG_ARGOCD}" kubectl patch configmap -n argocd argocd-cm --type merge --patch-file "${DIR}/argocd-config/argocd-cm.yaml"

# Wait for pod to be running
echo "[INFO] Waiting for ArgoCD to have started"
KUBECONFIG="${KUBECONFIG_ARGOCD}" kubectl -n argocd rollout status deployment argocd-server --timeout 5m

# Creating port-forward for ArgoCD server
echo "[INFO] Exposing argocd-server through kubectl port-forward"
KUBECONFIG="${KUBECONFIG_ARGOCD}" kubectl -n argocd port-forward deployment/argocd-server 8080 >/dev/null 2>&1 &
sleep 10

# Showing ArgoCD password
echo "[INFO] Logging in argocd CLI"
ARGOCD_PASSWORD="$(KUBECONFIG="${KUBECONFIG_ARGOCD}" argocd admin initial-password -n argocd | head -n 1)"
argocd login localhost:8080 --insecure --username admin --password "${ARGOCD_PASSWORD}"

echo "[INFO] You can open the ArgoCD UI at https://localhost:8080. Login as admin with password ${ARGOCD_PASSWORD}"
