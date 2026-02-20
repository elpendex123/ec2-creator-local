# API Reference

Base URL: `http://localhost:8000`

---

## Health Check

Check if the API is running.

**Request:**
```bash
GET /health
```

**Response (200 OK):**
```json
{"status": "ok"}
```

---

## Create Instance

Provision a new EC2 instance with optional security group.

**Request:**
```bash
POST /instances
Content-Type: application/json

{
  "name": "my-dev-server",
  "ami": "ami-0c02fb55956c7d316",
  "instance_type": "t3.micro",
  "storage_gb": 8,
  "create_security_group": true
}
```

**Query Parameters:**
- `backend=awscli` (default) or `backend=terraform`

**Response (201 Created):**
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
  "created_at": "2025-02-19T12:00:00Z",
  "updated_at": "2025-02-19T12:00:00Z"
}
```

**Errors:**
- `400 Bad Request` — invalid instance type or AMI
- `500 Internal Server Error` — AWS CLI error

---

## List Instances

Retrieve all instances.

**Request:**
```bash
GET /instances
```

**Response (200 OK):**
```json
[
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
    "created_at": "2025-02-19T12:00:00Z",
    "updated_at": "2025-02-19T12:00:00Z"
  }
]
```

---

## Get Instance

Retrieve details of a single instance.

**Request:**
```bash
GET /instances/{instance_id}
```

**Response (200 OK):**
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
  "created_at": "2025-02-19T12:00:00Z",
  "updated_at": "2025-02-19T12:00:00Z"
}
```

**Errors:**
- `404 Not Found` — instance doesn't exist

---

## Start Instance

Start a stopped instance.

**Request:**
```bash
POST /instances/{instance_id}/start
```

**Query Parameters:**
- `backend=awscli` (default) or `backend=terraform`

**Response (200 OK):**
```json
{
  "id": "i-0abc123def456",
  "name": "my-dev-server",
  "state": "starting",
  "public_ip": "54.123.45.67",
  ...
}
```

**Errors:**
- `404 Not Found` — instance doesn't exist
- `400 Bad Request` — instance is already running

---

## Stop Instance

Stop a running instance.

**Request:**
```bash
POST /instances/{instance_id}/stop
```

**Query Parameters:**
- `backend=awscli` (default) or `backend=terraform`

**Response (200 OK):**
```json
{
  "id": "i-0abc123def456",
  "name": "my-dev-server",
  "state": "stopping",
  "public_ip": "54.123.45.67",
  ...
}
```

**Errors:**
- `404 Not Found` — instance doesn't exist
- `400 Bad Request` — instance is already stopped

---

## Destroy Instance

Terminate an instance permanently.

**Request:**
```bash
DELETE /instances/{instance_id}
```

**Query Parameters:**
- `backend=awscli` (default) or `backend=terraform`

**Response (204 No Content)**

The instance will be terminated. This action is irreversible.

**Errors:**
- `404 Not Found` — instance doesn't exist

---

## curl Examples

### Create Instance
```bash
curl -X POST http://localhost:8000/instances \
  -H "Content-Type: application/json" \
  -d '{
    "name": "web-server",
    "ami": "ami-0c02fb55956c7d316",
    "instance_type": "t3.micro",
    "storage_gb": 8,
    "create_security_group": true
  }'
```

### List All Instances
```bash
curl http://localhost:8000/instances | jq
```

### Get One Instance
```bash
curl http://localhost:8000/instances/i-0abc123def456 | jq
```

### Start Instance
```bash
curl -X POST http://localhost:8000/instances/i-0abc123def456/start
```

### Stop Instance
```bash
curl -X POST http://localhost:8000/instances/i-0abc123def456/stop
```

### Delete Instance
```bash
curl -X DELETE http://localhost:8000/instances/i-0abc123def456
```

### Health Check
```bash
curl http://localhost:8000/health
```

---

## Free Tier Constraints

Only the following configurations are allowed:

**Instance Types:**
- `t3.micro`
- `t4g.micro`

**Allowed AMIs (us-east-1):**
- `ami-0c02fb55956c7d316` (Amazon Linux 2)
- `ami-026992d753d5622bc` (Amazon Linux 2)
- Others as defined in the app config

Request with invalid instance type or AMI will return **400 Bad Request**.
