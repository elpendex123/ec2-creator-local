#!/bin/bash
# Server management using systemd user service
# No root required - systemd user services run as the current user
# Much more reliable than manual process management

set -euo pipefail

ACTION="${1:-status}"
BUILD_WORKSPACE="${2:-.}"
APP_HOST="${3:-0.0.0.0}"
APP_PORT="${4:-8000}"
SERVICE_NAME="ec2-provisioner"

# Helper to run systemctl with proper error handling
run_systemctl() {
    if systemctl --user "$@" 2>/dev/null; then
        return 0
    else
        # Fallback: try with sudo if systemctl --user fails
        sudo systemctl --user "$@" 2>/dev/null || return 1
    fi
}

# Check if systemd user service is available
if ! run_systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
    echo "✗ ERROR: Systemd user service is not set up"
    echo ""
    echo "Please run the setup script first:"
    echo "  ./scripts/setup_systemd_service.sh $BUILD_WORKSPACE"
    echo ""
    return 1
fi

start_server() {
    echo "Starting EC2 Provisioner API server..."

    # Check if already running
    if run_systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✓ Server is already running"
        run_systemctl status "$SERVICE_NAME" --no-pager | grep -E "Active|Main PID"
        return 0
    fi

    # Start the service
    run_systemctl start "$SERVICE_NAME"

    # Wait for startup
    sleep 2

    # Verify it started
    if run_systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✓ Server started successfully"
        run_systemctl status "$SERVICE_NAME" --no-pager | grep -E "Active|Main PID"
        return 0
    else
        echo "✗ Server failed to start"
        echo ""
        echo "Recent logs:"
        journalctl --user -u "$SERVICE_NAME" -n 20 --no-pager
        return 1
    fi
}

stop_server() {
    echo "Stopping EC2 Provisioner API server..."

    if ! run_systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✓ Server is not running"
        return 0
    fi

    # Stop the service
    run_systemctl stop "$SERVICE_NAME"

    # Wait for shutdown
    sleep 1

    # Verify it stopped
    if run_systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✗ Server failed to stop"
        return 1
    else
        echo "✓ Server stopped successfully"
        return 0
    fi
}

status_server() {
    echo "EC2 Provisioner API Server Status"
    echo "=================================="

    if run_systemctl is-active --quiet "$SERVICE_NAME"; then
        run_systemctl status "$SERVICE_NAME" --no-pager

        # Check health endpoint
        if curl -s "http://localhost:$APP_PORT/health" >/dev/null 2>&1; then
            HEALTH=$(curl -s "http://localhost:$APP_PORT/health")
            echo ""
            echo "✓ Health check passed: $HEALTH"
            return 0
        else
            echo ""
            echo "⚠ Server running but health check failed"
            return 1
        fi
    else
        echo "✗ Server is not running"
        run_systemctl status "$SERVICE_NAME" --no-pager || true
        return 1
    fi
}

case "$ACTION" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    status)
        status_server
        ;;
    restart)
        echo "Restarting EC2 Provisioner API server..."
        run_systemctl restart "$SERVICE_NAME"
        sleep 2
        if run_systemctl is-active --quiet "$SERVICE_NAME"; then
            echo "✓ Server restarted successfully"
            return 0
        else
            echo "✗ Server failed to restart"
            return 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart} [BUILD_WORKSPACE] [APP_HOST] [APP_PORT]"
        echo ""
        echo "Setup: $0 setup <BUILD_WORKSPACE>"
        exit 1
        ;;
esac
