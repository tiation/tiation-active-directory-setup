# AD-Setup Enterprise Makefile
# Development, Testing, and Deployment Operations

.PHONY: help install install-mac dev-setup test test-unit test-integration lint format clean docker-build docker-push docs serve-docs

# Default target
help:
	@echo "AD-Setup Enterprise - Available Commands:"
	@echo "  make install          - Install AD-Setup (auto-detects OS)"
	@echo "  make install-mac      - Install AD-Setup on macOS"
	@echo "  make dev-setup        - Set up development environment"
	@echo "  make test             - Run all tests"
	@echo "  make test-unit        - Run unit tests"
	@echo "  make test-integration - Run integration tests"
	@echo "  make lint             - Run code linters"
	@echo "  make format           - Format code"
	@echo "  make clean            - Clean build artifacts"
	@echo "  make docker-build     - Build Docker images"
	@echo "  make docker-push      - Push Docker images to registry"
	@echo "  make docs             - Build documentation"
	@echo "  make serve-docs       - Serve documentation locally"
	@echo "  make security-scan    - Run security vulnerability scan"

# Installation targets
install:
	@echo "Installing AD-Setup Enterprise..."
	@sudo ./scripts/install.sh

install-mac:
	@echo "Installing AD-Setup Enterprise for macOS..."
	@./scripts/install-mac.sh

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	@python3 -m venv venv
	@./venv/bin/pip install --upgrade pip
	@./venv/bin/pip install -r requirements-dev.txt
	@./venv/bin/pre-commit install
	@echo "Development environment ready. Activate with: source venv/bin/activate"

# Testing targets
test: test-unit test-integration
	@echo "All tests completed!"

test-unit:
	@echo "Running unit tests..."
	@./venv/bin/python -m pytest tests/unit/ -v --cov=src --cov-report=html

test-integration:
	@echo "Running integration tests..."
	@./venv/bin/python -m pytest tests/integration/ -v

# Code quality targets
lint:
	@echo "Running linters..."
	@./venv/bin/flake8 src/ tests/
	@./venv/bin/pylint src/
	@./venv/bin/mypy src/
	@shellcheck scripts/*.sh scripts/**/*.sh

format:
	@echo "Formatting code..."
	@./venv/bin/black src/ tests/
	@./venv/bin/isort src/ tests/

# Security scan
security-scan:
	@echo "Running security scan..."
	@./venv/bin/bandit -r src/
	@./venv/bin/safety check
	@docker run --rm -v "$$(pwd)":/src aquasec/trivy fs /src

# Docker targets
docker-build:
	@echo "Building Docker images..."
	@docker build -t ad-setup:latest -f docker/Dockerfile .
	@docker build -t ad-setup-ui:latest -f docker/Dockerfile.ui .

docker-push:
	@echo "Pushing Docker images..."
	@docker tag ad-setup:latest yourusername/ad-setup:latest
	@docker tag ad-setup-ui:latest yourusername/ad-setup-ui:latest
	@docker push yourusername/ad-setup:latest
	@docker push yourusername/ad-setup-ui:latest

# Documentation targets
docs:
	@echo "Building documentation..."
	@cd docs && mkdocs build

serve-docs:
	@echo "Serving documentation at http://localhost:8000..."
	@cd docs && mkdocs serve

# Cleanup
clean:
	@echo "Cleaning up..."
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type f -name "*.pyc" -delete
	@rm -rf .coverage htmlcov/ .pytest_cache/
	@rm -rf build/ dist/ *.egg-info/
	@rm -rf docs/site/

# Development run targets
dev-run:
	@echo "Starting AD-Setup in development mode..."
	@./venv/bin/python src/cli.py

dev-daemon:
	@echo "Starting AD-Setup daemon in development mode..."
	@./venv/bin/python src/daemon.py

# Release targets
release-patch:
	@echo "Creating patch release..."
	@bumpversion patch
	@git push && git push --tags

release-minor:
	@echo "Creating minor release..."
	@bumpversion minor
	@git push && git push --tags

release-major:
	@echo "Creating major release..."
	@bumpversion major
	@git push && git push --tags
