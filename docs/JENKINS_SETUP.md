# Jenkins Setup (Optional)

Jenkins is optional for local development. You can run the app directly with `uvicorn` if you prefer.

---

## Installation

### Option 1: Docker (Recommended)

```bash
docker run -d -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  --name jenkins \
  jenkins/jenkins:lts
```

Get initial admin password:
```bash
docker logs jenkins | grep "Admin password"
```

Access Jenkins at `http://localhost:8080`.

### Option 2: Native Installation

- Linux: `sudo apt-get install jenkins`
- macOS: `brew install jenkins`
- Windows: Download from [jenkins.io](https://www.jenkins.io/)

---

## Configure Jenkins

### 1. Install Required Plugins

Go to **Manage Jenkins** → **Manage Plugins** → **Available**:

- Git
- Pipeline
- Python Plugin
- AWS CLI Plugin (optional)

### 2. Create Pipeline Job

**Job Name:** `ec2-creator-build`

**Pipeline Definition:**
- **Definition:** Pipeline script from SCM
- **SCM:** Git
- **Repository URL:** `https://github.com/yourusername/ec2-creator-local`
- **Branch:** `*/main`
- **Script Path:** `jenkins/deployment/Jenkinsfile.build`

### 3. Create Deployment Job

**Job Name:** `ec2-creator-deploy`

**Pipeline Definition:**
- **Definition:** Pipeline script from SCM
- **SCM:** Git
- **Repository URL:** `https://github.com/yourusername/ec2-creator-local`
- **Branch:** `*/main`
- **Script Path:** `jenkins/deployment/Jenkinsfile.deploy`

### 4. Create EC2 Operation Jobs

Repeat for each operation:

**Job Name:** `ec2-create-instance`
- **Script Path:** `jenkins/aws_cli_jobs/Jenkinsfile.cli_create`
- **Parameters:**
  - String: `name`
  - String: `ami`
  - String: `instance_type`
  - String: `storage_gb`
  - Boolean: `create_security_group`

**Job Name:** `ec2-list-instances`
- **Script Path:** `jenkins/aws_cli_jobs/Jenkinsfile.cli_list`

**Job Name:** `ec2-start-instance`
- **Script Path:** `jenkins/aws_cli_jobs/Jenkinsfile.cli_start`
- **Parameters:** String: `instance_id`

**Job Name:** `ec2-stop-instance`
- **Script Path:** `jenkins/aws_cli_jobs/Jenkinsfile.cli_stop`
- **Parameters:** String: `instance_id`

**Job Name:** `ec2-destroy-instance`
- **Script Path:** `jenkins/aws_cli_jobs/Jenkinsfile.cli_destroy`
- **Parameters:** String: `instance_id`

---

## Configure Jenkins Credentials

### Add AWS Credentials

**Credentials** → **System** → **Global credentials** → **Add Credentials**

- **Kind:** AWS Credentials
- **Access Key ID:** Your AWS Access Key
- **Secret Access Key:** Your AWS Secret Key
- **ID:** `aws-credentials`

### Add SSH Key

For deploying to remote Jenkins agents:

- **Kind:** SSH Username with private key
- **Username:** `jenkins`
- **Private Key:** `~/.ssh/id_rsa`
- **ID:** `jenkins-ssh-key`

---

## Environment Variables

Add to Jenkins system configuration (**Manage Jenkins** → **Configure System**):

```
AWS_ACCESS_KEY_ID=your-key-id
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
BACKEND=awscli
```

Or set in job configuration → **Build Environment** → **Inject environment variables**.

---

## Run a Pipeline

### Manual Trigger

1. Go to job (e.g., `ec2-creator-build`)
2. Click **Build Now** or **Build with Parameters**
3. View logs in **Console Output**

### Git Webhook (Optional)

Configure GitHub webhook to auto-trigger builds on push:

1. GitHub → Repository → **Settings** → **Webhooks** → **Add webhook**
2. **Payload URL:** `http://jenkins.example.com/github-webhook/`
3. **Content type:** `application/json`
4. **Trigger:** Push events

---

## Run Build Pipeline

```bash
curl -X POST http://localhost:8080/job/ec2-creator-build/build \
  --user admin:yourtoken
```

---

## Run Deployment Pipeline

Starts the FastAPI app on port 8000:

```bash
curl -X POST http://localhost:8080/job/ec2-creator-deploy/build \
  --user admin:yourtoken
```

---

## Run EC2 Operation Job (Example: Create Instance)

```bash
curl -X POST http://localhost:8080/job/ec2-create-instance/buildWithParameters \
  --user admin:yourtoken \
  -d "name=my-box&ami=ami-0c02fb55956c7d316&instance_type=t3.micro&storage_gb=8&create_security_group=true"
```

---

## Troubleshooting

### Pipeline Fails with "AWS credentials not found"

- Verify credentials are set in Jenkins configuration
- Check AWS CLI is installed: `aws --version`
- Verify AWS credentials file: `~/.aws/credentials`

### Pipeline Hangs

- Check Jenkins logs: `docker logs jenkins`
- Verify git repository is accessible
- Ensure SSH keys are configured for git authentication

### Python Module Not Found

Add to Jenkinsfile:
```groovy
sh 'pip install -r requirements.txt'
```

---

## Alternative: Run Directly with uvicorn

If Jenkins is too complex, just run the app:

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

No Jenkins needed for local development!
