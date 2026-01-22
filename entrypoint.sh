#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Ensure directories exist with proper permissions
ensure_directories() {
    log_info "Ensuring directories exist..."
    
    mkdir -p /var/cache/nginx/client_temp \
             /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp \
             /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp \
             /var/log/nginx \
             /var/log/nginx-ui \
             /etc/nginx/conf.d \
             /etc/nginx/sites-available \
             /etc/nginx/sites-enabled \
             /etc/nginx/streams-available \
             /etc/nginx/streams-enabled \
             /etc/nginx-ui

    chown -R nginx:nginx /var/cache/nginx /var/log/nginx 2>/dev/null || true
}

# Validate nginx configuration
validate_nginx_config() {
    log_info "Validating Nginx configuration..."
    if nginx -t; then
        log_info "Nginx configuration is valid"
        return 0
    else
        log_error "Nginx configuration is invalid"
        return 1
    fi
}

# Start Nginx
start_nginx() {
    log_info "Starting Nginx..."
    nginx
    
    # Wait for nginx to start
    sleep 2
    
    if [ -f /var/run/nginx.pid ]; then
        NGINX_PID=$(cat /var/run/nginx.pid)
        if kill -0 "$NGINX_PID" 2>/dev/null; then
            log_info "Nginx started successfully (PID: $NGINX_PID)"
            return 0
        fi
    fi
    
    log_error "Failed to start Nginx"
    return 1
}

# Start Nginx UI
start_nginx_ui() {
    log_info "Starting Nginx UI..."
    
    # Start Nginx UI in background
    /usr/local/bin/nginx-ui --config /etc/nginx-ui/app.ini &
    NGINX_UI_PID=$!
    
    # Wait a moment for it to start
    sleep 3
    
    if kill -0 "$NGINX_UI_PID" 2>/dev/null; then
        log_info "Nginx UI started successfully (PID: $NGINX_UI_PID)"
        echo $NGINX_UI_PID > /var/run/nginx-ui.pid
        return 0
    else
        log_error "Failed to start Nginx UI"
        return 1
    fi
}

# Handle shutdown gracefully
shutdown() {
    log_info "Shutting down..."
    
    # Stop Nginx UI
    if [ -f /var/run/nginx-ui.pid ]; then
        NGINX_UI_PID=$(cat /var/run/nginx-ui.pid)
        if kill -0 "$NGINX_UI_PID" 2>/dev/null; then
            log_info "Stopping Nginx UI..."
            kill -TERM "$NGINX_UI_PID" 2>/dev/null || true
            wait "$NGINX_UI_PID" 2>/dev/null || true
        fi
    fi
    
    # Stop Nginx
    if [ -f /var/run/nginx.pid ]; then
        NGINX_PID=$(cat /var/run/nginx.pid)
        if kill -0 "$NGINX_PID" 2>/dev/null; then
            log_info "Stopping Nginx..."
            nginx -s quit
            wait "$NGINX_PID" 2>/dev/null || true
        fi
    fi
    
    log_info "Shutdown complete"
    exit 0
}

# Monitor processes
monitor_processes() {
    while true; do
        # Check Nginx
        if [ -f /var/run/nginx.pid ]; then
            NGINX_PID=$(cat /var/run/nginx.pid)
            if ! kill -0 "$NGINX_PID" 2>/dev/null; then
                log_error "Nginx process died, restarting..."
                start_nginx
            fi
        else
            log_error "Nginx PID file not found, restarting..."
            start_nginx
        fi
        
        # Check Nginx UI
        if [ -f /var/run/nginx-ui.pid ]; then
            NGINX_UI_PID=$(cat /var/run/nginx-ui.pid)
            if ! kill -0 "$NGINX_UI_PID" 2>/dev/null; then
                log_error "Nginx UI process died, restarting..."
                start_nginx_ui
            fi
        else
            log_warn "Nginx UI PID file not found, restarting..."
            start_nginx_ui
        fi
        
        sleep 5
    done
}

# Main execution
main() {
    log_info "============================================"
    log_info "  Nginx + Active Health Check + Nginx UI   "
    log_info "============================================"
    
    # Set up signal handlers
    trap shutdown SIGTERM SIGINT SIGQUIT
    
    # Ensure directories exist
    ensure_directories
    
    # Validate and start Nginx
    if validate_nginx_config; then
        start_nginx
    else
        log_error "Cannot start with invalid configuration"
        exit 1
    fi
    
    # Start Nginx UI
    start_nginx_ui
    
    log_info "============================================"
    log_info "  Services are running:                    "
    log_info "  - Nginx:    http://localhost:80          "
    log_info "  - Status:   http://localhost:8080        "
    log_info "  - Nginx UI: http://localhost:9000        "
    log_info "============================================"
    
    # Monitor processes and keep container running
    monitor_processes
}

# Run main function
main "$@"
