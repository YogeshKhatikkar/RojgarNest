# app/core/base_model.py
from pydantic import BaseModel as PydanticBaseModel
from datetime import datetime

class BaseModel(PydanticBaseModel):
    class Config:
        arbitrary_types_allowed = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            # Add other encoders if needed
        }