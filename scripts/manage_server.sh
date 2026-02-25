#!/bin/bash
# Professional server management script
# This script handles starting, stopping, and checking the uvicorn server
# Only the jenkins user should manage servers started via Jenkins jobs
# Manual servers (started by other users) must be stopped manually

set -euo pipefail

ACTION="${1:-status}"
BUILD_WORKSPACE="${2:-.}"
APP_HOST="${3:-0.0.0.0}"
APP_PORT="${4:-8000}"
# Use workspace-specific PID file to avoid permission conflicts between jenkins and local user
PID_FILE="${BUILD_WORKSPACE}/.pid"

# Helper function to check if server is running and get its owner
check_running_server() {
    # Use netstat/ss to find process on the port
    if command -v lsof >/dev/null 2>&1; then
        RUNNING_PID=$(lsof -t -i :"$APP_PORT" 2>/dev/null | head -1)
    else
        # Fallback for systems without lsof
        RUNNING_PID=$(netstat -tulpn 2>/dev/null | grep ":$APP_PORT " | awk '{print $NF}' | cut -d'/' -f1 | head -1)
    fi

    if [ -n "$RUNNING_PID" ]; then
        RUNNING_USER=$(ps -o user= -p "$RUNNING_PID" 2>/dev/null || echo "unknown")
        echo "$RUNNING_PID|$RUNNING_USER"
    else
        echo ""
    fi
}

start_server() {
    # Check if any server is already running on the port
    RUNNING_INFO=$(check_running_server)

    if [ -n "$RUNNING_INFO" ]; then
        RUNNING_PID=$(echo "$RUNNING_INFO" | cut -d'|' -f1)
        RUNNING_USER=$(echo "$RUNNING_INFO" | cut -d'|' -f2)

        # If it's running as jenkins, we can manage it
        if [ "$RUNNING_USER" = "jenkins" ]; then
            echo "$RUNNING_PID" > "$PID_FILE" 2>/dev/null || true
            echo "✓ Server is already running on port $APP_PORT (PID $RUNNING_PID, owned by jenkins)"
            return 0
        else
            # Server is running but owned by a different user - fail with clear message
            echo "✗ ERROR: Server is already running on port $APP_PORT (PID $RUNNING_PID, owned by $RUNNING_USER)"
            echo "This server was started manually and must be stopped manually by the $RUNNING_USER user"
            echo "Run: pkill -f 'uvicorn app.main' (as the $RUNNING_USER user)"
            return 1
        fi
    fi

    # Check if stale PID file exists and clean it up
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ! kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Removing stale PID file"
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
    fi

    echo "Starting uvicorn server as jenkins user..."
    cd "$BUILD_WORKSPACE"

    # Use setsid to completely detach from Jenkins process group
    # This ensures Jenkins can't kill the process when it terminates
    setsid nohup python3 -m uvicorn app.main:app \
        --host "$APP_HOST" \
        --port "$APP_PORT" \
        < /dev/null > /tmp/uvicorn.log 2>&1 &

    PROC_PID=$!
    echo "$PROC_PID" > "$PID_FILE"

    echo "✓ Server started with PID $PROC_PID (jenkins user)"

    # Wait for uvicorn to start and initialize
    sleep 4

    # Find the actual uvicorn process (setsid creates a new session, so the PID might be different)
    ACTUAL_PID=$(pgrep -f "python3 -m uvicorn app.main:app" | head -1)

    if [ -z "$ACTUAL_PID" ]; then
        echo "✗ Server failed to start or crashed during initialization"
        rm -f "$PID_FILE"
        echo ""
        echo "Last 30 lines of /tmp/uvicorn.log:"
        tail -30 /tmp/uvicorn.log
        return 1
    fi

    # Update PID file with actual uvicorn PID
    echo "$ACTUAL_PID" > "$PID_FILE"
    echo "✓ Server is running with PID $ACTUAL_PID"
    return 0
}

stop_server() {
    # Check if any server is running
    RUNNING_INFO=$(check_running_server)

    if [ -z "$RUNNING_INFO" ]; then
        echo "✓ Server is not running"
        rm -f "$PID_FILE" 2>/dev/null || true
        return 0
    fi

    RUNNING_PID=$(echo "$RUNNING_INFO" | cut -d'|' -f1)
    RUNNING_USER=$(echo "$RUNNING_INFO" | cut -d'|' -f2)

    # Only jenkins can stop servers
    if [ "$RUNNING_USER" != "jenkins" ]; then
        echo "✗ ERROR: Server is owned by $RUNNING_USER user and cannot be stopped by jenkins"
        echo "Please stop it manually: pkill -f 'uvicorn app.main' (as the $RUNNING_USER user)"
        return 1
    fi

    echo "Stopping server (PID $RUNNING_PID, jenkins user)..."

    # Try graceful shutdown
    if kill -TERM "$RUNNING_PID" 2>/dev/null; then
        echo "Sent SIGTERM to $RUNNING_PID"

        # Wait for graceful shutdown
        sleep 2

        if kill -0 "$RUNNING_PID" 2>/dev/null; then
            echo "Process still running, sending SIGKILL..."
            kill -9 "$RUNNING_PID" 2>/dev/null || true
            sleep 1
        fi
    fi

    rm -f "$PID_FILE" 2>/dev/null || true
    echo "✓ Server stopped"
    return 0
}

status_server() {
    RUNNING_INFO=$(check_running_server)

    if [ -z "$RUNNING_INFO" ]; then
        echo "✗ Server is not running"
        rm -f "$PID_FILE" 2>/dev/null || true
        return 1
    fi

    RUNNING_PID=$(echo "$RUNNING_INFO" | cut -d'|' -f1)
    RUNNING_USER=$(echo "$RUNNING_INFO" | cut -d'|' -f2)

    echo "✓ Server is running with PID $RUNNING_PID (owned by $RUNNING_USER)"

    # Only check health for jenkins-owned servers
    if [ "$RUNNING_USER" = "jenkins" ]; then
        if curl -s http://localhost:"$APP_PORT"/health > /dev/null 2>&1; then
            HEALTH=$(curl -s http://localhost:"$APP_PORT"/health)
            echo "✓ Health check passed: $HEALTH"
            return 0
        else
            echo "⚠ Server running but health check failed"
            return 1
        fi
    else
        echo "⚠ This server is owned by $RUNNING_USER and may not be manageable by Jenkins"
        return 0
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
