# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Full Stack Development
- `docker compose watch` - Start full development stack with hot reloading
- `make dev` - Same as above using Makefile

### Backend Development (FastAPI)
- `cd backend && fastapi dev app/main.py` - Start backend development server
- `cd backend && bash ./scripts/test.sh` - Run tests with coverage
- `cd backend && bash ./scripts/lint.sh` - Run mypy, ruff check, and format check
- `cd backend && bash ./scripts/format.sh` - Format code with ruff
- `cd backend && alembic upgrade head` - Run database migrations
- `cd backend && alembic revision --autogenerate -m "message"` - Create new migration
- `cd backend && uv run pre-commit run --all-files` - Run pre-commit hooks manually

### Frontend Development (React + TypeScript)
- `cd frontend && npm run dev` - Start frontend development server
- `cd frontend && npm run build` - Build for production
- `cd frontend && npm run lint` - Run Biome linter
- `cd frontend && npx playwright test` - Run E2E tests
- `cd frontend && npm run generate-client` - Generate API client from OpenAPI schema

### Container & Deployment
- `make build` - Build both backend and frontend Docker images
- `make push` - Push images to registry (quay.io/cfchase/full-stack-fastapi)
- `make deploy-staging` - Deploy to OpenShift staging environment
- `make deploy-production` - Deploy to OpenShift production environment
- `make test` - Run all tests (backend + frontend E2E)

## Architecture Overview

This is a full-stack FastAPI template with React frontend, designed for modern web applications with authentication, CRUD operations, and deployment to OpenShift/Kubernetes.

### Backend Architecture
- **FastAPI** with **SQLModel** for type-safe database operations
- **PostgreSQL** database with **Alembic** migrations
- **JWT authentication** with secure password hashing (bcrypt)
- **Pydantic** for data validation and settings management
- Database models in `backend/app/models.py` with User/Item entities
- API routes in `backend/app/api/routes/` (users, items, login, private)
- Core configuration in `backend/app/core/` (config, security, database)
- **UV** for Python dependency management and virtual environments

### Frontend Architecture
- **React 18** with **TypeScript** and **Vite** build system
- **TanStack Router** for file-based routing (`src/routes/`)
- **TanStack Query** for server state management and caching
- **Chakra UI** component library with dark mode support
- Auto-generated API client from backend OpenAPI schema
- **Playwright** for E2E testing with authentication setup
- **Biome** for linting and formatting instead of ESLint/Prettier

### Key Patterns
- **Monorepo structure** with separate backend/frontend directories
- **Docker Compose** for local development with hot reloading
- **OpenAPI-first development** - frontend client generated from backend schema
- **Type safety** throughout stack (SQLModel → Pydantic → TypeScript)
- **Authentication flow** with JWT tokens and refresh mechanism
- **CRUD operations** following REST conventions with proper validation

### Database Schema
- **Users table**: UUID primary key, email (unique), hashed passwords, superuser flag
- **Items table**: UUID primary key, title, description, owner relationship
- **Cascade deletes** configured for user → items relationship

### Configuration Management
- Environment variables via `.env` file in project root
- Pydantic Settings class for type-safe configuration loading
- Separate configurations for local/staging/production environments
- OpenShift deployment uses Kustomize overlays for environment-specific configs

### Testing Strategy
- **Backend**: pytest with coverage reporting, test database isolation
- **Frontend**: Playwright E2E tests with authentication setup
- **Pre-commit hooks** for code quality (ruff, mypy, biome, prettier for emails)
- CI/CD integration ready with GitHub Actions

### Deployment
- **OpenShift/Kubernetes** ready with Kustomize manifests in `openshift/`
- **Multi-stage Docker builds** optimized for production
- **Staging and production** environment overlays
- **Secrets management** with automatic password generation for production
- **Route configuration** for external access via OpenShift routes

## Important Notes

- The backend uses UV instead of pip/poetry - always use `uv` commands for Python dependencies
- Frontend uses Biome instead of ESLint/Prettier - run `npm run lint` for linting
- API client is auto-generated - run `npm run generate-client` after backend schema changes
- Database migrations should be reviewed before applying to production
- All passwords and secrets are managed via environment variables
- The project supports both local Docker development and OpenShift deployment