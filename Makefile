# Full Stack FastAPI Template Makefile
# Common tasks for development, building, and deployment

# Variables
REGISTRY := quay.io
ORG := cfchase
PROJECT_NAME := full-stack-fastapi
BACKEND_IMAGE := $(REGISTRY)/$(ORG)/$(PROJECT_NAME)-backend
FRONTEND_IMAGE := $(REGISTRY)/$(ORG)/$(PROJECT_NAME)-frontend
TAG := latest
OPENSHIFT_NAMESPACE := full-stack-fastapi
STAGING_NAMESPACE := full-stack-fastapi-staging

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: help dev dev-frontend dev-backend build build-backend build-frontend push push-backend push-frontend deploy deploy-openshift clean test lint format generate-client

# Default target
help: ## Show this help message
	@echo "$(GREEN)Full Stack FastAPI Template - Available Make Targets$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development targets
dev: ## Start full development stack with Docker Compose
	@echo "$(GREEN)Starting development stack...$(NC)"
	docker compose watch

dev-frontend: ## Start only frontend development server
	@echo "$(GREEN)Starting frontend development server...$(NC)"
	cd frontend && npm run dev

dev-backend: ## Start only backend development server
	@echo "$(GREEN)Starting backend development server...$(NC)"
	cd backend && fastapi dev app/main.py

# Build targets
build: build-backend build-frontend ## Build both backend and frontend images

build-backend: ## Build backend Docker image
	@echo "$(GREEN)Building backend image for amd64 linux...$(NC)"
	docker build --platform linux/amd64 -t $(BACKEND_IMAGE):$(TAG) backend/
	@echo "$(GREEN)Backend image built: $(BACKEND_IMAGE):$(TAG)$(NC)"

build-frontend: ## Build frontend Docker image
	@echo "$(GREEN)Building frontend image for amd64 linux...$(NC)"
	docker build --platform linux/amd64 -f frontend/Dockerfile.openshift -t $(FRONTEND_IMAGE):$(TAG) frontend/
	@echo "$(GREEN)Frontend image built: $(FRONTEND_IMAGE):$(TAG)$(NC)"

# Push targets
push: push-backend push-frontend ## Push both images to registry

push-backend: build-backend ## Build and push backend image
	@echo "$(GREEN)Pushing backend image to $(REGISTRY)...$(NC)"
	docker push $(BACKEND_IMAGE):$(TAG)
	@echo "$(GREEN)Backend image pushed: $(BACKEND_IMAGE):$(TAG)$(NC)"

push-frontend: build-frontend ## Build and push frontend image
	@echo "$(GREEN)Pushing frontend image to $(REGISTRY)...$(NC)"
	docker push $(FRONTEND_IMAGE):$(TAG)
	@echo "$(GREEN)Frontend image pushed: $(FRONTEND_IMAGE):$(TAG)$(NC)"

# OpenShift deployment targets
deploy: deploy-openshift ## Deploy to OpenShift

deploy-openshift: deploy-production ## Deploy application to OpenShift (production)

deploy-staging: ## Deploy to staging environment
	@echo "$(GREEN)Deploying to staging environment...$(NC)"
	@echo "$(YELLOW)Creating namespace $(STAGING_NAMESPACE) if it doesn't exist...$(NC)"
	kubectl create namespace $(STAGING_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	cd openshift/overlays/staging && kustomize edit set namespace $(STAGING_NAMESPACE)
	kubectl apply -k openshift/overlays/staging
	@echo "$(YELLOW)Waiting for database to be ready...$(NC)"
	kubectl wait --for=condition=available --timeout=300s deployment/postgresql -n $(STAGING_NAMESPACE)
	@echo "$(GREEN)Staging deployment completed!$(NC)"
	@echo "$(YELLOW)Getting route URLs...$(NC)"
	@kubectl get routes -n $(STAGING_NAMESPACE) -o custom-columns=NAME:.metadata.name,URL:.spec.host --no-headers | sed 's/^/  https:\/\//'
	@echo ""
	@echo "$(GREEN)Login Credentials:$(NC)"
	@echo "Email: $$(kubectl get configmap full-stack-fastapi-config -n $(STAGING_NAMESPACE) -o jsonpath='{.data.first-superuser}')"
	@echo "Password: $$(kubectl get secret full-stack-fastapi-secrets -n $(STAGING_NAMESPACE) -o jsonpath='{.data.first-superuser-password}' | base64 -d)"

deploy-production: ## Deploy to production environment  
	@echo "$(GREEN)Deploying to production environment...$(NC)"
	@echo "$(YELLOW)Creating namespace if it doesn't exist...$(NC)"
	kubectl create namespace $(OPENSHIFT_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "$(YELLOW)Generating random production passwords...$(NC)"
	$(eval PROD_PASSWORD := $(shell openssl rand -base64 16))
	$(eval POSTGRES_PASSWORD := $(shell openssl rand -base64 16))
	$(eval SECRET_KEY := $(shell openssl rand -base64 32))
	@echo "postgres-user=postgres" > openshift/overlays/production/production-secrets.env
	@echo "postgres-password=$(POSTGRES_PASSWORD)" >> openshift/overlays/production/production-secrets.env
	@echo "first-superuser-password=$(PROD_PASSWORD)" >> openshift/overlays/production/production-secrets.env
	@echo "secret-key=$(SECRET_KEY)" >> openshift/overlays/production/production-secrets.env
	cd openshift/overlays/production && kustomize edit set namespace $(OPENSHIFT_NAMESPACE)
	kubectl apply -k openshift/overlays/production
	@echo "$(YELLOW)Waiting for database to be ready...$(NC)"
	kubectl wait --for=condition=available --timeout=300s deployment/postgresql -n $(OPENSHIFT_NAMESPACE)
	@echo "$(GREEN)Production deployment completed!$(NC)"
	@echo "$(YELLOW)Getting route URLs...$(NC)"
	@kubectl get routes -n $(OPENSHIFT_NAMESPACE) -o custom-columns=NAME:.metadata.name,URL:.spec.host --no-headers | sed 's/^/  https:\/\//'
	@echo ""
	@echo "$(GREEN)Login Credentials:$(NC)"
	@echo "Email: $$(kubectl get configmap full-stack-fastapi-config -n $(OPENSHIFT_NAMESPACE) -o jsonpath='{.data.first-superuser}')"
	@echo "Password: $$(kubectl get secret full-stack-fastapi-secrets -n $(OPENSHIFT_NAMESPACE) -o jsonpath='{.data.first-superuser-password}' | base64 -d)"

undeploy: undeploy-production ## Remove application from OpenShift (production)

undeploy-staging: ## Remove application from staging environment
	@echo "$(RED)Removing application from staging environment...$(NC)"
	kubectl delete -k openshift/overlays/staging --ignore-not-found=true
	kubectl delete namespace $(STAGING_NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)Staging application removed$(NC)"

undeploy-production: ## Remove application from production environment
	@echo "$(RED)Removing application from production environment...$(NC)"
	kubectl delete -k openshift/overlays/production --ignore-not-found=true
	@echo "$(GREEN)Production application removed$(NC)"

# Update deployment with new images
update-images: push ## Update OpenShift deployment with latest images
	@echo "$(GREEN)Updating deployment with new images...$(NC)"
	kubectl set image deployment/backend backend=$(BACKEND_IMAGE):$(TAG) -n $(OPENSHIFT_NAMESPACE)
	kubectl set image deployment/frontend frontend=$(FRONTEND_IMAGE):$(TAG) -n $(OPENSHIFT_NAMESPACE)
	kubectl rollout status deployment/backend -n $(OPENSHIFT_NAMESPACE)
	kubectl rollout status deployment/frontend -n $(OPENSHIFT_NAMESPACE)
	@echo "$(GREEN)Deployment updated successfully!$(NC)"

# Testing targets
test: test-backend test-frontend ## Run all tests

test-backend: ## Run backend tests
	@echo "$(GREEN)Running backend tests...$(NC)"
	cd backend && bash ./scripts/test.sh

test-frontend: ## Run frontend E2E tests
	@echo "$(GREEN)Running frontend tests...$(NC)"
	cd frontend && npx playwright test

# Code quality targets
lint: lint-backend lint-frontend ## Run linting for both backend and frontend

lint-backend: ## Run backend linting
	@echo "$(GREEN)Running backend linting...$(NC)"
	cd backend && bash ./scripts/lint.sh

lint-frontend: ## Run frontend linting
	@echo "$(GREEN)Running frontend linting...$(NC)"
	cd frontend && npm run lint

format: format-backend ## Format code

format-backend: ## Format backend code
	@echo "$(GREEN)Formatting backend code...$(NC)"
	cd backend && bash ./scripts/format.sh

# Client generation
generate-client: ## Generate frontend API client from backend OpenAPI schema
	@echo "$(GREEN)Generating API client...$(NC)"
	./scripts/generate-client.sh

# Setup targets
setup: ## Initial project setup
	@echo "$(GREEN)Setting up project...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Creating .env file from template...$(NC)"; \
		cp .env.example .env 2>/dev/null || echo "$(RED)Warning: .env.example not found$(NC)"; \
	fi
	@echo "$(YELLOW)Installing backend dependencies...$(NC)"
	cd backend && uv sync
	@echo "$(YELLOW)Installing frontend dependencies...$(NC)"
	cd frontend && npm install
	@echo "$(YELLOW)Installing pre-commit hooks...$(NC)"
	cd backend && uv run pre-commit install
	@echo "$(GREEN)Setup completed!$(NC)"
	@echo "$(YELLOW)Don't forget to update .env with your configuration$(NC)"

# Database targets
db-migrate: ## Run database migrations
	@echo "$(GREEN)Running database migrations...$(NC)"
	cd backend && alembic upgrade head

db-revision: ## Create new database migration
	@read -p "Enter migration message: " msg; \
	cd backend && alembic revision --autogenerate -m "$$msg"

# Utility targets
logs: ## Show Docker Compose logs
	docker compose logs -f

logs-backend: ## Show backend logs
	docker compose logs -f backend

logs-frontend: ## Show frontend logs
	docker compose logs -f frontend

clean: ## Clean up Docker containers and images
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	docker compose down -v --remove-orphans
	docker system prune -f
	@echo "$(GREEN)Cleanup completed$(NC)"

status: status-production ## Show OpenShift deployment status (production)

status-staging: ## Show staging deployment status
	@echo "$(GREEN)Staging Deployment Status:$(NC)"
	kubectl get all -n $(STAGING_NAMESPACE)
	@echo ""
	@echo "$(GREEN)Routes:$(NC)"
	kubectl get routes -n $(STAGING_NAMESPACE) -o custom-columns=NAME:.metadata.name,URL:.spec.host --no-headers | sed 's/^/  https:\/\//'

status-production: ## Show production deployment status
	@echo "$(GREEN)Production Deployment Status:$(NC)"
	kubectl get all -n $(OPENSHIFT_NAMESPACE)
	@echo ""
	@echo "$(GREEN)Routes:$(NC)"
	kubectl get routes -n $(OPENSHIFT_NAMESPACE) -o custom-columns=NAME:.metadata.name,URL:.spec.host --no-headers | sed 's/^/  https:\/\//'

# Registry login
registry-login: ## Login to Quay.io registry
	@echo "$(GREEN)Logging into Quay.io registry...$(NC)"
	@read -p "Enter Quay.io username: " username; \
	docker login -u $$username $(REGISTRY)

# Configuration helpers
config-check: ## Check configuration and environment
	@echo "$(GREEN)Configuration Check:$(NC)"
	@echo "Registry: $(REGISTRY)"
	@echo "Organization: $(ORG)"
	@echo "Backend Image: $(BACKEND_IMAGE):$(TAG)"
	@echo "Frontend Image: $(FRONTEND_IMAGE):$(TAG)"
	@echo "Production Namespace: $(OPENSHIFT_NAMESPACE)"
	@echo "Staging Namespace: $(STAGING_NAMESPACE)"
	@echo ""
	@echo "$(YELLOW)Docker status:$(NC)"
	@docker --version
	@echo "$(YELLOW)kubectl status:$(NC)"
	@kubectl version --client
	@echo "$(YELLOW)Current context:$(NC)"
	@kubectl config current-context