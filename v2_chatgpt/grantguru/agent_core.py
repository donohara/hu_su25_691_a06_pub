from llm_chain import build_pipeline
from data_store import store

from logging_config import setup_logger
logger = setup_logger("main")

def process_query(query, job_id):
    logger.info(f"process_query starting: job_id", extra={"job_id": job_id})
    result = build_pipeline(query.user_input)
    logger.info(f"process_query stats:", extra={"result": result})
    store[job_id] = {"status": "complete", "result": result}