PWD = $(shell pwd)
TOKEN = $(shell az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
IMAGE_TAG = sha-$(shell git rev-parse --short HEAD)
# Default number of migrations to execute up or down
N = 2

.PHONY: deploy
deploy:
	@cd ./infra;./deploy.sh

.PHONY: destroy
destroy:
	az group delete --name ${CONTAINERAPP_RESOURCE_GROUP} --yes --no-wait

.PHONY: build
build:
	go build ./cmd/server

.PHONY: test
test:
	go test -v -race -shuffle=on ./...

.PHONY: tidy
tidy:
	go fmt ./...
	go mod tidy -v

.PHONY: migrate-up 
migrate-up:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" up $(N)

.PHONY: migrate-down 
migrate-down:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" down $(N)
	
.PHONY: migrate-force 
migrate-force:
	migrate -path $(PWD)/migrations -database "pgx://${PGUSER}:$(TOKEN)@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}" force $(VERSION)

.PHONY: migrate-docker-up 
migrate-docker-up:
	migrate -path $(PWD)/migrations -database "pgx://postgres:pass%40word1@localhost/todo?sslmode=allow" up $(N)

.PHONY: migrate-docker-down 
migrate-docker-down:
	migrate -path $(PWD)/migrations -database "pgx://postgres:pass%40word1@localhost/todo?sslmode=allow" down $(N)
	
.PHONY: migrate-docker-force
migrate-docker-force:
	migrate -path $(PWD)/migrations -database "pgx://postgres:pass%40word1@localhost/todo?sslmode=allow" force $(N)

.PHONY: build-image
build-image:
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME):$(IMAGE_TAG) -t $(IMAGE_NAME):latest --push .
