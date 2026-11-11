# Hardened (Project Hummingbird) FIPS Go builder, digest-pinned to a
# multi-architecture image index — same reference as rosa-seaplane-kube-applier
# and rosa-seaplane-ecr-creds-sync.
FROM registry.access.redhat.com/hi/go:latest-fips-builder@sha256:e424db07a04673ec9c732981d3d97e96044cce39215f5c528d4f549e45eb1c2c AS builder
ARG TARGETOS=linux
ARG TARGETARCH=amd64
USER root

WORKDIR /workspace
ENV GOCACHE=/workspace/.cache/go-build

COPY go.mod go.sum ./
RUN go mod download
COPY . .

# `make print-version` is the repository's single VERSION parser (see Makefile);
# the hardened builder provides make and ships no awk.
RUN git config --global --add safe.directory /workspace && \
    ZOA_VERSION=$(make print-version) && \
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") && \
    BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) && \
    VERSION_PKG="github.com/openshift-online/rosa-seaplane-zoa/internal/version" && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -buildvcs=false \
    -ldflags="-w -s -X ${VERSION_PKG}.Version=${ZOA_VERSION} -X ${VERSION_PKG}.GitCommit=${GIT_COMMIT} -X ${VERSION_PKG}.BuildDate=${BUILD_DATE}" \
    -o /workspace/zoa-lambda ./cmd/zoa-lambda/

# Hardened FIPS runtime (GODEBUG=fips140=on), digest-pinned multi-architecture index.
FROM registry.access.redhat.com/hi/go:latest-fips@sha256:275df00eba7680ddee0a3701af59af981a4c9a6fad41a84e0bc371c778ed21e8

ARG VERSION=0.0.1
ARG RELEASE=1

LABEL name="zoa-lambda" \
      vendor="Red Hat, Inc." \
      version="${VERSION}" \
      release="${RELEASE}" \
      summary="ZOA Lambda function" \
      description="Minimal Lambda image for ZOA API, Worker, and Access" \
      io.k8s.display-name="zoa-lambda" \
      io.k8s.description="ZOA Lambda function for API, Worker, and Access (HANDLER_MODE)" \
      com.redhat.component="zoa-lambda-container" \
      distribution-scope="public" \
      url="https://github.com/openshift-online/rosa-seaplane-zoa"

COPY --from=builder /workspace/zoa-lambda /usr/local/bin/zoa-lambda

USER 65534:65534

ENTRYPOINT ["/usr/local/bin/zoa-lambda"]
