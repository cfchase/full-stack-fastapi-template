# OpenShift Deployment with Kustomize

This directory contains OpenShift-compatible Kubernetes templates for deploying the Full Stack FastAPI Template application using Kustomize for configuration management.

## Directory Structure

```
openshift/
├── base/                     # Base Kubernetes manifests
│   ├── kustomization.yaml    # Base kustomization
│   ├── secret.yaml          # Default secrets
│   ├── configmap.yaml       # Base configuration
│   ├── postgresql.yaml      # Database deployment
│   ├── backend.yaml         # Backend API deployment
│   ├── frontend.yaml        # Frontend deployment
│   └── route.yaml           # OpenShift routes
└── overlays/                # Environment-specific overlays
    ├── staging/             # Staging environment
    │   ├── kustomization.yaml
    │   └── environment-patch.yaml
    └── production/          # Production environment
        ├── kustomization.yaml
        ├── environment-patch.yaml
        └── resource-limits.yaml
```

## Deployment Options

### Using Makefile (Recommended)

```bash
# Staging environment
make deploy-staging

# Production environment  
make deploy-production

# Check status
make status-staging
make status-production

# Remove deployments
make undeploy-staging
make undeploy-production
```

### Using kubectl directly

```bash
# Staging deployment
kubectl apply -k openshift/overlays/staging

# Production deployment
kubectl apply -k openshift/overlays/production

# Remove deployment
kubectl delete -k openshift/overlays/production
```

### Using OpenShift CLI

```bash
# Staging deployment
oc apply -k openshift/overlays/staging

# Production deployment
oc apply -k openshift/overlays/production
```

## Environment Differences

### Staging Environment
- **Namespace**: `full-stack-fastapi-staging`
- **Image Tags**: `staging`
- **Replicas**: 1 for all services
- **Resources**: Lower limits for staging
- **Secrets**: Generated with staging passwords
- **CORS**: Includes localhost origins for local development

### Production Environment
- **Namespace**: `full-stack-fastapi`
- **Image Tags**: `latest`
- **Replicas**: 2 for backend and frontend (HA)
- **Resources**: Higher limits for production workloads
- **Database Storage**: 5Gi vs 1Gi for staging
- **Secrets**: Use external secrets (commented out secret generator)
- **CORS**: Production domains only

## Customization

### Image Management
Images are managed through kustomize and can be overridden:

```yaml
images:
  - name: backend-image
    newName: quay.io/myorg/full-stack-fastapi-backend
    newTag: v1.2.3
```

### Environment Variables
Add environment-specific patches in overlay directories:

```yaml
# overlays/production/environment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  template:
    spec:
      containers:
      - name: backend
        env:
        - name: CUSTOM_VAR
          value: "production-value"
```

### Secrets Management
For production, replace the secret generator with external secrets:

```bash
# Create secrets manually
kubectl create secret generic full-stack-fastapi-secrets \
  --from-literal=postgres-password="secure-password" \
  --from-literal=first-superuser-password="secure-password" \
  --from-literal=secret-key="secure-secret-key" \
  -n full-stack-fastapi
```

## Technical Notes

- **Container Images**: Uses Red Hat UBI-based images for OpenShift compatibility
- **Security Contexts**: Non-root containers with proper OpenShift security constraints
- **Health Checks**: Configured liveness and readiness probes
- **Database**: Red Hat PostgreSQL with automatic database initialization
- **Networking**: Internal service communication with external routes
- **Storage**: Persistent volumes for database data

## Security

⚠️ **Important**: 
- Change all default passwords before deploying to production
- Use external secret management in production
- Review and adjust resource limits based on your cluster capacity
- Ensure proper RBAC permissions for service accounts