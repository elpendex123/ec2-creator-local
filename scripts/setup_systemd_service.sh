#!/bin/bash
# Setup systemd user service for ec2-provisioner API
# Run this once to configure systemd to manage the uvicorn server
# This allows Jenkins to start/stop the server via systemctl --user

set -euo pipefail

SERVICE_NAME="ec2-provisioner"
SERVICE_FILE="$HOME/.config/systemd/user/${SERVICE_NAME}.service"
BUILD_WORKSPACE="${1:-.}"

echo "=================================================="
echo "Setting up systemd user service for $SERVICE_NAME"
echo "=================================================="
echo ""

# Create systemd user directory if it doesn't exist
mkdir -p "$HOME/.config/systemd/user"

echo "Creating systemd service file at: $SERVICE_FILE"

# Create the service file
cat > "$SERVICE_FILE" << 'SYSTEMD_SERVICE'
[Unit]
Description=EC2 Provisioner FastAPI Server
After=network.target

[Service]
Type=notify
WorkingDirectory=BUILD_WORKSPACE_PLACEHOLDER
ExecStart=BUILD_WORKSPACE_PLACEHOLDER/.venv/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ec2-provisioner

[Install]
WantedBy=default.target
SYSTEMD_SERVICE

# Replace placeholder with actual workspace
sed -i "s|BUILD_WORKSPACE_PLACEHOLDER|$BUILD_WORKSPACE|g" "$SERVICE_FILE"

echo "✓ Service file created"
echo ""

# Reload systemd user daemon to recognize the new service
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

echo "✓ Systemd reloaded"
echo ""

# Enable the service to start on login
echo "Enabling service to start on login..."
systemctl --user enable "$SERVICE_NAME"

echo "✓ Service enabled"
echo ""

echo "=================================================="
echo "Setup complete!"
echo "=================================================="
echo ""
echo "You can now manage the server with:"
echo "  systemctl --user start $SERVICE_NAME"
echo "  systemctl --user stop $SERVICE_NAME"
echo "  systemctl --user status $SERVICE_NAME"
echo "  systemctl --user restart $SERVICE_NAME"
echo ""
echo "View logs with:"
echo "  journalctl --user -u $SERVICE_NAME -f"
echo ""
