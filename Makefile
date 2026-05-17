.PHONY: dev stop test test-watch lint format migrate migration rollback shell logs prod-up prod-down anonymize help

dev: ## Start development environment with live reload
	docker compose up

stop: ## Stop development environment
	docker compose down

test: ## Run backend tests
	pytest tests/ -v --tb=short $(ARGS)

test-watch: ## Run backend tests (no live-reload — use entr or similar externally)
	pytest tests/ -v --tb=short $(ARGS)

lint: ## Lint and type-check backend code
	flake8 app/ tests/ && black --check app/ tests/

format: ## Format backend code with black
	black app/ tests/

migrate: ## Run database migrations
	alembic upgrade head

migration: ## Create a new migration: make migration name="description"
	alembic revision --autogenerate -m "$(name)"

rollback: ## Rollback last migration
	alembic downgrade -1

shell: ## Open a bash shell in the api container
	docker compose exec api bash

logs: ## Tail api container logs
	docker compose logs -f api

prod-up: ## Start production environment
	docker compose -f docker-compose.prod.yml up -d

prod-down: ## Stop production environment
	docker compose -f docker-compose.prod.yml down

anonymize: ## Anonymize user data: make anonymize user=<user_id>
	python scripts/anonymize_data.py --user-id "$(user)"

help: ## Print this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
