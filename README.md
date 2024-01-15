# OMS GitOps POC

DO THIS FIRST!

1. Configure AWS SSO.
```
$ aws configure sso
```
2. Login to ECR.
```
$ aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 586495777821.dkr.ecr.us-east-1.amazonaws.com
```

THEN DO THIS

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