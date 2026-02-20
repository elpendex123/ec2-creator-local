# Local Setup Guide

## Prerequisites

1. **Python 3.11+** and **pip**
2. **AWS CLI v2** — [Install](https://aws.amazon.com/cli/)
3. **AWS Account** with EC2 permissions
4. **Terraform** (optional) — [Install](https://www.terraform.io/)
5. **Jenkins** (optional for CI/CD) — [Install](https://www.jenkins.io/)

## Quick Start (5 minutes)

### 1. AWS Setup

```bash
# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and default region (e.g., us-east-1)

# Verify connection
aws sts get-caller-identity
```

### 2. Create EC2 Key Pair

```bash
# Create a key pair (save to ~/.ssh/)
aws ec2 create-key-pair \
  --key-name my_ec2_keypair \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my_ec2_keypair.pem

# Set correct permissions
chmod 400 ~/.ssh/my_ec2_keypair.pem

# Verify
ls -la ~/.ssh/my_ec2_keypair.pem
```

### 3. Install Python Dependencies

```bash
cd /home/enrique/PROJECTS/ec2-creator-local
pip install -r requirements.txt
```

### 4. Configure `.env`

```bash
cp .env.example .env
```

Edit `.env` with your AWS credentials:

```env
AWS_ACCESS_KEY_ID=your-key-id
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
BACKEND=awscli
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASSWORD=
NOTIFICATION_EMAIL=
```

### 5. Start the App

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API will be available at `http://localhost:8000`.

### 6. Test Instance Creation

```bash
curl -X POST http://localhost:8000/instances \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-instance",
    "ami": "ami-0c02fb55956c7d316",
    "instance_type": "t3.micro",
    "storage_gb": 8,
    "create_security_group": true
  }'
```

### 7. SSH to Instance

```bash
# Get public IP from API response or:
curl http://localhost:8000/instances | jq '.[] | {id, public_ip}'

# Connect
ssh -i ~/.ssh/my_ec2_keypair.pem ec2-user@<public-ip>
```

---

## Troubleshooting

### AWS CLI Not Found

```bash
which aws
# If not found, install from https://aws.amazon.com/cli/
```

### Cannot Create Key Pair

```bash
# Check existing key pairs
aws ec2 describe-key-pairs

# If already exists, use AWS Console to download the private key
# Place in ~/.ssh/my_ec2_keypair.pem and chmod 400
```

### Instance Creation Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check AMI availability in your region
aws ec2 describe-images --image-ids ami-0c02fb55956c7d316 --region us-east-1

# Check free-tier eligibility
# Only t3.micro and t4g.micro are allowed
```

### Cannot SSH to Instance

```bash
# Wait 30-60 seconds for instance to fully boot
# Verify security group allows SSH:
aws ec2 describe-security-groups --query 'SecurityGroups[?GroupName==`ec2-provisioner-sg`]'
```
