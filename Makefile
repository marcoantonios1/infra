.PHONY: run up down restart logs status pull clean help

run: up ## Alias for up

up: ## Start all services in the background
	docker compose up -d

down: ## Stop all services
	docker compose down

restart: ## Restart all services
	docker compose restart

logs: ## Tail logs for all services (Ctrl+C to exit)
	docker compose logs -f

logs-speaches: ## Tail speaches logs only
	docker compose logs -f speaches

logs-kokoro: ## Tail kokoro logs only
	docker compose logs -f kokoro

status: ## Show running container status
	docker compose ps

pull: ## Pull latest images without restarting
	docker compose pull

clean: ## Stop services and remove volumes (deletes downloaded models)
	docker compose down -v

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
