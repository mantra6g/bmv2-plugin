# Shared base: download deps and copy source so neither builder re-downloads modules
FROM golang:1.26 AS base
ARG TARGETOS
ARG TARGETARCH

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY cmd/ cmd/
COPY internal/ internal/
COPY pkg/ pkg/

# Build the driver binary
FROM base AS driver-builder
# the GOARCH has not a default value to allow the binary be built according to the host where the command
# was called. For example, if we call make docker-build in a local env which has the Apple Silicon M1 SO
# the docker BUILDPLATFORM arg will be linux/arm64 when for Apple x86 it will be linux/amd64. Therefore,
# by leaving it empty we can ensure that the container and binary shipped on it will have the same platform.
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -a -o driver ./cmd/driver

# Build the manager binary
FROM base AS operator-builder
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -a -o manager ./cmd/operator

# The driver shells out to the p4c compiler (pkg/p4compile) to compile P4 sources fetched at
# runtime, so its runtime image needs p4c and its native dependencies rather than a minimal base.
FROM p4lang/p4c:latest AS driver
RUN apt-get update && apt-get install -y --no-install-recommends \
    libboost-iostreams-dev \
    libboost-graph-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /
COPY --from=driver-builder /workspace/driver .

ENTRYPOINT ["/driver"]

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM gcr.io/distroless/static:nonroot AS operator
WORKDIR /
COPY --from=operator-builder /workspace/manager .
USER 65532:65532

ENTRYPOINT ["/manager"]