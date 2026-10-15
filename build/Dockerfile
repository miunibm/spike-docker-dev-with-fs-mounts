ARG ALPINE_VERSION=3
FROM alpine:${ALPINE_VERSION}

ARG DEV_UID=1824
ARG DEV_GID=1824
ARG DEV_USER=devuser
ARG DEV_GRP=devgroup

# Install shadow (for groupadd/useradd) and create non-root user mimicking vendor/runtime UID
RUN apk add --no-cache shadow \
    && groupadd -g ${DEV_GID} ${DEV_GRP} \
    && useradd -u ${DEV_UID} -g ${DEV_GID} -m -s /bin/sh ${DEV_USER} \
    && mkdir -p /app/packages /app/config /app/temp /app/logs \
    && chown -R ${DEV_UID}:${DEV_GID} /app

USER ${DEV_USER}
WORKDIR /app

# Keep container alive for interactive testing & execution
CMD ["sleep", "infinity"]
