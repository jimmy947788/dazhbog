# syntax=docker/dockerfile:1.7

# Raspberry Pi 5 (BCM2712, Cortex-A76) runs aarch64 userspace. Both stages are
# pinned to linux/arm64 so the image matches that architecture.
ARG BUILDPLATFORM
ARG TARGETPLATFORM

# Build stage - use bookworm-based rust image to match runtime glibc
FROM --platform=linux/arm64 rust:1.91-slim-bookworm as builder

ARG BUILDPLATFORM
ARG TARGETPLATFORM

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y pkg-config libssl-dev cmake clang && \
    rm -rf /var/lib/apt/lists/*

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Copy source code
COPY src ./src

# Build for release. Only the two binaries copied into the runtime image.
RUN echo "Building on ${BUILDPLATFORM:-unknown} for linux/arm64 (requested ${TARGETPLATFORM:-unset})" && \
    cargo build --locked --release --bin dazhbog --bin dazhbog-recover

# Runtime stage - must match builder's glibc version
FROM --platform=linux/arm64 debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates libssl3 && \
    rm -rf /var/lib/apt/lists/*

# Copy the binary from builder
COPY --from=builder /app/target/release/dazhbog /app/dazhbog
COPY --from=builder /app/target/release/dazhbog-recover /app/dazhbog-recover

# Copy config if needed (data should be mounted as volume)
COPY config.toml ./

# Expose ports (Lumina RPC + HTTP metrics)
EXPOSE 1234 8080

# Run the binary
CMD ["./dazhbog", "config.toml"]
