# Local dev: MongoDB only (docker-compose.dev.yml)
COMPOSE_DEV = docker-compose -f docker-compose.dev.yml

up-local:
	$(COMPOSE_DEV) up -d

down-local:
	$(COMPOSE_DEV) down
