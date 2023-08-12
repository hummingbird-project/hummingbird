# ================================
# Build image
# ================================
FROM swift:5.7 as build

WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

RUN swift test --enable-test-discovery --sanitize=thread
