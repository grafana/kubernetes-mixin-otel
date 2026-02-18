FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod main.go ./
RUN go build -o kwok-hostmetrics-faker .

FROM alpine:3.20
COPY --from=builder /app/kwok-hostmetrics-faker /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/kwok-hostmetrics-faker"]
