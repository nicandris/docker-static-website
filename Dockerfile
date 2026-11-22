ARG ALPINE_VERSION=latest

FROM alpine:${ALPINE_VERSION} AS builder

ARG BUSYBOX_VERSION=1.38.0
# Must match BUSYBOX_VERSION, see https://busybox.net/downloads/busybox-<version>.tar.bz2.sha256
ARG BUSYBOX_SHA256=34f9ea6ff8636f2c9241153b9114eefa9e65674a45318ae1ef95bb5f31c53bb2

# Install all dependencies required for compiling busybox
RUN apk add --no-cache gcc musl-dev make perl

# Download busybox sources and verify the checksum
RUN wget https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 \
  && echo "${BUSYBOX_SHA256}  busybox-${BUSYBOX_VERSION}.tar.bz2" | sha256sum -c - \
  && tar xf busybox-${BUSYBOX_VERSION}.tar.bz2 \
  && mv /busybox-${BUSYBOX_VERSION} /busybox

WORKDIR /busybox

# Copy the busybox build config (limited to httpd)
COPY .config .

# Compile
RUN make && ./make_single_applets.sh

# Create a non-root user to own the files and run our server
RUN adduser -D static

# Switch to the scratch image
FROM scratch

EXPOSE 3000

# Copy over the user
COPY --from=builder /etc/passwd /etc/passwd

# Copy the static binary
COPY --from=builder /busybox/busybox_HTTPD /busybox-httpd

# Use our non-root user
USER static
WORKDIR /home/static

# Uploads a blank default httpd.conf
# This is only needed in order to set the `-c` argument in this base file
# and save the developer the need to override the CMD line in case they ever
# want to use a httpd.conf
COPY httpd.conf .

# Copy the static website
# Use the .dockerignore file to control what ends up inside the image!
# NOTE: Commented out since this will also copy the .config file
# COPY . .

# Run busybox httpd
CMD ["/busybox-httpd", "-f", "-v", "-p", "3000"]
