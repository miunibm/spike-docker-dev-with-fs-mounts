ARG ALPINE_VERSION=3
FROM alpine:${ALPINE_VERSION}

ARG DEV_UID=1824
ARG DEV_GID=1824
ARG DEV_USER=devuser
ARG DEV_GRP=devgroup

# Install shadow and safely create/reuse group and user for arbitrary UID/GID (including GID 0 or GID 20)
RUN apk add --no-cache shadow \
    && (getent group ${DEV_GID} >/dev/null || groupadd -g ${DEV_GID} ${DEV_GRP} 2>/dev/null || true) \
    && (getent passwd ${DEV_UID} >/dev/null || useradd -u ${DEV_UID} -g ${DEV_GID} -m -s /bin/sh ${DEV_USER} 2>/dev/null || true) \
    && mkdir -p /app/packages /app/config /app/temp /app/logs \
    && chown -R ${DEV_UID}:${DEV_GID} /app

USER ${DEV_UID}
WORKDIR /app

# Keep container alive for interactive testing & execution
CMD ["sleep", "infinity"]
