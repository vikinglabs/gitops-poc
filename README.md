# OMS GitOps POC

## PREREQUISITES
These instructions assume a local setup in Windows 11 with Docker Desktop and WSL2. You will also need the following packages install under WSL2:

1. Kind - https://kind.sigs.k8s.io/
```
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 \
chmod +x ./kind \
sudo mv ./kind /usr/local/bin/kind
```
2. Helm - https://helm.sh/
```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
chmod 700 get_helm.sh \
./get_helm.sh
```
3. Kubernetes CLI - https://kubernetes.io/
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
chmod +x ./vcluster  \
sudo mv ./kubectl /usr/local/bin/vcluster
```
4. vCluster CLI - https://www.vcluster.com/
```
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64" \
chmod +x ./kubectl \
sudo mv ./kubectl /usr/local/bin/kubectl
```

## DO THIS FIRST!

1. Configure AWS SSO.
```
$ aws configure sso
```
2. Login to ECR.
```
$ aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 586495777821.dkr.ecr.us-east-1.amazonaws.com
```

## THEN DO THIS

1. Bootstrap local setup.
```
$ ./start.sh
```
2. Port forward the ArgoCD service.
```
$ kubectl -n argocd port-forward svc/argocd-server 8080:80
```
3. Get the `admin` user password.
```
$ kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
4. Login to http://localhost:8080
![ArgoCD](https://github.com/vikinglabs/gitops-poc/blob/main/argo.png?raw=true)