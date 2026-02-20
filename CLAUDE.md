# CLAUDE.md — EC2 Creator (Local Development)

## Project Overview

A FastAPI REST API that provisions and manages AWS EC2 instances locally using AWS CLI bash scripts and native Terraform. This is a **local development project only** — no Docker, no Kubernetes, no cloud deployment stages.

---

## Tech Stack

- **Python 3.11+** with **FastAPI** — REST API
- **AWS CLI + Bash** — direct EC2 operations (primary backend)
- **Terraform** — EC2 provisioning and lifecycle management (optional backend)
- **SQLite** — local persistence for instance records
- **Python subprocess** — invokes Terraform CLI and AWS CLI from FastAPI
- **smtplib (SMTP)** — email notifications on lifecycle events
- **Jenkins** — local CI/CD pipeline and EC2 operation jobs

---

## Project Structure

```
ec2-creator-local/
├── app/
│   ├── main.py                        # FastAPI app entry point, router registration
│   ├── config.py                      # Load .env vars, expose settings object
│   ├── routers/
│   │   └── instances.py               # All /instances endpoints
│   ├── services/
│   │   ├── aws_cli.py                 # subprocess calls to aws_cli_bash_scripts/
│   │   ├── terraform.py               # subprocess calls to terraform_bash_scripts/ (optional)
│   │   ├── db.py                      # SQLite CRUD: create, read, update, delete instance records
│   │   └── notifications.py           # SMTP email sender
│   └── models/
│       └── instance.py                # Pydantic request/response models
│
├── terraform/
│   └── ec2/
│       ├── main.tf                    # aws_instance resource
│       ├── variables.tf               # ami, instance_type, storage_gb, name, key_name
│       └── outputs.tf                 # public_ip, instance_id
│
├── aws_cli_bash_scripts/              # Pure AWS CLI — primary implementation
│   ├── create_instance.sh             # aws ec2 run-instances with security group
│   ├── list_instances.sh              # aws ec2 describe-instances
│   ├── start_instance.sh              # aws ec2 start-instances
│   ├── stop_instance.sh               # aws ec2 stop-instances
│   ├── destroy_instance.sh            # aws ec2 terminate-instances
│   ├── create_security_group.sh       # aws ec2 create-security-group (allow SSH + HTTP/HTTPS)
│   └── get_security_group.sh          # aws ec2 describe-security-groups
│
├── terraform_bash_scripts/            # Terraform CLI wrappers (optional backend)
│   ├── tf_init.sh                     # terraform init
│   ├── tf_create.sh                   # write tfvars + terraform apply
│   ├── tf_list.sh                     # terraform show, parse state for instance list
│   ├── tf_start.sh                    # start instance via AWS CLI
│   ├── tf_stop.sh                     # stop instance via AWS CLI
│   └── tf_destroy.sh                  # terraform destroy -auto-approve
│
├── jenkins/
│   ├── deployment/
│   │   ├── Jenkinsfile.build          # Lint, test, validate
│   │   └── Jenkinsfile.deploy         # Start uvicorn server
│   ├── aws_cli_jobs/
│   │   ├── Jenkinsfile.cli_create     # runs create_instance.sh
│   │   ├── Jenkinsfile.cli_list       # runs list_instances.sh
│   │   ├── Jenkinsfile.cli_start      # runs start_instance.sh
│   │   ├── Jenkinsfile.cli_stop       # runs stop_instance.sh
│   │   └── Jenkinsfile.cli_destroy    # runs destroy_instance.sh
│   └── terraform_jobs/
│       ├── Jenkinsfile.tf_create      # runs tf_create.sh (optional)
│       ├── Jenkinsfile.tf_list        # runs tf_list.sh (optional)
│       ├── Jenkinsfile.tf_start       # runs tf_start.sh (optional)
│       ├── Jenkinsfile.tf_stop        # runs tf_stop.sh (optional)
│       └── Jenkinsfile.tf_destroy     # runs tf_destroy.sh (optional)
│
├── data/                              # SQLite database directory
├── requirements.txt
├── .env.example
├── .gitignore
└── CLAUDE.md
```

---

## REST API Endpoints

| Method   | Endpoint                  | Description                        |
|----------|---------------------------|------------------------------------|
| `GET`    | `/health`                 | Health check (k8s liveness probe)  |
| `POST`   | `/instances`              | Create a new EC2 instance          |
| `GET`    | `/instances`              | List all instances                 |
| `GET`    | `/instances/{id}`         | Get details of one instance        |
| `POST`   | `/instances/{id}/start`   | Start a stopped instance           |
| `POST`   | `/instances/{id}/stop`    | Stop a running instance            |
| `DELETE` | `/instances/{id}`         | Destroy/terminate an instance      |

### Query Parameter

All endpoints accept `?backend=terraform` or `?backend=awscli` to select the implementation. If omitted, the `BACKEND` env var is used as the default (recommended: `awscli`).

### POST `/instances` Request Body

```json
{
  "name": "my-dev-server",
  "ami": "ami-0c02fb55956c7d316",
  "instance_type": "t3.micro",
  "storage_gb": 8,
  "create_security_group": true
}
```

### POST `/instances` Response

```json
{
  "id": "i-0abc123def456",
  "name": "my-dev-server",
  "public_ip": "54.123.45.67",
  "ssh_string": "ssh -i ~/.ssh/my_ec2_keypair.pem ec2-user@54.123.45.67",
  "state": "running",
  "ami": "ami-0c02fb55956c7d316",
  "instance_type": "t3.micro",
  "security_group_id": "sg-0abc123def456",
  "backend_used": "awscli",
  "created_at": "2025-01-01T12:00:00Z"
}
```

---

## Local Development Setup

### Prerequisites

1. **Python 3.11+** and **pip**
2. **AWS CLI v2** installed and configured with AWS credentials
3. **Terraform** installed (optional, only needed for Terraform backend)
4. **Jenkins** (optional, for automated CI/CD; can run app directly with uvicorn)
5. **AWS EC2 Key Pair** named `my_ec2_keypair` created in your AWS account

### Step 1: Clone and Install

```bash
cd /home/enrique/PROJECTS/ec2-creator-local
pip install -r requirements.txt
```

### Step 2: Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, default region (e.g., us-east-1)
```

### Step 3: Create EC2 Key Pair

```bash
# Create or import your key pair in AWS Console, or via CLI:
aws ec2 create-key-pair --key-name my_ec2_keypair --region us-east-1 > my_ec2_keypair.json
# Save the private key to ~/.ssh/my_ec2_keypair.pem with 400 permissions
chmod 400 ~/.ssh/my_ec2_keypair.pem
```

### Step 4: Create `.env` File

Copy `.env.example` and configure:

```bash
cp .env.example .env
# Edit .env with your settings:
# - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
# - SMTP credentials (optional, for email notifications)
# - BACKEND=awscli (primary) or terraform (optional)
```

### Step 5: Run Locally

```bash
# Direct uvicorn (fastest for development)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Or via Jenkins (see below)
```

---

## AWS Free Tier Enforcement

- **Allowed instance types:** `t3.micro`, `t4g.micro` only
- **Allowed AMIs:** Common free-tier AMIs (Amazon Linux 2, Ubuntu, etc.)
- API returns HTTP `400` if invalid type or AMI is requested

---

## Security Groups

The API supports automatic security group creation for each instance:

- **SSH (port 22):** Allowed from anywhere (restrict in production!)
- **HTTP (port 80):** Allowed from anywhere
- **HTTPS (port 443):** Allowed from anywhere

To disable auto-creation, set `create_security_group: false` in the request body.

---

## Bash Scripts

### `aws_cli_bash_scripts/`

- `create_instance.sh <name> <ami> <instance_type> <storage_gb> [sg_id]` — creates EC2 instance with optional security group; outputs instance_id and public_ip
- `create_security_group.sh <sg_name>` — creates security group; outputs sg-xxxx
- `get_security_group.sh <sg_name>` — retrieves security group ID
- `list_instances.sh` — lists all EC2 instances (running, stopped, terminated)
- `start_instance.sh <instance_id>` — starts a stopped instance
- `stop_instance.sh <instance_id>` — stops a running instance
- `destroy_instance.sh <instance_id>` — terminates an instance

### `terraform_bash_scripts/` (Optional)

- `tf_init.sh` — terraform init in terraform/ec2/
- `tf_create.sh <name> <ami> <instance_type> <storage_gb>` — apply Terraform
- `tf_list.sh` — show instances from Terraform state
- `tf_start.sh <instance_id>` — start via AWS CLI (Terraform has no native start/stop)
- `tf_stop.sh <instance_id>` — stop via AWS CLI
- `tf_destroy.sh <instance_id>` — destroy instance via Terraform

---

## Jenkins Local Deployment

Two Jenkins pipelines for local development:

### `jenkins/deployment/Jenkinsfile.build`

```
Stages: Checkout → Lint (flake8) → Test (pytest) → Validate (flake8)
```

Triggered manually or on git push.

### `jenkins/deployment/Jenkinsfile.deploy`

```
Stages: Checkout → Start (uvicorn on port 8000)
```

Triggered manually to start the API server. Can be reused to restart the app.

### EC2 Operation Jobs

#### AWS CLI Jobs (`jenkins/aws_cli_jobs/`)

- `Jenkinsfile.cli_create` — params: name, ami, instance_type, storage_gb, create_security_group
- `Jenkinsfile.cli_list` — no params
- `Jenkinsfile.cli_start` — params: instance_id
- `Jenkinsfile.cli_stop` — params: instance_id
- `Jenkinsfile.cli_destroy` — params: instance_id

#### Terraform Jobs (`jenkins/terraform_jobs/`) [Optional]

- `Jenkinsfile.tf_create` — params: name, ami, instance_type, storage_gb
- `Jenkinsfile.tf_list` — no params
- `Jenkinsfile.tf_start` — params: instance_id
- `Jenkinsfile.tf_stop` — params: instance_id
- `Jenkinsfile.tf_destroy` — params: instance_id

---

## SQLite Database

Table: `instances`

```
id                TEXT PRIMARY KEY   -- AWS instance ID (i-xxxx)
name              TEXT
public_ip         TEXT
ami               TEXT
instance_type     TEXT
state             TEXT               -- running, stopped, terminated
ssh_string        TEXT
security_group_id TEXT
backend_used      TEXT               -- awscli or terraform
created_at        TIMESTAMP
updated_at        TIMESTAMP
```

Database file: `./data/instances.db` (auto-created on first run).

---

## SSH Access

After creating an instance, connect via:

```bash
ssh -i ~/.ssh/my_ec2_keypair.pem ec2-user@<public_ip>
```

Key points:
- Private key must have 400 permissions: `chmod 400 ~/.ssh/my_ec2_keypair.pem`
- Key pair name must match `my_ec2_keypair` in AWS

---

## Email Notifications

Optional SMTP integration for lifecycle events (create, start, stop, destroy).

Set in `.env`:

```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
NOTIFICATION_EMAIL=recipient@example.com
```

Emails sent asynchronously (non-blocking).

---

## curl Examples

```bash
# Start the app
uvicorn app.main:app --reload

# Create instance (awscli backend, default)
curl -X POST http://localhost:8000/instances \
  -H "Content-Type: application/json" \
  -d '{
    "name":"dev-box",
    "ami":"ami-0c02fb55956c7d316",
    "instance_type":"t3.micro",
    "storage_gb":8,
    "create_security_group":true
  }'

# List all instances
curl http://localhost:8000/instances

# Get one instance
curl http://localhost:8000/instances/i-0abc123def456

# Start instance
curl -X POST http://localhost:8000/instances/i-0abc123def456/start

# Stop instance
curl -X POST http://localhost:8000/instances/i-0abc123def456/stop

# Destroy instance
curl -X DELETE http://localhost:8000/instances/i-0abc123def456

# Health check
curl http://localhost:8000/health
```

---

## Environment Variables (`.env`)

```bash
# AWS credentials (required)
AWS_ACCESS_KEY_ID=your-key-id
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1

# SMTP email notifications (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
NOTIFICATION_EMAIL=

# App config
BACKEND=awscli                 # default backend: awscli (recommended) or terraform
DATABASE_URL=./data/instances.db
```

---

## Dependencies (`requirements.txt`)

```
fastapi
uvicorn[standard]
pydantic
python-dotenv
pytest
httpx
flake8
```

---

## Testing Locally

### Run Tests

```bash
pytest test_api.py -v
```

### Test Instance Creation

```bash
# Via curl (as shown above)

# Or programmatically
python -c "
import requests
resp = requests.post(
    'http://localhost:8000/instances',
    json={
        'name': 'test-instance',
        'ami': 'ami-0c02fb55956c7d316',
        'instance_type': 't3.micro',
        'storage_gb': 8,
        'create_security_group': True
    }
)
print(resp.json())
"
```

---

## Troubleshooting

### Instance Creation Fails

- Verify AWS credentials: `aws sts get-caller-identity`
- Check free-tier eligibility: instance_type must be t3.micro or t4g.micro
- Ensure key pair exists: `aws ec2 describe-key-pairs --key-names my_ec2_keypair`
- Check AMI validity for your region: `aws ec2 describe-images --image-ids ami-xxxxx`

### Cannot SSH to Instance

- Ensure private key has 400 permissions: `chmod 400 ~/.ssh/my_ec2_keypair.pem`
- Wait 30 seconds for instance to fully boot
- Verify security group allows SSH (port 22)
- Check public IP is assigned: `curl http://localhost:8000/instances/<instance-id>`

### Terraform Backend Issues

- Initialize Terraform first: `terraform -chdir=terraform/ec2 init`
- Check state file: `terraform -chdir=terraform/ec2 state list`
- Workspace isolation: each instance uses a unique workspace name

---

## Notes for Development

- Primary backend is **AWS CLI** (recommended for simplicity)
- Terraform backend is **optional** (use for state management if needed)
- All bash scripts are executable and accept positional arguments
- Free-tier validation is enforced at the API layer
- SQLite provides local persistence; no cloud database needed
- Email notifications are optional and non-blocking
- Include `/health` endpoint for monitoring
- SSH key pair `my_ec2_keypair` is hardcoded; configure in AWS before use

---

## Quick Start

```bash
# 1. Configure AWS and create key pair
aws configure
aws ec2 create-key-pair --key-name my_ec2_keypair --region us-east-1 > my_ec2_keypair.json

# 2. Set up Python environment
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your AWS credentials

# 3. Start the app
uvicorn app.main:app --reload

# 4. Create an instance
curl -X POST http://localhost:8000/instances \
  -H "Content-Type: application/json" \
  -d '{"name":"my-box","ami":"ami-0c02fb55956c7d316","instance_type":"t3.micro","storage_gb":8,"create_security_group":true}'

# 5. SSH to instance
ssh -i ~/.ssh/my_ec2_keypair.pem ec2-user@<public-ip>
```

---

## Recent Updates (February 2026)

- ✅ Removed Docker, Kubernetes, ECR, and EKS infrastructure
- ✅ Simplified to local-only development
- ✅ Primary backend: AWS CLI (bash scripts)
- ✅ Optional backend: Terraform
- ✅ Added security group creation and management
- ✅ Jenkins pipelines for local build and EC2 operations
- ✅ Focus on local testing with real AWS EC2 instances
