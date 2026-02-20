# Jenkins Pipelines for EC2 Creator

This guide explains the Jenkins pipelines available for building and operating EC2 instances.

---

## Pipeline Structure

```
jenkins/
├── deployment/
│   ├── Jenkinsfile              # Build, lint, test, validate pipeline
│   └── Jenkinsfile.deploy       # Start uvicorn API server
└── aws_cli_jobs/
    ├── Jenkinsfile.create       # Create EC2 instance via API
    ├── Jenkinsfile.list         # List all instances
    ├── Jenkinsfile.start        # Start a stopped instance
    ├── Jenkinsfile.stop         # Stop a running instance
    └── Jenkinsfile.destroy      # Terminate an instance
```

---

## Deployment Pipelines

### 1. Jenkinsfile (Build & Test)

**Purpose:** Lint, test, and validate code

**Stages:**
1. Checkout repository
2. Setup Python environment (venv)
3. Lint code with flake8
4. Run pytest tests
5. Validate Python syntax

**Trigger:** Manual or on git push

**Example:**
```bash
# Triggered from Jenkins UI or:
curl -X POST http://jenkins.example.com/job/ec2-creator-build/build
```

### 2. Jenkinsfile.deploy (Start API Server)

**Purpose:** Start the FastAPI uvicorn server

**Stages:**
1. Checkout repository
2. Setup Python environment
3. Start uvicorn on port 8000
4. Verify endpoints are responding

**Parameters:**
- `RELOAD` (boolean, default: false) — Enable auto-reload for development

**Example:**
```bash
# Start without auto-reload:
curl -X POST http://jenkins.example.com/job/ec2-creator-deploy/build

# Start with auto-reload:
curl -X POST http://jenkins.example.com/job/ec2-creator-deploy/buildWithParameters?RELOAD=true
```

**Output:**
- API available at `http://localhost:8000`
- Swagger docs at `http://localhost:8000/docs`
- Health check at `http://localhost:8000/health`

---

## EC2 Operation Jobs (AWS CLI Only)

All EC2 operation jobs require the API server to be running (deploy pipeline).

### 1. Jenkinsfile.create (Create Instance)

**Purpose:** Provision a new EC2 instance

**Parameters:**
- `INSTANCE_NAME` (string, default: "test-instance") — Name for the instance
- `AMI_ID` (string, default: "ami-026992d753d5622bc") — Amazon Linux 2 in us-east-1
- `INSTANCE_TYPE` (choice: t3.micro, t4g.micro) — Free-tier only
- `STORAGE_GB` (number, default: 8) — EBS volume size
- `CREATE_SECURITY_GROUP` (boolean, default: true) — Auto-create SSH/HTTP/HTTPS rules

**Stages:**
1. Validate parameters (instance type, storage)
2. Create instance via FastAPI endpoint
3. Verify instance in database and AWS

**Example:**
```bash
curl -X POST http://jenkins.example.com/job/ec2-create-instance/buildWithParameters \
  -d "INSTANCE_NAME=my-box&INSTANCE_TYPE=t3.micro&STORAGE_GB=8&CREATE_SECURITY_GROUP=true"
```

### 2. Jenkinsfile.list (List Instances)

**Purpose:** Display all EC2 instances

**Stages:**
1. Fetch instances from API database
2. List instances from AWS
3. Show counts

**Example:**
```bash
curl -X POST http://jenkins.example.com/job/ec2-list-instances/build
```

**Output:**
```
Instances in database:
- id: i-0abc123def456
- name: my-box
- state: running
- public_ip: 54.123.45.67
- instance_type: t3.micro

Instances in AWS (all states):
i-0abc123def456  running  54.123.45.67  t3.micro
```

### 3. Jenkinsfile.start (Start Instance)

**Purpose:** Start a stopped EC2 instance

**Parameters:**
- `INSTANCE_ID` (string, required) — Instance ID (e.g., i-0abc123def456)

**Stages:**
1. Validate instance ID format
2. Check current status (API + AWS)
3. Send start request via API
4. Verify instance is running

**Example:**
```bash
curl -X POST http://jenkins.example.com/job/ec2-start-instance/buildWithParameters \
  -d "INSTANCE_ID=i-0abc123def456"
```

### 4. Jenkinsfile.stop (Stop Instance)

**Purpose:** Stop a running EC2 instance

**Parameters:**
- `INSTANCE_ID` (string, required) — Instance ID (e.g., i-0abc123def456)

**Stages:**
1. Validate instance ID format
2. Check current status (API + AWS)
3. Send stop request via API
4. Verify instance is stopped

**Example:**
```bash
curl -X POST http://jenkins.example.com/job/ec2-stop-instance/buildWithParameters \
  -d "INSTANCE_ID=i-0abc123def456"
```

### 5. Jenkinsfile.destroy (Terminate Instance)

**Purpose:** Permanently terminate an EC2 instance

**Parameters:**
- `INSTANCE_ID` (string, required) — Instance ID (e.g., i-0abc123def456)
- `CONFIRM` (boolean, default: false) — Must set to true to proceed

**Stages:**
1. Validate parameters (ID format, confirmation)
2. Check instance status before deletion
3. Show confirmation warning
4. Send destroy request via API
5. Verify instance is terminated

**WARNING:** This action is **irreversible**!

**Example:**
```bash
curl -X POST http://jenkins.example.com/job/ec2-destroy-instance/buildWithParameters \
  -d "INSTANCE_ID=i-0abc123def456&CONFIRM=true"
```

---

## Jenkins Setup

### 1. Create Build Pipeline Job

1. Jenkins → New Item
2. **Job name:** `ec2-creator-build`
3. **Type:** Pipeline
4. **Pipeline → Definition:** Pipeline script from SCM
5. **SCM:** Git
6. **Repository URL:** `https://github.com/elpendex123/ec2-creator-local.git`
7. **Branch:** `*/main`
8. **Script Path:** `jenkins/deployment/Jenkinsfile`
9. Save

### 2. Create Deploy Job

1. Jenkins → New Item
2. **Job name:** `ec2-creator-deploy`
3. **Type:** Pipeline
4. **Pipeline → Definition:** Pipeline script from SCM
5. **SCM:** Git
6. **Repository URL:** `https://github.com/elpendex123/ec2-creator-local.git`
7. **Branch:** `*/main`
8. **Script Path:** `jenkins/deployment/Jenkinsfile.deploy`
9. Save

### 3. Create EC2 Operation Jobs

Repeat for each operation (create, list, start, stop, destroy):

1. Jenkins → New Item
2. **Job name:** `ec2-create-instance` (or `ec2-list-instances`, etc.)
3. **Type:** Pipeline
4. **Pipeline → Definition:** Pipeline script from SCM
5. **SCM:** Git
6. **Repository URL:** `https://github.com/elpendex123/ec2-creator-local.git`
7. **Branch:** `*/main`
8. **Script Path:** `jenkins/aws_cli_jobs/Jenkinsfile.create` (or appropriate Jenkinsfile)
9. Save

---

## Typical Workflow

### 1. Build and Test

```bash
# Run build pipeline to lint, test, validate
curl -X POST http://jenkins/job/ec2-creator-build/build
```

### 2. Deploy API

```bash
# Start the API server
curl -X POST http://jenkins/job/ec2-creator-deploy/build
```

### 3. Create Instance

```bash
# Create a new instance
curl -X POST http://jenkins/job/ec2-create-instance/buildWithParameters \
  -d "INSTANCE_NAME=my-server&INSTANCE_TYPE=t3.micro&STORAGE_GB=8"
```

### 4. Check Instance

```bash
# List all instances
curl -X POST http://jenkins/job/ec2-list-instances/build
```

### 5. SSH to Instance

```bash
# Get public IP from Jenkins job output
ssh -i ~/.ssh/my_ec2_keypair.pem ec2-user@<PUBLIC_IP>
```

### 6. Manage Instance

```bash
# Stop instance
curl -X POST http://jenkins/job/ec2-stop-instance/buildWithParameters \
  -d "INSTANCE_ID=i-xxxxx"

# Start instance
curl -X POST http://jenkins/job/ec2-start-instance/buildWithParameters \
  -d "INSTANCE_ID=i-xxxxx"

# Destroy instance
curl -X POST http://jenkins/job/ec2-destroy-instance/buildWithParameters \
  -d "INSTANCE_ID=i-xxxxx&CONFIRM=true"
```

---

## Troubleshooting

### API Server Not Running

If EC2 operation jobs fail, ensure the deploy pipeline has been run:
```bash
curl -X POST http://jenkins/job/ec2-creator-deploy/build
```

### AWS Credentials Error

Jenkins must have AWS credentials configured:
1. Jenkins → Credentials → System → Global credentials
2. Add AWS access key and secret key
3. Or set environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

### Instance ID Not Found

Ensure the instance ID is correct format: `i-` followed by hex characters.
List instances first:
```bash
curl -X POST http://jenkins/job/ec2-list-instances/build
```

### Port 8000 Already in Use

If deployment fails due to port conflict:
```bash
# Kill existing uvicorn process
pkill -f "uvicorn app.main"
```

---

## Environment Variables

Jobs automatically inherit from Jenkins environment:
- `AWS_ACCESS_KEY_ID` — AWS access key
- `AWS_SECRET_ACCESS_KEY` — AWS secret key
- `AWS_DEFAULT_REGION` — AWS region (default: us-east-1)

Configure these in Jenkins:
1. Manage Jenkins → Configure System → Global properties
2. Add environment variables
3. Save

---

## CI/CD Integration

To auto-trigger builds on git push:

1. GitHub → Settings → Webhooks → Add webhook
2. **Payload URL:** `http://jenkins.example.com/github-webhook/`
3. **Content type:** `application/json`
4. **Trigger:** Push events
5. Save

Then in Jenkins job:
- Build Triggers → GitHub hook trigger for GITScm polling
- Save

---

## Performance Notes

- Build pipeline: ~30 seconds (lint, test, validate)
- Deploy pipeline: ~10 seconds (start server)
- Create instance: ~2-3 minutes (AWS provision time)
- List instances: ~5 seconds
- Start/Stop: ~30 seconds
- Destroy: ~2 minutes

---

## Security Considerations

- Destroy job requires `CONFIRM=true` parameter to prevent accidental deletion
- All AWS CLI calls use temporary credentials from Jenkins environment
- Never commit AWS credentials to git
- Use Jenkins secrets for sensitive values
