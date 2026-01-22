# Multi-stage build for NGINX with active health check module and Nginx UI
FROM ubuntu:22.04 as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    wget \
    git \
    patch \
    && rm -rf /var/lib/apt/lists/*

# Set NGINX version
ENV NGINX_VERSION=1.24.0

# Download and extract NGINX source
WORKDIR /tmp
RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz

# Clone the health check module
RUN git clone https://github.com/yaoweibin/nginx_upstream_check_module.git

# Apply patch and compile NGINX with health check module
WORKDIR /tmp/nginx-${NGINX_VERSION}
RUN patch -p1 < /tmp/nginx_upstream_check_module/check_1.20.1+.patch

RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_slice_module \
    --with-file-aio \
    --with-http_v2_module \
    --add-module=/tmp/nginx_upstream_check_module && \
    make && \
    make install

# Final stage
FROM ubuntu:22.04

# Set Nginx UI version
ENV NGINX_UI_VERSION=2.3.2

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpcre3 \
    libssl3 \
    zlib1g \
    curl \
    ca-certificates \
    logrotate \
    && rm -rf /var/lib/apt/lists/*

# Create nginx user and group
RUN groupadd nginx && \
    useradd -g nginx -s /sbin/nologin -M nginx

# Copy compiled NGINX from builder
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx

# Create necessary directories
RUN mkdir -p /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp \
    /var/log/nginx \
    && chown -R nginx:nginx /var/cache/nginx /var/log/nginx

# Create directory for custom configuration
RUN mkdir -p /etc/nginx/conf.d \
    /etc/nginx/streams-available \
    /etc/nginx/streams-enabled \
    /etc/nginx/sites-available \
    /etc/nginx/sites-enabled

# Download and install Nginx UI
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then ARCH="64"; \
    elif [ "$ARCH" = "arm64" ]; then ARCH="arm64"; \
    elif [ "$ARCH" = "armhf" ]; then ARCH="arm"; \
    fi && \
    curl -sL "https://github.com/0xJacky/nginx-ui/releases/download/v${NGINX_UI_VERSION}/nginx-ui-linux-${ARCH}.tar.gz" -o /tmp/nginx-ui.tar.gz && \
    tar -xzf /tmp/nginx-ui.tar.gz -C /tmp && \
    mv /tmp/nginx-ui /usr/local/bin/nginx-ui && \
    chmod +x /usr/local/bin/nginx-ui && \
    rm -rf /tmp/nginx-ui.tar.gz

# Create Nginx UI directories
RUN mkdir -p /etc/nginx-ui /var/log/nginx-ui

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx-ui.conf /etc/nginx-ui/app.ini
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
# 80: HTTP
# 443: HTTPS
# 8080: Nginx status/health check
# 9000: Nginx UI
EXPOSE 80 443 8080 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/nginx_status || exit 1

# Volumes for persistence
VOLUME ["/etc/nginx", "/etc/nginx-ui", "/var/log/nginx", "/var/log/nginx-ui"]

# Start both Nginx and Nginx UI
ENTRYPOINT ["/entrypoint.sh"]
