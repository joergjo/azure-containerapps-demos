.DEFAULT_GOAL=build

PHONY: deploy 
deploy:
	@cd ./infra;./deploy.sh

PHONY: destroy 
destroy:
	az group delete --name ${CONTAINERAPP_RESOURCE_GROUP_NAME} --yes --no-wait

PHONY: fmt 
fmt:
	go fmt ./...

PHONY: vet 
vet: fmt
	go vet ./...

PHONY: build 
build: vet
	go build

PHONY: docker-build
docker-build: vet
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME):$(IMAGE_TAG) --push .
