# Nginx with Active Health Check + Nginx UI

[![Build and Push Docker Image](https://github.com/deviant101/nginx-active-healthcheck-ui/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/deviant101/nginx-active-healthcheck-ui/actions/workflows/docker-publish.yml)

This Docker image combines:
- **Nginx Open Source** (v1.24.0) compiled from source
- **Active Health Check Module** ([nginx_upstream_check_module](https://github.com/yaoweibin/nginx_upstream_check_module))
- **Nginx UI** (Web-based management interface)

> 🎯 **A free alternative to Nginx Plus active health checks** - Get enterprise-grade health checking without the enterprise price tag!

## Features

- ✅ Active health checks for upstream servers (similar to Nginx Plus)
- ✅ Web-based UI for managing Nginx configurations
- ✅ SSL/TLS support with HTTP/2
- ✅ Stream module for TCP/UDP load balancing
- ✅ Real-time upstream health status monitoring
- ✅ Configuration editor with syntax highlighting
- ✅ Let's Encrypt certificate management

## Quick Start

### Method 1: Pull and Run (Simplest)

```bash
docker pull ghcr.io/deviant101/nginx-active-healthcheck-ui:latest

docker run -d \
  --name nginx-healthcheck-ui \
  -p 80:80 \
  -p 443:443 \
  -p 8080:8080 \
  -p 9000:9000 \
  -v nginx_config:/etc/nginx \
  -v nginx_ui_config:/etc/nginx-ui \
  --restart unless-stopped \
  ghcr.io/deviant101/nginx-active-healthcheck-ui:latest
```

### Method 2: Building from Source

```bash
git clone https://github.com/deviant101/nginx-active-healthcheck-ui.git
cd nginx-active-healthcheck-ui
```

**Option A:** Using Docker Compose
```bash
docker-compose up -d --build
```

**Option B:** Build and run manually
```bash
docker build -t nginx-healthcheck-ui .

docker run -d \
  --name nginx-healthcheck-ui \
  -p 80:80 \
  -p 443:443 \
  -p 8080:8080 \
  -p 9000:9000 \
  -v nginx_config:/etc/nginx \
  -v nginx_ui_config:/etc/nginx-ui \
  --restart unless-stopped \
  nginx-healthcheck-ui
```

## Accessing Services

| Service | URL | Description |
|---------|-----|-------------|
| Nginx | http://localhost:80 | Main HTTP server |
| Nginx (HTTPS) | https://localhost:443 | Main HTTPS server |
| Nginx Status | http://localhost:8080/nginx_status | Nginx stub status |
| Health Check Status | http://localhost:8080/upstream_status | Active health check status (HTML) |
| Health Check JSON | http://localhost:8080/upstream_status_json | Active health check status (JSON) |
| Nginx UI | http://localhost:9000 | Web management interface |

## First Time Setup

1. Access Nginx UI at `http://localhost:9000`
2. Create your admin account on first visit
3. Configure your upstream servers and sites through the UI

## Active Health Check Configuration

Add active health checks to your upstream blocks in nginx configuration:

```nginx
upstream backend {
    server backend1.example.com:8080;
    server backend2.example.com:8080;
    server backend3.example.com:8080;

    # Active health check configuration
    check interval=3000 rise=2 fall=3 timeout=1000 type=http;
    check_http_send "HEAD /health HTTP/1.0\r\n\r\n";
    check_http_expect_alive http_2xx http_3xx;
}
```

### Health Check Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `interval` | Check interval in milliseconds | `interval=3000` (3 seconds) |
| `rise` | Number of successful checks to mark server as up | `rise=2` |
| `fall` | Number of failed checks to mark server as down | `fall=3` |
| `timeout` | Timeout for health check in milliseconds | `timeout=1000` |
| `type` | Check type (tcp, http, ssl_hello, mysql, ajp) | `type=http` |

### Health Check Types

- **tcp**: Simple TCP connection check
- **http**: HTTP request check
- **ssl_hello**: SSL handshake check
- **mysql**: MySQL protocol check
- **ajp**: AJP protocol check

## Directory Structure

```
/etc/nginx/
├── nginx.conf           # Main configuration
├── conf.d/              # Additional configurations
├── sites-available/     # Available site configurations
├── sites-enabled/       # Enabled site configurations
├── streams-available/   # Available stream configurations
├── streams-enabled/     # Enabled stream configurations
└── ssl/                 # SSL certificates

/etc/nginx-ui/
├── app.ini              # Nginx UI configuration
└── database.db          # Nginx UI database

/var/log/nginx/
├── access.log           # Nginx access log
└── error.log            # Nginx error log
```

## Environment Variables

You can customize the Nginx UI configuration by mounting your own `app.ini` file or setting these in the configuration:

- `HttpPort`: Nginx UI port (default: 9000)
- `JWTSecret`: JWT secret for authentication
- `Database`: Path to SQLite database

## Volumes

| Volume | Path | Description |
|--------|------|-------------|
| nginx_config | /etc/nginx | Nginx configuration files |
| nginx_ui_config | /etc/nginx-ui | Nginx UI configuration and database |
| nginx_logs | /var/log/nginx | Nginx log files |
| nginx_ui_logs | /var/log/nginx-ui | Nginx UI log files |

## Security Notes

1. **Change default secrets**: Update `JWTSecret` and `Secret` in `/etc/nginx-ui/app.ini`
2. **Restrict status endpoints**: The status endpoints are restricted to private networks by default
3. **Use HTTPS**: Configure SSL/TLS for production environments
4. **Firewall**: Consider restricting access to port 9000 (Nginx UI)

## Example: Load Balancer with Health Checks

```nginx
upstream api_servers {
    server api1.internal:3000;
    server api2.internal:3000;
    server api3.internal:3000;

    # Health check every 5 seconds
    # Mark as UP after 2 successful checks
    # Mark as DOWN after 3 failed checks
    check interval=5000 rise=2 fall=3 timeout=2000 type=http;
    check_http_send "GET /api/health HTTP/1.1\r\nHost: localhost\r\n\r\n";
    check_http_expect_alive http_2xx;
}

server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://api_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Troubleshooting

### Check Nginx Status
```bash
docker exec nginx-ui-healthcheck nginx -t
docker exec nginx-ui-healthcheck nginx -s reload
```

### View Logs
```bash
# Nginx logs
docker logs nginx-ui-healthcheck

# Or access log files directly
docker exec nginx-ui-healthcheck tail -f /var/log/nginx/error.log
```

### Check Health Status
```bash
curl http://localhost:8080/upstream_status
curl http://localhost:8080/upstream_status_json
```

## License

- Nginx: [BSD-like license](http://nginx.org/LICENSE)
- nginx_upstream_check_module: [BSD license](https://github.com/yaoweibin/nginx_upstream_check_module)
- Nginx UI: [AGPL-3.0 license](https://github.com/0xJacky/nginx-ui)
