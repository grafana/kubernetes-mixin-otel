FROM golang:1.27-alpine@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS builder
WORKDIR /app
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN go build -o kwok-hostmetrics-faker .

FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a
COPY --from=builder /app/kwok-hostmetrics-faker /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/kwok-hostmetrics-faker"]
