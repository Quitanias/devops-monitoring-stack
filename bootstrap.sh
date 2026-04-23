#!/bin/bash

set -e

echo "======================================"
echo "Starting DevOps Lab Bootstrap"
echo "======================================"

############################################
# CHECK DEPENDENCIES
############################################

echo "Checking Docker..."

if ! command -v docker &> /dev/null
then
    echo "Docker not found. Install Docker first."
    exit 1
fi

############################################
# START MINIKUBE
############################################

echo "Starting Minikube..."

minikube start --driver=docker

echo "Minikube cluster started"

############################################
# INSTALL ARGOCD
############################################

echo "Installing ArgoCD..."

kubectl create namespace argocd || true

kubectl apply \
--server-side \
-n argocd \
-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "ArgoCD installed"

############################################
# DEPLOY ARGOCD APPLICATION
############################################

echo "Deploying ArgoCD Application for GitOps..."

kubectl apply -f infra/argocd/argocd-app.yaml

echo "ArgoCD Application deployed"

############################################
# INSTALL HELM (IF NOT INSTALLED)
############################################

if ! command -v helm &> /dev/null
then
    echo "Installing Helm..."

    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

############################################
# INSTALL OBSERVABILITY STACK
############################################

echo "Installing Prometheus + Grafana..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

kubectl create namespace monitoring || true

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
-n monitoring

echo "Observability stack installed"

############################################
# START JENKINS
############################################

echo "Starting Jenkins container..."

docker volume create jenkins_home || true
docker rm -f jenkins || true

docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts || true

############################################
# WAIT FOR PODS
############################################

echo "Waiting for pods..."

kubectl wait --for=condition=ready pod \
--all \
-n argocd \
--timeout=300s || true

kubectl wait --for=condition=ready pod \
--all \
-n monitoring \
--timeout=300s || true

############################################
# PRINT ACCESS INFO
############################################

echo "======================================"
echo "Environment Ready"
echo "======================================"

echo "Jenkins:"
echo "http://localhost:8080"

echo ""
echo "ArgoCD:"
echo "kubectl port-forward svc/argocd-server -n argocd 8081:443"

echo ""
echo "Grafana:"
echo "kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80"

echo ""
echo "Grafana Password:"
kubectl get secret monitoring-grafana \
-n monitoring \
-o jsonpath="{.data.admin-password}" | base64 -d

echo ""
echo ""
echo "ArgoCD Password:"
kubectl get secret argocd-initial-admin-secret \
-n argocd \
-o jsonpath="{.data.password}" | base64 -d

echo ""
echo "======================================"

############################################
# BUILD AND DEPLOY PYTHON API
############################################

echo "Building Python API image..."

eval $(minikube docker-env)

docker build -t app:latest ./app

echo "Deploying Python API..."

kubectl apply -k infra/k8s/

kubectl rollout status deployment/app

echo "Python API deployed"

echo ""
echo "Test:"
echo "kubectl port-forward svc/app 8000:80"


############################################
# INSTALL KUSTOMIZE
############################################

curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
sudo mv kustomize /usr/local/bin/