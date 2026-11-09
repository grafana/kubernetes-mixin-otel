FROM golang:1.27-alpine@sha256:fa3d596898d9f126af7c01d14ee7597bab3f39cccf392ef36b69fe77cd681f18 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
RUN go mod verify
COPY . .
RUN CGO_ENABLED=0 go build -o kwok-stats-proxy .

FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/kwok-stats-proxy /usr/local/bin/
ENTRYPOINT ["kwok-stats-proxy"]

