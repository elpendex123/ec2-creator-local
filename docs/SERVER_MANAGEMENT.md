# Server Management Guide

## Overview

The `scripts/manage_server.sh` script provides production-grade process management for the EC2 Creator API server. It handles starting, stopping, and monitoring the uvicorn server with proper process isolation, graceful shutdown, and health verification.

## Why a Dedicated Process Manager?

Jenkins pipelines are designed for task automation, not long-running service management. When a Jenkins job completes, it terminates all child processes in its process group. This script ensures the uvicorn server survives job completion by:

1. Using `nohup` to ignore SIGHUP signals
2. Redirecting stdin/stdout from Jenkins pipes
3. Maintaining a PID file for reliable tracking
4. Verifying health before reporting success
5. Handling graceful shutdown with fallback to force kill

This is the standard approach used in enterprise environments.

## Usage

### Basic Commands

```bash
# Start the server
./scripts/manage_server.sh start <workspace> <host> <port>

# Check server status
./scripts/manage_server.sh status

# Stop the server gracefully
./scripts/manage_server.sh stop

# Restart the server
./scripts/manage_server.sh restart
```

### Examples

#### Start from Build workspace
```bash
./scripts/manage_server.sh start /var/lib/jenkins/workspace/EC2-Creator-Local/Build-App 0.0.0.0 8000
```

Output:
```
Starting uvicorn server...
✓ Server started with PID 45912
✓ Server is running
```

#### Check status
```bash
./scripts/manage_server.sh status
```

Output (if running):
```
✓ Server is running with PID 45912
✓ Health check passed: {"status":"ok"}
```

Output (if not running):
```
✗ Server is not running (no PID file)
```

#### Stop server
```bash
./scripts/manage_server.sh stop
```

Output:
```
Stopping server (PID 45912)...
Sent SIGTERM to 45912
✓ Server stopped
```

## Implementation Details

### Process Lifecycle

```
1. start_server()
   ├─ Check for existing process
   ├─ cd to workspace
   ├─ Start: nohup python3 -m uvicorn ... &
   ├─ Save PID to /tmp/ec2-provisioner.pid
   ├─ Sleep 3 seconds (startup time)
   └─ Verify process alive & responding

2. status_server()
   ├─ Read PID from file
   ├─ Check process exists
   ├─ Test /health endpoint
   └─ Report status

3. stop_server()
   ├─ Read PID from file
   ├─ Send SIGTERM (graceful shutdown)
   ├─ Wait 2 seconds
   ├─ Send SIGKILL if still running
   └─ Remove PID file

4. restart_server()
   ├─ Call stop_server()
   ├─ Sleep 1 second
   └─ Call start_server()
```

### File Locations

| File | Owner | Purpose | Permissions |
|------|-------|---------|-------------|
| `/tmp/ec2-provisioner.pid` | jenkins/current user | Process ID tracking | rw------- |
| `/tmp/uvicorn.log` | jenkins/current user | Server logs | rw------- |
| `./data/instances.db` | jenkins/current user | SQLite database | rw------- |

### Signal Handling

- **SIGTERM (15)** - Graceful shutdown, uvicorn completes in-flight requests
- **SIGKILL (9)** - Forced shutdown, used if SIGTERM doesn't work within 2 seconds
- **SIGHUP (1)** - Ignored by nohup, allows background process to survive shell exit

## Configuration

### Environment Variables

The script uses these environment variables:

```bash
# Set in manage_server.sh or provide as arguments
BUILD_WORKSPACE="/var/lib/jenkins/workspace/EC2-Creator-Local/Build-App"
APP_HOST="0.0.0.0"
APP_PORT="8000"
PID_FILE="/tmp/ec2-provisioner.pid"
```

### Customization

Edit `scripts/manage_server.sh` to change:

```bash
# Line 10 - Default PID file location
PID_FILE="/tmp/ec2-provisioner.pid"

# Change to custom location if needed:
# PID_FILE="/var/run/ec2-provisioner.pid"
```

## Integration with Jenkins

### In Jenkinsfile.manage

The start stage calls the script:

```groovy
stage('Start') {
    when {
        expression { params.ACTION == 'start' }
    }
    steps {
        script {
            sh '''
                ./scripts/manage_server.sh start "${BUILD_WORKSPACE}" "${APP_HOST}" "${APP_PORT}"
            '''
        }
    }
}
```

The stop stage calls:

```groovy
stage('Stop') {
    when {
        expression { params.ACTION == 'stop' }
    }
    steps {
        script {
            sh '''
                ./scripts/manage_server.sh stop
            '''
        }
    }
}
```

## Troubleshooting

### Server won't start

Check logs:
```bash
tail -50 /tmp/uvicorn.log
```

Common issues:
- Port 8000 already in use: `lsof -i :8000`
- venv not found: Check `BUILD_WORKSPACE` path
- Import errors: Run `pip install -r requirements.txt`

### Server stops after Jenkins job

This should NOT happen with the nohup + PID file approach. If it does:

```bash
# Manually start and verify
./scripts/manage_server.sh start /var/lib/jenkins/workspace/EC2-Creator-Local/Build-App 0.0.0.0 8000

# Check if process survives
sleep 60
pgrep -f "uvicorn app.main"

# View logs
tail -50 /tmp/uvicorn.log
```

### Permission denied on PID file

If Jenkins user can't remove PID file:

```bash
# Option 1: Let the script handle it (has error suppression)
./scripts/manage_server.sh stop

# Option 2: Manual cleanup with sudo
sudo rm -f /tmp/ec2-provisioner.pid

# Option 3: Change PID file location to user-writable directory
# Edit scripts/manage_server.sh line 10
```

### Health check fails

Server is running but not responding:

```bash
# Check if port is listening
netstat -tlnp | grep 8000

# Test endpoint directly
curl http://localhost:8000/health

# Check for errors in startup
tail -20 /tmp/uvicorn.log | grep -i error
```

## Monitoring

### Real-time log streaming

```bash
tail -f /tmp/uvicorn.log
```

### Health check loop

```bash
while true; do
    ./scripts/manage_server.sh status
    sleep 10
done
```

### Process monitoring

```bash
# One-time check
ps aux | grep "uvicorn app.main" | grep -v grep

# Continuous monitoring
watch -n 2 'pgrep -a "uvicorn app.main"'
```

## Comparison: Before vs After

### Before (Direct Jenkins Shell)
```bash
# Jenkins runs:
nohup python3 -m uvicorn ... &
# Jenkins job completes
# Process terminated (still in Jenkins process group)
# ✗ Server not accessible after job
```

### After (manage_server.sh)
```bash
# Jenkins runs:
./scripts/manage_server.sh start ...
# Script uses nohup + stdin redirect + PID tracking
# Jenkins job completes
# Process continues (detached from Jenkins)
# ✓ Server accessible after job
```

## Performance Notes

- **Startup time:** ~3 seconds (includes 3s wait for app to initialize)
- **Shutdown time:** ~2 seconds (graceful SIGTERM)
- **Force kill time:** ~1 second (if SIGTERM fails)
- **Health check latency:** <100ms (local /health endpoint)

## Security Considerations

### Process Isolation
- Process runs as Jenkins user (or current user if run manually)
- PID file world-readable but created with restrictive permissions
- No hardcoded credentials (uses environment variables)

### Log Access
- Logs stored in /tmp (consider moving to persistent location for production)
- Logs contain request/response data (PII considerations)
- No sensitive data logged (API keys not shown)

### Future Improvements
1. Use systemd user service instead of PID file
2. Implement log rotation for /tmp/uvicorn.log
3. Add monitoring/alerting integration
4. Use syslog for centralized logging

## Related Documentation

- [PROJECT_STATUS.md](./PROJECT_STATUS.md) - Overall project status
- [DEPLOYMENT_STATUS.md](./DEPLOYMENT_STATUS.md) - Current deployment phase
- [JENKINS_PIPELINES.md](./JENKINS_PIPELINES.md) - Pipeline details
- [QUICK_START.md](./QUICK_START.md) - Getting started guide
