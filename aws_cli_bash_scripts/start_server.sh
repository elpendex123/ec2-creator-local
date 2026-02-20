#!/bin/bash
# Start uvicorn server with proper process detachment
# Usage: ./start_server.sh <workspace_dir> <venv_dir> <host> <port> <log_file>

set -euo pipefail

WORKSPACE="$1"
VENV="$2"
HOST="$3"
PORT="$4"
LOG_FILE="$5"

# Change to workspace
cd "$WORKSPACE"

# Activate venv
source "$VENV/bin/activate"

# Start uvicorn completely detached using setsid
# setsid creates a new session, completely detaching from parent shell
setsid -f python3 -m uvicorn app.main:app \
    --host "$HOST" \
    --port "$PORT" \
    >> "$LOG_FILE" 2>&1
