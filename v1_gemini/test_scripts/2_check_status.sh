#!/bin/bash
# 2_check_status.sh
#
# This script checks the status of the job started by '1_start_job.sh'.
# It reads the job_id from the file and polls the status endpoint.

JOB_ID_FILE="last_job.id"

if [ ! -f "$JOB_ID_FILE" ]; then
    echo "Error: Job ID file (${JOB_ID_FILE}) not found."
    echo "Please run '1_start_job.sh' first to create a job."
    exit 1
fi

JOB_ID=$(cat $JOB_ID_FILE)

echo "--- Checking status for Job ID: $JOB_ID ---"
echo "Waiting 5 seconds for the job to start processing..."
sleep 5

STATUS_RESPONSE=$(curl -s http://127.0.0.1:8000/research/status/$JOB_ID)
JOB_STATUS=$(echo $STATUS_RESPONSE | jq -r '.status')

echo "Server Response: $STATUS_RESPONSE"
echo "Current Job Status: $JOB_STATUS"
