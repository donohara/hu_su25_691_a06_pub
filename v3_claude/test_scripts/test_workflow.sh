#!/bin/bash
echo "🧪 Testing ResearchMate workflow..."

# Check if agent is running
if ! curl -s http://localhost:8000/ >/dev/null 2>&1; then
    echo "❌ ResearchMate agent not responding"
    echo "💡 Run 5_start_research_agent.sh first"
    exit 1
fi

# Test 1: Health check
echo "1️⃣ Testing health endpoint..."
HEALTH=$(curl -s http://localhost:8000/)
if echo "$HEALTH" | grep -q "ResearchMate"; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Test 2: Start research query
echo "2️⃣ Starting test research query..."
QUERY='{"query": "transformer attention mechanisms", "max_papers": 3}'
RESPONSE=$(curl -s -X POST http://localhost:8000/research/query \
    -H "Content-Type: application/json" \
    -d "$QUERY")

JOB_ID=$(echo "$RESPONSE" | grep -o '"job_id":"[^"]*"' | cut -d'"' -f4)

if [[ -z "$JOB_ID" ]]; then
    echo "❌ Failed to start research query"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✅ Research started. Job ID: $JOB_ID"

# Test 3: Monitor job status
echo "3️⃣ Monitoring job progress..."
for i in {1..60}; do
    STATUS_RESPONSE=$(curl -s http://localhost:8000/research/status/$JOB_ID)
    STATUS=$(echo "$STATUS_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    echo "⏳ Status: $STATUS (${i}s elapsed)"
    
    if [[ "$STATUS" == "completed" ]]; then
        echo "✅ Research completed!"
        break
    elif [[ "$STATUS" == "failed" ]]; then
        echo "❌ Research failed"
        echo "Response: $STATUS_RESPONSE"
        exit 1
    fi
    
    sleep 2
done

if [[ "$STATUS" != "completed" ]]; then
    echo "⏰ Research timed out after 2 minutes"
    exit 1
fi

# Test 4: Get results
echo "4️⃣ Retrieving results..."
RESULTS=$(curl -s http://localhost:8000/research/results/$JOB_ID)

if echo "$RESULTS" | grep -q "papers_found"; then
    PAPERS_COUNT=$(echo "$RESULTS" | grep -o '"papers_found":[0-9]*' | cut -d':' -f2)
    echo "✅ Results retrieved: $PAPERS_COUNT papers found"
    
    # Save results to file
    echo "$RESULTS" | python3 -m json.tool > test_results.json
    echo "📄 Results saved to: test_results.json"
else
    echo "❌ Failed to retrieve results"
    echo "Response: $RESULTS"
    exit 1
fi

# Test 5: Stats check
echo "5️⃣ Checking system stats..."
STATS=$(curl -s http://localhost:8000/stats)
if echo "$STATS" | grep -q "jobs"; then
    echo "✅ Stats retrieved successfully"
    echo "$STATS" | python3 -m json.tool
else
    echo "❌ Failed to get stats"
fi

echo ""
echo "🎉 All tests passed! ResearchMate is working correctly."
echo "🔗 Try the interactive docs: http://localhost:8000/docs"
echo "📝 Example query: curl -X POST http://localhost:8000/research/query -H 'Content-Type: application/json' -d '{\"query\":\"machine learning transformers\"}'"
