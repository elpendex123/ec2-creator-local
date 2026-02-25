#!/bin/bash
# Server management using systemd user service
# No root required - systemd user services run as the current user
# Much more reliable process management

set -euo pipefail

ACTION="${1:-status}"
BUILD_WORKSPACE="${2:-.}"
APP_HOST="${3:-0.0.0.0}"
APP_PORT="${4:-8000}"
SERVICE_NAME="ec2-provisioner"

# Helper to run systemctl - use machine notation for Jenkins environment
run_systemctl() {
    # In Jenkins (no active session), use --machine=jenkins@.host notation
    # This connects to the user service manager without needing DBus session
    local cmd="systemctl"

    # Check if we have an active session (XDG_RUNTIME_DIR is set)
    if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
        # Normal user session - use --user
        $cmd --user "$@" 2>&1 || return 1
    else
        # Jenkins environment - use machine notation
        # Get current user
        local current_user=$(whoami)
        $cmd --machine="${current_user}@.host" --user "$@" 2>&1 || return 1
    fi
}

# Check if systemd user service is available (check file existence since is-enabled may fail in Jenkins)
SERVICE_FILE="$HOME/.config/systemd/user/${SERVICE_NAME}.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "✗ ERROR: Systemd user service is not set up"
    echo ""
    echo "Please run the setup script first:"
    echo "  ./scripts/setup_systemd_service.sh $BUILD_WORKSPACE"
    echo ""
    exit 1
fi

start_server() {
    echo "Starting EC2 Provisioner API server..."

    # Check if already running by looking for the process
    if pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        PID=$(pgrep -f "python3 -m uvicorn app.main:app" | head -1)
        echo "✓ Server is already running (PID $PID)"
        return 0
    fi

    # Start the service using systemctl (if available) or fallback to direct start
    if run_systemctl start "$SERVICE_NAME" 2>/dev/null; then
        echo "✓ Started via systemd"
    else
        # Fallback: systemctl failed, start directly
        echo "⚠ systemctl unavailable, starting directly..."
        cd "$BUILD_WORKSPACE"
        nohup python3 -m uvicorn app.main:app --host "$APP_HOST" --port "$APP_PORT" < /dev/null > /tmp/uvicorn.log 2>&1 &
        PROC_PID=$!
        disown $PROC_PID
        echo "✓ Started directly with PID $PROC_PID"
    fi

    # Wait for startup
    sleep 3

    # Verify it started
    if pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        PID=$(pgrep -f "python3 -m uvicorn app.main:app" | head -1)
        echo "✓ Server started successfully (PID $PID)"
        return 0
    else
        echo "✗ Server failed to start"
        echo ""
        echo "Recent logs:"
        tail -20 /tmp/uvicorn.log 2>/dev/null || true
        return 1
    fi
}

stop_server() {
    echo "Stopping EC2 Provisioner API server..."

    # Check if process is running
    if ! pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        echo "✓ Server is not running"
        return 0
    fi

    # Try to stop via systemctl first
    run_systemctl stop "$SERVICE_NAME" 2>/dev/null || true

    # Also directly kill the process to be sure
    pkill -f "python3 -m uvicorn app.main:app" || true
    sleep 1

    # Verify it stopped
    if pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        echo "✗ Server failed to stop, forcing kill..."
        pkill -9 -f "python3 -m uvicorn app.main:app" || true
        sleep 1

        if pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
            echo "✗ Server still running"
            return 1
        fi
    fi

    echo "✓ Server stopped successfully"
    return 0
}

status_server() {
    echo "EC2 Provisioner API Server Status"
    echo "=================================="

    if pgrep -f "python3 -m uvicorn app.main:app" > /dev/null 2>&1; then
        PID=$(pgrep -f "python3 -m uvicorn app.main:app" | head -1)
        echo "✓ Server is running (PID $PID)"

        # Check health endpoint
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
