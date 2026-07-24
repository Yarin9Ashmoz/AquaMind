from pydantic import BaseModel

class DeviceTokenCreate(BaseModel):
    token: str