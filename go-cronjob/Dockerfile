FROM golang:1.18 AS builder

WORKDIR /build

# Enable Go's DNS resolver to read from /etc/hosts
RUN echo "hosts: files dns" > /etc/nsswitch.conf.min

# Create a minimal passwd so we can run as non-root in the container
RUN echo "nobody:x:65534:65534:Nobody:/:" > /etc/passwd.min

# Fetch latest CA certificates
RUN apt-get update && \
    apt-get install -y ca-certificates

# Only download Go modules (improves build caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy our source code over and build the binary
COPY . .
RUN CGO_ENABLED=0 go build -ldflags '-s -w' -tags 'osusergo netgo' -o cronjob ./main.go

FROM scratch AS final
EXPOSE 8000

# Copy over the binary artifact
COPY --from=builder /build/cronjob /

# Copy configuration from builder
COPY --from=builder /etc/nsswitch.conf.min /etc/nsswitch.conf
COPY --from=builder /etc/passwd.min /etc/passwd
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

USER nobody
ENTRYPOINT ["/cronjob"]
