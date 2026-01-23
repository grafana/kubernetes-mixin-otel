FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum* ./
RUN go mod download || true
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o kwok-stats-proxy .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/kwok-stats-proxy /usr/local/bin/
ENTRYPOINT ["kwok-stats-proxy"]

