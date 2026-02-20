# Deployment Status

**Last Updated:** February 20, 2026
**Current Phase:** Local Development (Stage 1)

## Deployment Stages

```
Stage 1: Local Linux (CURRENT) ✅
  └─ Direct uvicorn execution on development machine
  └─ AWS CLI integration for EC2 operations
  └─ Jenkins pipelines for CI/CD

Stage 2: Docker (PLANNED)
  └─ Containerized FastAPI application
  └─ Docker Compose for local testing
  └─ Push to ECR (if needed)

Stage 3+: Kubernetes (PLANNED)
  └─ Deploy to minikube or EKS when ready
```

## Stage 1 Status: Local Linux ✅

### Completed
- ✅ FastAPI application (app/main.py)
- ✅ AWS CLI bash scripts (aws_cli_bash_scripts/)
- ✅ SQLite database integration
- ✅ Pytest test suite
- ✅ Jenkins Build pipeline (lint, test, validate)
- ✅ Jenkins Manage pipeline (status, start, stop)
- ✅ Professional process manager (scripts/manage_server.sh)
- ✅ Venv optimization (reuse across Jenkins jobs)
- ✅ All REST API endpoints

### In Progress
- ⏳ Verify server process survives Jenkins job completion
- ⏳ Test full AWS EC2 operations end-to-end
- ⏳ Validate all error scenarios

### Pending
- ⏱️ Docker containerization (Stage 2)
- ⏱️ Kubernetes deployment (Stage 3+)

## Environment Setup

### Python Environment
- Location: `/var/lib/jenkins/workspace/EC2-Creator-Local/Build-App/.venv`
- Created by: Build job (jenkins/deployment/Jenkinsfile)
- Shared with: Manage job
- Activation: `. .venv/bin/activate`

### AWS Credentials
- Required environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- Default region: `us-east-1`
- Key pair: `my_ec2_keypair` (must exist in AWS)

### Server Process
- Manager script: `scripts/manage_server.sh`
- PID file: `/tmp/ec2-provisioner.pid`
- Log file: `/tmp/uvicorn.log`
- Port: 8000
- Host: 0.0.0.0

## Jenkins Jobs

### 1. EC2-Creator-Local (Build Job)
- **Purpose:** Code quality, testing, venv management
- **Triggers:** Manual or git push
- **Stages:**
  1. Checkout code from GitHub
  2. Setup/reuse Python venv
  3. Lint with flake8
  4. Run pytest tests
  5. Validate syntax

**Status:** ✅ Fully operational

### 2. EC2-Creator-Manage (Server Management)
- **Purpose:** Server lifecycle management
- **Parameter:** ACTION (choice: status, start, stop)
- **Stages:**
  1. Checkout code
  2. Validate environment
  3. Execute selected action
  4. Verify success

**Status:** ✅ Fully operational (process survival pending verification)

## API Endpoints

All endpoints return appropriate HTTP status codes and JSON responses.

### Health Check
```
GET /health
Response: {"status": "ok"}
Status: 200 OK
```

### Instance Management
```
POST /instances
  Create new EC2 instance
  Body: {name, ami, instance_type, storage_gb}
  Status: 201 Created / 400 Bad Request

GET /instances
  List all instances
  Status: 200 OK

GET /instances/{id}
  Get instance details
  Status: 200 OK / 404 Not Found

POST /instances/{id}/start
  Start stopped instance
  Status: 200 OK / 404 Not Found

POST /instances/{id}/stop
  Stop running instance
  Status: 200 OK / 404 Not Found

DELETE /instances/{id}
  Terminate instance
  Status: 204 No Content / 404 Not Found
```

## Known Limitations

### Current Stage
1. **No persistent logging** - Logs are temporary (/tmp/uvicorn.log)
2. **Single-machine deployment** - All components on one server
3. **Manual AWS key management** - Key pair must be pre-created
4. **SQLite limitations** - Not suitable for multi-instance concurrency
5. **No authentication** - API is open (suitable for local dev)

### By Design
1. **AWS CLI only** - No Terraform complexity
2. **Single environment** - No staging/prod separation
3. **Lightweight** - Minimal dependencies
4. **Local database** - No external database service

## Monitoring & Troubleshooting

### Server Status Check
```bash
./scripts/manage_server.sh status
```

### View Logs
```bash
tail -50 /tmp/uvicorn.log
```

### Manual Server Start
```bash
./scripts/manage_server.sh start /var/lib/jenkins/workspace/EC2-Creator-Local/Build-App 0.0.0.0 8000
```

### Test API Connectivity
```bash
curl http://localhost:8000/health
curl -X GET http://localhost:8000/instances
```

## Data Persistence

### SQLite Database
- Location: `./data/instances.db`
- Created: On first application startup
- Schema: Single `instances` table with 10 columns
- Backup: Manual (file-based)

### Server PID File
- Location: `/tmp/ec2-provisioner.pid`
- Lifecycle: Created on start, removed on stop
- Purpose: Process tracking across restarts

## Resource Requirements

### Minimum
- Python 3.11+
- 256 MB RAM
- 100 MB disk space
- Network access to AWS

### Recommended
- Python 3.11+
- 512 MB RAM
- 1 GB disk space
- Stable network connection

## Configuration Files

### .env (if needed)
```bash
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
AWS_DEFAULT_REGION=us-east-1
DATABASE_URL=./data/instances.db
```

### Environment Variables (Jenkins)
Set in Manage-App job environment section:
- APP_HOST=0.0.0.0
- APP_PORT=8000
- VENV_DIR=.venv
- UVICORN_LOG=/tmp/uvicorn.log

## Success Criteria

- [x] API responds to health check
- [x] API endpoints are accessible
- [x] Database operations work
- [x] AWS CLI integration functional
- [x] Jenkins pipelines execute
- [x] Tests pass
- [ ] Server survives Jenkins job completion (pending)
- [ ] Full E2E workflow tested

## Next Verification Steps

1. Run Jenkins Manage > start action
2. Wait for job completion
3. Curl localhost:8000/health
4. Confirm response: `{"status":"ok"}`
5. Check process: `pgrep -f "uvicorn app.main"`
6. View logs: `tail /tmp/uvicorn.log`

## Contacts & References

- GitHub Repo: https://github.com/elpendex123/ec2-creator-local
- AWS Region: us-east-1
- Jenkins Server: localhost:8080
- API Server: localhost:8000
