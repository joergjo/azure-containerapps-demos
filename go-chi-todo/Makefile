SHELL=/bin/bash
PWD = $(shell pwd)
TOKEN = $(shell az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
# Default number of migrations to execute up or down
N = 2

.PHONY: migrate-up migrate-down migrate-force migrate-docker-up migrate-docker-down build-image deploy

migrate-up:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" up $(N)

migrate-down:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" down $(N)
	
migrate-force:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" force $(VERSION)

migrate-docker-up:
	migrate -path $(PWD)/migrations -database "pgx://postgres:pass%40word1@localhost/todo?sslmode=allow" up $(N)

migrate-docker-down:
	migrate -path $(PWD)/migrations -database "pgx://postgres:pass%40word1@localhost/todo?sslmode=allow" down $(N)
	
migrate-docker-force:
	migrate -path $(PWD)/migrations -database "pgx://postgres:pass%40word1@localhost/todo?sslmode=allow" force $(N)

build-image:
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME):$(IMAGE_TAG) --push .

deploy:
	@cd ./infra;./deploy.sh