FROM ghcr.io/getsops/sops:v3.13.3-alpine AS sops-bin

FROM alpine:latest
COPY --from=sops-bin /usr/local/bin/sops /usr/local/bin/sops
ENV SOPS_AGE_KEY_FILE=/tmp/age.key
USER 1000:1000
