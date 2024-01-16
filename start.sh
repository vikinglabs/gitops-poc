#!/bin/bash
set -e

# Create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

# Create Kind cluster
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: local
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:5000"]
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Add the registry config to the nodes
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

# Connect the registry to the cluster network if not already connected
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# Document the local registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# # Pull docker images
# aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 586495777821.dkr.ecr.us-east-1.amazonaws.com
# 
# docker pull 586495777821.dkr.ecr.us-east-1.amazonaws.com/oms-device-usage:41
# docker pull 586495777821.dkr.ecr.us-east-1.amazonaws.com/oms-sap-be:1.3.0
# docker pull 586495777821.dkr.ecr.us-east-1.amazonaws.com/oms-spelling:0.0.11
# 
# docker tag 586495777821.dkr.ecr.us-east-1.amazonaws.com/oms-device-usage:41 localhost:5001/oms-device-usage:0.1.0
# docker tag 586495777821.dkr.ecr.us-east-1.amazonaws.com/oms-sap-be:1.3.0 localhost:5001/oms-sap-be:1.3.0
# docker tag 586495777821.dkr.ecr.us-east-1.amazonaws.com/oms-spelling:0.0.11 localhost:5001/oms-spelling:0.0.11
# 
# docker push localhost:5001/oms-device-usage:0.1.0
# docker push localhost:5001/oms-sap-be:1.3.0
# docker push localhost:5001/oms-spelling:0.0.11
# 
# Create vCluster for development, staging and production
vcluster create development --create-namespace
vcluster create staging --create-namespace
vcluster create production --create-namespace

# helm upgrade --install vcluster-development vcluster \
#   --repo https://charts.loft.sh \
#   --namespace vcluster-development \
#   --create-namespace \
#   --repository-config='' \
#   --set service.type="NodePort"
# 
# helm upgrade --install vcluster-staging vcluster \
#   --repo https://charts.loft.sh \
#   --namespace vcluster-staging \
#   --create-namespace \
#   --repository-config='' \
#   --set service.type="NodePort"
# 
# helm upgrade --install vcluster-production vcluster \
#   --repo https://charts.loft.sh \
#   --namespace vcluster-production \
#   --create-namespace \
#   --repository-config='' \
#   --set service.type="NodePort"

# Kyverno
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace
sleep 10
cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sync-secret
spec:
  generateExistingOnPolicyUpdate: true
  rules:
  - name: sync-secret
    match:
      any:
      - resources:
          names:
          - "vc-*"
          kinds:
          - Secret
    exclude:
      any:
      - resources:
          namespaces:
          - kube-system
          - default
          - kube-public
          - kyverno
    context:
    - name: namespace
      variable:
        value: "{{ request.object.metadata.namespace }}"
    - name: name
      variable:
        value: "{{ request.object.metadata.name }}"
    - name: ca
      variable: 
        value: "{{ request.object.data.\"certificate-authority\" }}"
    - name: cert
      variable: 
        value: "{{ request.object.data.\"client-certificate\" }}"
    - name: key
      variable: 
        value: "{{ request.object.data.\"client-key\" }}"
    - name: vclusterName
      variable:
        value: "{{ replace_all(namespace, 'vcluster-', '') }}"
        jmesPath: 'to_string(@)'
    generate:
      kind: Secret
      apiVersion: v1
      name: "{{ vclusterName }}"
      namespace: argocd
      synchronize: true
      data:
        kind: Secret
        metadata:
          labels:
            argocd.argoproj.io/secret-type: cluster
        stringData:
          name: "{{ vclusterName }}"
          server: "https://{{ vclusterName }}.{{ namespace }}:443"
          config: |
            {
              "tlsClientConfig": {
                "insecure": false,
                "caData": "{{ ca }}",
                "certData": "{{ cert }}",
                "keyData": "{{ key }}"
              }
            }
EOF

#helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
#--set admissionController.replicas=3 \
#--set backgroundController.replicas=2 \
#--set cleanupController.replicas=2 \
#--set reportsController.replicas=2

# ArgoCD
kubectl apply -k argocd/
sleep 10
kubectl apply -f argocd/argocd-proj.yaml
kubectl apply -f argocd/argocd-app.yaml

# Bootstrap applications
# kubectl apply -k cluster-bootstrap/
kubectl apply -k cluster-bootstrap/