# EC2 Creator (Local Development)

A lightweight FastAPI REST API for provisioning and managing AWS EC2 instances locally. Features AWS CLI integration, SQLite persistence, and Jenkins automation.

## Current Status

**Phase:** Local Development (Stage 1) ✅

- ✅ All REST API endpoints functional
- ✅ AWS CLI integration complete
- ✅ SQLite database working
- ✅ Jenkins pipelines operational
- ✅ Professional server process management
- ⏳ Process survival verification in progress

## Overview

**EC2 Creator** is a local development tool that:
- ✅ Provisions EC2 instances with AWS CLI bash scripts
- ✅ Enforces free-tier constraints (t3.micro, t4g.micro only)
- ✅ Manages instance lifecycle (create, start, stop, destroy)
- ✅ Stores instance records in SQLite
- ✅ Runs locally with uvicorn or via Jenkins pipelines
- ✅ Includes Swagger/OpenAPI documentation
- ✅ Professional process management for long-running server
- ✅ CI/CD automation with Jenkins

## Quick Start (5 minutes)

```bash
# 1. Configure AWS credentials
aws configure

# 2. Create EC2 key pair
aws ec2 create-key-pair --key-name my_ec2_keypair \
  --region us-east-1 --query 'KeyMaterial' --output text \
  > ~/.ssh/my_ec2_keypair.pem
chmod 400 ~/.ssh/my_ec2_keypair.pem

# 3. Install Python dependencies
python3 -m pip install -r requirements.txt

# 4. Configure environment
cp .env.example .env
# Edit .env with your AWS credentials

# 5. Start the API
python3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 6. Access Swagger UI
open http://localhost:8000/docs

# 7. Create an instance
curl -X POST http://localhost:8000/instances \
  -H "Content-Type: application/json" \
  -d '{"name":"my-box","ami":"ami-0c02fb55956c7d316","instance_type":"t3.micro","storage_gb":8,"create_security_group":true}'

# 8. SSH to instance
ssh -i ~/.ssh/my_ec2_keypair.pem ec2-user@<public-ip>
```

## Documentation

All documentation is in the `docs/` directory:

| Document | Purpose |
|----------|---------|
| **[LOCAL_SETUP.md](docs/LOCAL_SETUP.md)** | Detailed local setup instructions |
| **[API_REFERENCE.md](docs/API_REFERENCE.md)** | Complete endpoint documentation |
| **[JENKINS_SETUP.md](docs/JENKINS_SETUP.md)** | Configure Jenkins for CI/CD (optional) |
| **[CLAUDE.md](CLAUDE.md)** | Project architecture and technical details |

## Tech Stack

- **Language:** Python 3.11+
- **Framework:** FastAPI + Uvicorn
- **AWS:** EC2, VPC, Security Groups
- **Provisioning:** AWS CLI (primary) + Terraform (optional)
- **Database:** SQLite (local persistence)
- **Notifications:** SMTP (optional, for email alerts)
- **CI/CD:** Jenkins (optional; can run directly with uvicorn)
- **Scripting:** Bash for AWS CLI and Terraform operations

## Free-Tier Configuration

### Allowed Instance Types
- `t3.micro` ✓
- `t4g.micro` ✓

### Allowed AMIs by Region

**us-east-1:**
- `ami-0c02fb55956c7d316` — Amazon Linux 2 (older)
- `ami-026992d753d5622bc` — Amazon Linux 2 (current)
- `ami-026ebee89baf5eb77` — Ubuntu 20.04 LTS

**us-east-2, us-west-1, us-west-2, eu-west-1:**
- See [QUICK_START.md](docs/QUICK_START.md) for region-specific AMIs

## Core Features

### 1. Instance Management

Create, list, start, stop, and destroy EC2 instances:

```bash
# Create
curl -X POST http://localhost:8000/instances \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-server",
    "ami": "ami-026992d753d5622bc",
    "instance_type": "t3.micro",
    "storage_gb": 8
  }'

# List
curl http://localhost:8000/instances

# Start/Stop
curl -X POST http://localhost:8000/instances/i-xxxxx/start
curl -X POST http://localhost:8000/instances/i-xxxxx/stop

# Destroy
curl -X DELETE http://localhost:8000/instances/i-xxxxx
```

### 2. Dual Backend Support

Choose provisioning engine per request:

```bash
# AWS CLI (default)
curl -X POST "http://localhost:8000/instances?backend=awscli" ...

# Terraform
curl -X POST "http://localhost:8000/instances?backend=terraform" ...
```

### 3. Security Groups

Instances are created with a security group that allows:
- **SSH (port 22)** — for remote access
- **HTTP (port 80)** — for web traffic
- **HTTPS (port 443)** — for secure web traffic

Set `create_security_group: true` in the request body to auto-create.

### 4. SSH Access

Instances are created with the `my_ec2_keypair` SSH key:

```bash
ssh -i ~/.ssh/my_ec2_keypair.pem ec2-user@<public_ip>
```

See [LOCAL_SETUP.md](docs/LOCAL_SETUP.md) for detailed instructions.

### 5. Email Notifications (Optional)

Automated emails sent on:
- Instance creation ✉️
- Instance start ✉️
- Instance stop ✉️
- Instance destruction ✉️

Configure in `.env` (all fields optional):
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your.email@gmail.com
SMTP_PASSWORD=your_app_password
NOTIFICATION_EMAIL=recipient@example.com
```

### 6. API Documentation

Interactive Swagger UI at:
```
http://localhost:8000/docs
```

Alternative ReDoc:
```
http://localhost:8000/redoc
```

## Project Structure

```
ec2-creator-local/
├── app/                          # FastAPI application
│   ├── main.py                   # App entry point
│   ├── config.py                 # Settings & free-tier validation
│   ├── routers/
│   │   └── instances.py          # All endpoints
│   ├── services/
│   │   ├── aws_cli.py            # AWS CLI backend (primary)
│   │   ├── terraform.py          # Terraform backend (optional)
│   │   ├── db.py                 # SQLite ORM
│   │   └── notifications.py      # Email service
│   └── models/
│       └── instance.py           # Pydantic models
├── terraform/
│   └── ec2/                      # EC2 instance Terraform
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── aws_cli_bash_scripts/         # AWS CLI wrapper scripts
│   ├── create_instance.sh
│   ├── create_security_group.sh
│   ├── get_security_group.sh
│   ├── list_instances.sh
│   ├── start_instance.sh
│   ├── stop_instance.sh
│   └── destroy_instance.sh
├── terraform_bash_scripts/       # Terraform wrapper scripts (optional)
│   ├── tf_init.sh
│   ├── tf_create.sh
│   ├── tf_list.sh
│   ├── tf_start.sh
│   ├── tf_stop.sh
│   └── tf_destroy.sh
├── jenkins/                      # CI/CD pipelines (optional)
│   ├── deployment/
│   │   ├── Jenkinsfile.build     # Lint, test, validate
│   │   └── Jenkinsfile.deploy    # Start uvicorn
│   ├── aws_cli_jobs/             # AWS CLI EC2 operations
│   └── terraform_jobs/           # Terraform EC2 operations (optional)
├── data/                         # SQLite database directory
├── docs/                         # Documentation
│   ├── LOCAL_SETUP.md
│   ├── API_REFERENCE.md
│   └── JENKINS_SETUP.md
├── requirements.txt              # Python dependencies
├── .env.example                  # Environment template
├── .gitignore
├── CLAUDE.md                     # Technical documentation
└── README.md                     # This file
```

## Environment Variables

Create a `.env` file in the project root:

```bash
# AWS Credentials (required)
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=us-east-1

# SMTP Email Notifications (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your.email@gmail.com
SMTP_PASSWORD=your_app_password
NOTIFICATION_EMAIL=recipient@example.com

# App Configuration
BACKEND=awscli                      # Default backend (awscli or terraform)
DATABASE_URL=./data/instances.db    # SQLite database location
```

## Free-Tier Validation

The API enforces AWS free-tier constraints:

✅ **Allowed:**
- Instance types: `t3.micro`, `t4g.micro`
- Whitelisted AMIs per region
- Storage: Any size >= 1 GB

❌ **Rejected:**
- Instance type: `t2.micro`, `t2.small`, etc.
- Non-whitelisted AMIs
- Invalid regions

Error response:
```json
{
  "detail": "Instance type 't2.large' or AMI 'ami-xxxxx' not allowed. Only t3.micro and t4g.micro instance types are free tier eligible."
}
```

## Running the App

### Option 1: Direct with uvicorn (Fastest)

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Option 2: With Jenkins (CI/CD)

See [JENKINS_SETUP.md](docs/JENKINS_SETUP.md) for optional Jenkins integration.

## Development

### Local Testing

```bash
# Install dependencies
python3 -m pip install -r requirements.txt

# Run tests
pytest test_api.py -v

# Lint code
flake8 app/

# Start with auto-reload
python3 -m uvicorn app.main:app --reload
```

### Database

SQLite database stored at `./data/instances.db`:

```bash
# View contents
sqlite3 ./data/instances.db
sqlite> SELECT * FROM instances;

# Reset database
rm ./data/instances.db
```

### Check Syntax

```bash
# Lint Python code
flake8 app/

# Check Terraform (if using optional backend)
terraform -chdir=terraform/ec2 validate
```

## Documentation

Complete documentation is available in the `docs/` directory:

- **[PROJECT_STATUS.md](docs/PROJECT_STATUS.md)** — Comprehensive project status, architecture, and next steps
- **[DEPLOYMENT_STATUS.md](docs/DEPLOYMENT_STATUS.md)** — Current deployment phase and environment setup
- **[SERVER_MANAGEMENT.md](docs/SERVER_MANAGEMENT.md)** — Process manager script documentation
- **[JENKINS_PIPELINES.md](docs/JENKINS_PIPELINES.md)** — Jenkins job setup and usage
- **[QUICK_START.md](docs/QUICK_START.md)** — 5-minute quick start guide
- **[API_REFERENCE.md](docs/API_REFERENCE.md)** — Complete API endpoint documentation (if available)

## Troubleshooting

### Instance creation fails

Check:
1. AWS credentials: `aws sts get-caller-identity`
2. Free-tier eligibility: instance_type must be `t3.micro` or `t4g.micro`
3. Key pair exists: `aws ec2 describe-key-pairs --key-names my_ec2_keypair`
4. Default VPC: `aws ec2 describe-vpcs` (create if missing: `aws ec2 create-default-vpc`)

### Can't SSH to instance

Check:
1. Security group allows SSH (port 22)
2. Instance is running: `aws ec2 describe-instances --instance-ids i-xxxxx`
3. Key pair permissions: `chmod 400 ~/.ssh/my_ec2_keypair.pem`
4. Public IP is assigned (wait 30 seconds after creation)

### Email notifications not sending

Check:
1. `.env` has valid SMTP credentials
2. SMTP_HOST and SMTP_PORT are correct
3. Gmail requires app password, not main password
4. Port 587 is not blocked by firewall

### Database errors

```bash
# Reset SQLite database
rm ./data/instances.db

# API will recreate on next request
```

## Support

For help:
1. Check [LOCAL_SETUP.md](docs/LOCAL_SETUP.md) for setup issues
2. Review [API_REFERENCE.md](docs/API_REFERENCE.md) for API usage
3. See [JENKINS_SETUP.md](docs/JENKINS_SETUP.md) for CI/CD setup
4. Check application logs during execution

---

**Last Updated:** February 2026
**Project Type:** Local Development Only
**Status:** Ready for Testing ✅
