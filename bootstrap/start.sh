#!/bin/bash
set -e

# Create Kind cluster
kind create cluster --config kind-cluster.yaml

# Create vCluster for development, staging and production
helm upgrade --install vcluster-development vcluster \
  --set vcluster.image="rancher/k3s:v1.23.5-k3s1" \
  --repo https://charts.loft.sh \
  --namespace vcluster-develoment \
  --create-namespace

helm upgrade --install vcluster-staging vcluster \
  --set vcluster.image="rancher/k3s:v1.23.5-k3s1" \
  --repo https://charts.loft.sh \
  --namespace vcluster-staging \
  --create-namespace

helm upgrade --install vcluster-production vcluster  \
  --set vcluster.image="rancher/k3s:v1.23.5-k3s1" \
  --repo https://charts.loft.sh \
  --namespace vcluster-production \
  --create-namespace

# Kyverno
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
sleep 10
kubectl apply -f cluster-policy.yaml

#helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
#--set admissionController.replicas=3 \
#--set backgroundController.replicas=2 \
#--set cleanupController.replicas=2 \
#--set reportsController.replicas=2

# ArgoCD
kubectl apply -k ../argocd
sleep 10
kubectl apply -f ../argocd/argocd-proj.yaml
kubectl apply -f ../argocd/argocd-app.yaml

# Bootstrap applications
kubectl apply -k ../cluster-bootstrap