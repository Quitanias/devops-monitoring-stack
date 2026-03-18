# devops-monitoring-stack

A end-to-end DevOps lab project. It includes a Python API instrumented with Prometheus metrics, a Jenkins-based CI/CD pipeline, and a Kubernetes deployment managed with Kustomize, designed to run locally with Minikube.

---

## Stack

| Layer | Tool |
|---|---|
| Application | Python + FastAPI + Uvicorn |
| Containerization | Docker |
| Orchestration | Kubernetes (Minikube) |
| CI/CD | Jenkins |
| Observability | Prometheus + Grafana (kube-prometheus-stack) |
| GitOps | ArgoCD + Kustomize |

---

## Project Structure

```
devops-monitoring-stack/
├── app/
│   ├── python-app/
│   │   └── main.py           # FastAPI app with Prometheus metrics middleware
│   ├── tests/
│   │   └── test_api.py       # API tests
│   ├── Dockerfile            # Container image definition
│   ├── Jenkinsfile           # CI/CD pipeline definition
│   └── requirements.txt      # Python dependencies
│
├── infra/
│   └── k8s/
│       ├── deployment.yaml   # Kubernetes Deployment
│       ├── service.yaml      # Kubernetes Service
│       └── kustomization.yaml # Kustomize image override config
│
└── bootstrap.sh              # One-shot script to set up the full local environment
```

---

## Application

The API is built with **FastAPI** and exposes three endpoints:

| Endpoint | Description |
|---|---|
| `GET /status` | Health check — returns `{"status": "ok"}` |
| `GET /data` | Returns example data |
| `GET /metrics` | Prometheus-formatted metrics |

A middleware automatically tracks every request, recording:
- **Total request count** (`http_requests_total`) — labeled by method, endpoint, and status code
- **Request latency** (`http_request_duration_seconds`) — labeled by endpoint
- **Error count** (`http_errors_total`) — labeled by endpoint

---

## CI/CD Pipeline (Jenkins)

The `Jenkinsfile` defines a fully automated pipeline with the following stages:

```
Checkout → Run Tests → Build Image → Login Docker Hub → Push Image → Update Kustomize → Commit & Push
```

1. **Checkout** — Clones the application repository
2. **Run Tests** — Installs dependencies and runs `pytest`
3. **Build Image** — Builds the Docker image tagged with the Jenkins build number
4. **Login Docker Hub** — Authenticates using Jenkins credentials (`dockerhub-creds`)
5. **Push Image** — Pushes the image to Docker Hub
6. **Update Image with Kustomize** — Updates the image tag in `infra/k8s/kustomization.yaml`
7. **Commit and Push** — Commits the updated manifest back to the repository, triggering ArgoCD to sync

### Required Jenkins Credentials

| ID | Type | Usage |
|---|---|---|
| `github-creds` | Username + Password | Git clone and push |
| `dockerhub-creds` | Username + Password | Docker Hub login |

---

## Running Locally

The `bootstrap.sh` script automates the entire local environment setup.

### Prerequisites

- Docker
- Minikube
- `kubectl`

### Setup

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

The script will:
1. Start a **Minikube** cluster
2. Install **ArgoCD** in the `argocd` namespace
3. Install **Helm** (if not present) and deploy the **Prometheus + Grafana** stack in the `monitoring` namespace
4. Start a **Jenkins** container on port `8080`
5. Build the Python API image inside Minikube's Docker daemon
6. Deploy the app to Kubernetes with `kubectl apply -f k8s/`
7. Install **Kustomize**

### Accessing the Services

After `bootstrap.sh` completes, use the following commands to access each service:

```bash
# Application
kubectl port-forward svc/app 8000:80

# Jenkins
# http://localhost:8080

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8081:443

# Grafana
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

> The Grafana and ArgoCD admin passwords are printed at the end of the `bootstrap.sh` output.

---

## Kubernetes Manifests

The deployment is managed with **Kustomize**. The `kustomization.yaml` file overrides the image at deploy time, allowing Jenkins to update only the image tag without touching the base manifests.

```yaml
# infra/k8s/kustomization.yaml
images:
  - name: app
    newName: quitanias/app
    newTag: latest  # Updated automatically by Jenkins via `kustomize edit set image`
```

To apply manually:

```bash
kubectl apply -k infra/k8s/
```
