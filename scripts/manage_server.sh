#!/bin/bash
# Simple server management - just start/stop uvicorn directly
# No complicated systemd or daemonization - keep it simple

set -euo pipefail

ACTION="${1:-status}"
BUILD_WORKSPACE="${2:-.}"
APP_PORT="${4:-8000}"

start_server() {
    echo "Starting EC2 Provisioner API server..."

    # Check if already running
    if pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        PID=$(pgrep -f "python3 -m uvicorn app.main:app" | head -1)
        echo "✓ Server is already running (PID $PID)"
        return 0
    fi

    # Start in background, redirect output, and detach immediately
    cd "$BUILD_WORKSPACE"
    nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &
    BG_PID=$!

    # Immediately return without waiting - this is critical
    # If we wait, Jenkins will kill the background process when the script exits
    disown $BG_PID 2>/dev/null || true

    echo "✓ Server started (PID $BG_PID)"
    echo "  Logs: tail -f /tmp/uvicorn.log"

    # Don't wait - just return immediately
    return 0
}

stop_server() {
    echo "Stopping EC2 Provisioner API server..."

    if ! pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        echo "✓ Server is not running"
        return 0
    fi

    pkill -f "python3 -m uvicorn app.main:app" || true
    sleep 1

    if pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        echo "⚠ Forcing kill..."
        pkill -9 -f "python3 -m uvicorn app.main:app" || true
    fi

    echo "✓ Server stopped"
    return 0
}

status_server() {
    echo "EC2 Provisioner API Server Status"
    echo "=================================="

    if pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        PID=$(pgrep -f "python3 -m uvicorn app.main:app" | head -1)
        echo "✓ Server is running (PID $PID)"

        if curl -s "http://localhost:$APP_PORT/health" >/dev/null 2>&1; then
            HEALTH=$(curl -s "http://localhost:$APP_PORT/health")
            echo "✓ Health check passed: $HEALTH"
            return 0
        else
            echo "⚠ Server running but health check failed"
            return 1
        fi
    else
        echo "✗ Server is not running"
        return 1
    fi
}

restart_server() {
    echo "Restarting EC2 Provisioner API server..."
    stop_server || true
    sleep 1
    start_server
}

# Execute the requested action
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
        restart_server
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart} [BUILD_WORKSPACE] [APP_HOST] [APP_PORT]"
        exit 1
        ;;
esac

exit $?
