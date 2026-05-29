# syntax=docker/dockerfile:1

ARG GO_VERSION=1.25
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION} AS build
ARG TARGETOS TARGETARCH
ARG VCS_REVISION=dev
ARG VCS_DATE=unknown
WORKDIR /src

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=bind,source=go.mod,target=go.mod \
    go mod download -x

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,target=. \
    GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 go build \
        -C ./cmd/server \
        -ldflags="-s -w -X 'main.vcsRevision=${VCS_REVISION}' -X 'main.vcsDate=${VCS_DATE}'" \
        -o /bin/server

FROM gcr.io/distroless/static:nonroot AS final
EXPOSE 8080
COPY --from=build /bin/server /bin/
ENTRYPOINT [ "/bin/server" ]