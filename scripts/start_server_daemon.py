#!/usr/bin/env python3
"""
Properly daemonize the uvicorn server to escape Jenkins process management.
This script:
1. Forks to create a new process completely independent of parent
2. Changes to the proper working directory
3. Activates the venv
4. Starts uvicorn
"""

import os
import sys
import subprocess
import time

def daemonize(workspace_dir):
    """Daemonize the process - fork twice to escape process groups."""

    # First fork
    try:
        pid = os.fork()
        if pid > 0:
            # Parent exits immediately - first fork detaches parent
            sys.exit(0)
    except OSError as err:
        print(f"fork #1 failed: {err}")
        sys.exit(1)

    # Decouple from parent environment
    os.chdir(workspace_dir)
    os.setsid()  # Create new session
    os.umask(0)

    # Second fork
    try:
        pid = os.fork()
        if pid > 0:
            # Second parent exits - this daemonizes the process
            sys.exit(0)
    except OSError as err:
        print(f"fork #2 failed: {err}")
        sys.exit(1)

    # Now we're truly daemonized
    # Redirect standard file descriptors
    sys.stdout.flush()
    sys.stderr.flush()

    si = open('/dev/null', 'r')
    so = open('/tmp/uvicorn.log', 'a+')
    se = open('/tmp/uvicorn.log', 'a+')

    os.dup2(si.fileno(), sys.stdin.fileno())
    os.dup2(so.fileno(), sys.stdout.fileno())
    os.dup2(se.fileno(), sys.stderr.fileno())

    # Start the uvicorn server
    venv_python = os.path.join(workspace_dir, '.venv/bin/python3')
    cmd = [
        venv_python,
        '-m', 'uvicorn',
        'app.main:app',
        '--host', '0.0.0.0',
        '--port', '8000'
    ]

    os.execvp(venv_python, cmd)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: start_server_daemon.py <workspace_dir>")
        sys.exit(1)

    workspace = sys.argv[1]
    if not os.path.isdir(workspace):
        print(f"Workspace not found: {workspace}")
        sys.exit(1)

    daemonize(workspace)
