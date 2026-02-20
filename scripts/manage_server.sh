#!/bin/bash
# Professional server management script
# This script handles starting, stopping, and checking the uvicorn server
# using proper process management

set -euo pipefail

ACTION="${1:-status}"
BUILD_WORKSPACE="${2:-.}"
APP_HOST="${3:-0.0.0.0}"
APP_PORT="${4:-8000}"
PID_FILE="/tmp/ec2-provisioner.pid"

start_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "✗ Server is already running with PID $PID"
            return 1
        else
            echo "Removing stale PID file"
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
    fi

    echo "Starting uvicorn server..."
    cd "$BUILD_WORKSPACE"

    # Start the process with nohup and proper backgrounding
    # nohup ensures it survives SIGHUP, < /dev/null disconnects stdin
    nohup python3 -m uvicorn app.main:app \
        --host "$APP_HOST" \
        --port "$APP_PORT" \
        < /dev/null > /tmp/uvicorn.log 2>&1 &

    # Save PID
    echo $! > "$PID_FILE"
    PID=$!

    echo "✓ Server started with PID $PID"

    # Wait for startup
    sleep 3

    # Verify it's actually running
    if kill -0 "$PID" 2>/dev/null; then
        echo "✓ Server is running"
        return 0
    else
        echo "✗ Server failed to start"
        rm -f "$PID_FILE"
        tail -20 /tmp/uvicorn.log
        return 1
    fi
}

stop_server() {
    if [ ! -f "$PID_FILE" ]; then
        echo "✓ Server is not running"
        return 0
    fi

    PID=$(cat "$PID_FILE")

    if ! kill -0 "$PID" 2>/dev/null; then
        echo "✓ Server is not running (stale PID file)"
        rm -f "$PID_FILE"
        return 0
    fi

    echo "Stopping server (PID $PID)..."

    # Try graceful shutdown
    if kill -TERM "$PID" 2>/dev/null; then
        echo "Sent SIGTERM to $PID"

        # Wait for graceful shutdown
        sleep 2

        if kill -0 "$PID" 2>/dev/null; then
            echo "Process still running, sending SIGKILL..."
            kill -9 "$PID" 2>/dev/null || true
            sleep 1
        fi
    fi

    rm -f "$PID_FILE" 2>/dev/null || true
    echo "✓ Server stopped"
    return 0
}

status_server() {
    if [ ! -f "$PID_FILE" ]; then
        echo "✗ Server is not running (no PID file)"
        return 1
    fi

    PID=$(cat "$PID_FILE")

    if ! kill -0 "$PID" 2>/dev/null; then
        echo "✗ Server is not running (PID $PID not found)"
        rm -f "$PID_FILE"
        return 1
    fi

    echo "✓ Server is running with PID $PID"

    # Check health endpoint
    if curl -s http://localhost:"$APP_PORT"/health > /dev/null 2>&1; then
        HEALTH=$(curl -s http://localhost:"$APP_PORT"/health)
        echo "✓ Health check passed: $HEALTH"
        return 0
    else
        echo "⚠ Server running but health check failed"
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
        stop_server
        sleep 1
        start_server
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart} [BUILD_WORKSPACE] [APP_HOST] [APP_PORT]"
        exit 1
        ;;
esac
