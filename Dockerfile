FROM alpine:3.19

LABEL maintainer="changelog-generator"
LABEL description="GitHub Action that auto-generates CHANGELOG.md from Conventional Commits"

RUN apk add --no-cache \
    bash \
    git \
    curl \
    jq \
    grep \
    sed \
    coreutils

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
