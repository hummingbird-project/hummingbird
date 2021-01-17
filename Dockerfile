FROM swift:5.3-focal as builder

WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

RUN swift build --enable-test-discovery

WORKDIR /staging
RUN cp "$(swift build --package-path /build -c debug --show-bin-path)/test-framework" ./Run

# ================================
# Run image
# ================================
FROM swift:5.3-focal-slim

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get -q update && apt-get -q dist-upgrade -y && rm -r /var/lib/apt/lists/*

# Create a hummingbird user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app hummingbird

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=builder --chown=hummingbird:hummingbird /staging /app

# Ensure all further commands run as the hummingbird user
USER hummingbird:hummingbird

# Let Docker bind to port 8080
EXPOSE 8080

# set host environment variable
ENV HOST=0.0.0.0

# Start the Hummingbird service when the image is run, default to listening on 8080 in production environment
CMD ["./Run"]
