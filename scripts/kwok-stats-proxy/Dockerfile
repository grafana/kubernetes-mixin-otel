FROM golang:1.27-alpine@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
RUN go mod verify
COPY . .
RUN CGO_ENABLED=0 go build -o kwok-stats-proxy .

FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/kwok-stats-proxy /usr/local/bin/
ENTRYPOINT ["kwok-stats-proxy"]

