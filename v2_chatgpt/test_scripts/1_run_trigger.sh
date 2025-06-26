curl -X POST http://localhost:8000/trigger \
 -H "Content-Type: application/json" \
 -d '{"user_input": "Looking for AI grants in healthcare"}'

# Returns: {"job_id": "...", "status": "processing"}

