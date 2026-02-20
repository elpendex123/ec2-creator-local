#!/bin/bash
# This script is kept for backwards compatibility
# The start_server.sh functionality is now inlined in Jenkinsfile.manage
# to avoid issues with process group management in Jenkins.

echo "ERROR: start_server.sh should not be called directly"
echo "The functionality has been moved to Jenkinsfile.manage"
exit 1
