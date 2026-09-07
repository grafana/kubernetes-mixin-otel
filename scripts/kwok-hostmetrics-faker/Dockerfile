FROM golang:1.27-alpine@sha256:cf6fca6641884b8433441b2b0652976f975e1d0fdd26d177eaaf8596087f3125 AS builder
WORKDIR /app
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN go build -o kwok-hostmetrics-faker .

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b
COPY --from=builder /app/kwok-hostmetrics-faker /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/kwok-hostmetrics-faker"]
