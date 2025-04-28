#!/bin/bash

# Script to send concurrent requests to the /transcribe endpoint 
# to test ECS service auto-scaling.

# --- Configuration ---
# Get API Endpoint from the first argument
API_ENDPOINT="$1"
# Get JWT Token from the second argument
JWT_TOKEN="$2"
# Number of concurrent requests to send
NUM_REQUESTS=15 
# Delay between batches (optional, if needed)
DELAY_SECONDS=1 

# --- Validation ---
if [[ -z "$API_ENDPOINT" || -z "$JWT_TOKEN" ]]; then
  echo "Usage: $0 <api_endpoint_url> <jwt_token>"
  echo "Example: $0 https://xxxx.execute-api.us-east-1.amazonaws.com/prod YourJWTTokenHere"
  exit 1
fi

echo "API Endpoint: $API_ENDPOINT"
echo "Number of Requests: $NUM_REQUESTS"

# --- Generate Dummy Audio Data ---
# A small, short WAV file header and minimal data, base64 encoded.
# This is NOT valid audio but enough to send as payload.
# You can replace this with a base64 string from a real short .webm if preferred.
DUMMY_AUDIO_BASE64="data:audio/webm;base64,GkXfo59ChoEBQveBAULygQRC84EIQoKEd2VibUKHgQJChYECGFOAZwEAAAAAAA......"
# (You might need a slightly longer valid base64 string if the API does validation)

# JSON Payload
JSON_PAYLOAD="{\"audio_data\": \"${DUMMY_AUDIO_BASE64}\"}"

# --- Send Requests ---
echo "Sending $NUM_REQUESTS concurrent requests to POST /transcribe..."

for (( i=1; i<=$NUM_REQUESTS; i++ ))
do
   echo "Sending request $i..."
   # Use curl to send request in the background
   curl -s -X POST "${API_ENDPOINT}/transcribe" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${JWT_TOKEN}" \
     -d "$JSON_PAYLOAD" -o /dev/null & # Output to /dev/null, run in background
   
   # Optional delay between requests if needed
   # sleep 0.1 
done

echo "All requests sent to background. Waiting for completion..."
# Wait for all background jobs started in this script to finish
wait

echo "Load test script finished." 