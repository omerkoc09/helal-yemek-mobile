# syntax=docker/dockerfile:1

# ── Derleme aşaması ───────────────────────────────────────────────────────────
FROM golang:1.25-alpine AS builder

WORKDIR /src

# Bağımlılıklar önce: kaynak değiştiğinde bu katman cache'ten gelir.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# CGO kapalı: statik binary üretir, scratch/alpine'da ek kütüphane gerekmez.
# -trimpath: binary'de yerel dosya yolları kalmasın.
# -s -w: sembol tablosu ve DWARF atılır, binary küçülür.
# Migration'lar go:embed ile binary'ye gömülü olduğu için ayrıca kopyalanmaz.
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/api ./cmd/api

# ── Çalışma aşaması ───────────────────────────────────────────────────────────
FROM alpine:3.21

# ca-certificates: Google Places/idtoken gibi HTTPS çağrıları için şart.
# tzdata: scheduler yerel saate göre çalışıyor (SCHEDULER_RUN_HOUR).
RUN apk add --no-cache ca-certificates tzdata

# Root olmayan kullanıcı.
RUN adduser -D -u 10001 appuser

WORKDIR /app
COPY --from=builder /out/api /app/api

# Yüklenen fotoğraflar buraya yazılıyor (StorageService baseDir "./uploads").
# UYARI: container katmanı kalıcı değil — prod'da volume bağlanmalı veya
# Faz 3'teki S3 geçişi tamamlanmalı, aksi halde restart'ta fotoğraflar kaybolur.
RUN mkdir -p /app/uploads && chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

# Not: healthcheck burada tanımlı değil; readiness kontrolü orkestratöre
# (compose/k8s) bırakıldı — /health ucu bunun için var.
ENTRYPOINT ["/app/api"]
