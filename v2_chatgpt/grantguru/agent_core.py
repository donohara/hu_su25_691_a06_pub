# from llama_client import call_llm
# from grant_fetcher import fetch_grants
# from data_store import store
#
#
# def process_query(query, job_id):
#     prompt = f"""You are a grant advisor. Find relevant grants for the following request:
#     Request: "{query.user_input}".
#     Return a short summary and explain why each is a good fit."""
#
#     matched = fetch_grants(["AI", "health"])  # TODO: extract real keywords via LLM
#     summary_input = f"{prompt}\nMatching Grants:\n" + "\n".join(
#         [f"- {g['title']}, {g['agency']}, due {g['deadline']}" for g in matched])
#
#     summary = call_llm(summary_input)
#     store[job_id] = {"status": "complete", "result": summary}

from llm_chain import build_pipeline
from data_store import store

from logging_config import setup_logger
logger = setup_logger("main")

def process_query(query, job_id):
    logger.info(f"process_query starting: job_id", extra={"job_id": job_id})
    result = build_pipeline(query.user_input)
    logger.info(f"process_query stats:", extra={"result": result})
    store[job_id] = {"status": "complete", "result": result}