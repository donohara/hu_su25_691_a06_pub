from fastapi import FastAPI, HTTPException, BackgroundTasks
from uuid import uuid4
from schemas import QueryRequest, QueryStatus
from agent_core import process_query
from data_store import store, get_status
from logging_config import setup_logger

logger = setup_logger("main")

app = FastAPI()

@app.post("/trigger", response_model=QueryStatus)
async def trigger_query(query: QueryRequest, background_tasks: BackgroundTasks):
    job_id = str(uuid4())
    logger.info(f"Received new query: {query.user_input}", extra={"job_id": job_id})
    store[job_id] = {"status": "processing", "result": None}
    background_tasks.add_task(process_query, query, job_id)
    logger.info(f"Background task started", extra={"job_id": job_id})
    return QueryStatus(job_id=job_id, status="processing")


@app.get("/status/{job_id}", response_model=QueryStatus)
async def get_query_status(job_id: str):
    if job_id not in store:
        logger.warning("Job ID not found", extra={"job_id": job_id})
        raise HTTPException(status_code=404, detail="Job ID not found")
    logger.debug("Status retrieved", extra={"job_id": job_id, "status": store[job_id]["status"]})
    return QueryStatus(job_id=job_id, status=store[job_id]["status"], result=store[job_id]["result"])
