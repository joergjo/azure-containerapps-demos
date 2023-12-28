.DEFAULT_GOAL=build
PHONY: fmt vet build docker-build

fmt:
	go fmt ./...

vet: fmt
	go vet ./...

build: vet
	go build

docker-build: vet
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME):$(IMAGE_TAG) --push .
