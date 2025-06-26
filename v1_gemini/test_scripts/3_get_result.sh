#!/bin/bash
# 3_get_result.sh
#
# This script attempts to retrieve the final result of the job.
# It reads the job_id and polls the result endpoint.

JOB_ID_FILE="last_job.id"

if [ ! -f "$JOB_ID_FILE" ]; then
    echo "Error: Job ID file (${JOB_ID_FILE}) not found."
    echo "Please run '1_start_job.sh' first."
    exit 1
fi

JOB_ID=$(cat $JOB_ID_FILE)

echo "--- Fetching result for Job ID: $JOB_ID ---"
echo "This may take a minute or two depending on your local LLM's speed."
echo "Waiting 60 seconds before polling for the result..."
sleep 60

echo "Polling for result..."
RESULT_RESPONSE=$(curl -s http://127.0.0.1:8000/research/result/$JOB_ID)

# Check if the response contains "COMPLETED"
if [[ $(echo "$RESULT_RESPONSE" | jq -r '.status') == "COMPLETED" ]]; then
    echo "--- Job Complete! ---"
    # Pretty-print the JSON response using jq
    echo $RESULT_RESPONSE | jq
else
    echo "--- Job Not Yet Complete ---"
    echo "Server is still processing or an error occurred."
    echo "Server Response:"
    echo $RESULT_RESPONSE | jq
fi
