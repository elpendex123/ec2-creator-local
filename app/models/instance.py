from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class InstanceCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, description="Instance name")
    ami: str = Field(..., min_length=1, description="AMI ID")
    instance_type: str = Field(..., min_length=1, description="Instance type")
    storage_gb: int = Field(..., ge=1, description="Storage size in GB")
    create_security_group: bool = Field(default=False, description="Auto-create security group for SSH/HTTP/HTTPS")


class InstanceResponse(BaseModel):
    id: str
    name: str
    public_ip: Optional[str] = ""
    ssh_string: Optional[str] = ""
    state: str
    ami: str
    instance_type: str
    security_group_id: Optional[str] = ""
    backend_used: str
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class InstanceListResponse(BaseModel):
    instances: List[InstanceResponse]
