
from pydantic import BaseModel
from typing import Optional

class QueryRequest(BaseModel):
    user_input: str

class QueryStatus(BaseModel):
    job_id: str
    status: str
    result: Optional[str] = None
