#!/bin/bash
# 1_start_job.sh
#
# This script starts a new research job for a given stock ticker.
# It sends a POST request and saves the returned job_id to a file for other scripts to use.

# The stock ticker to research
TICKER="AAPL"
JOB_ID_FILE="last_job.id"

echo "--- Starting research for ticker: $TICKER ---"

# Use curl to send a POST request with a JSON payload
# -s silences the progress meter
# -X POST specifies the request method
# -H sets the content type header
# -d specifies the data payload
RESPONSE=$(curl -s -X POST http://127.0.0.1:8000/research \
-H "Content-Type: application/json" \
-d "{\"ticker\": \"${TICKER}\"}")

# Use 'jq' to parse the JSON response and extract the job_id.
# 'jq' is a lightweight command-line JSON processor. Install with 'sudo apt-get install jq' or 'brew install jq'
JOB_ID=$(echo $RESPONSE | jq -r '.job_id')

if [ -z "$JOB_ID" ] || [ "$JOB_ID" == "null" ]; then
    echo "Error: Failed to get job_id from the server."
    echo "Server Response: $RESPONSE"
    exit 1
else
    echo "Task accepted by server."
    echo "Job ID: $JOB_ID"
    # Save the job ID to a file so the other scripts can use it
    echo $JOB_ID > $JOB_ID_FILE
    echo "Job ID saved to ${JOB_ID_FILE} for use by other scripts."
fi
