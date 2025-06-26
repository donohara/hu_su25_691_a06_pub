#!/bin/bash
# ResearchMate Agent - Workflow Shell Scripts
# Execute in order: 1_ → 2_ → 3_ → 4_ → 5_ → 6_

# =============================================================================
# 1_setup_environment.sh
# =============================================================================
cat > 1_setup_environment.sh << 'EOF'
#!/bin/bash
echo "🔧 Setting up ResearchMate environment..."

# Create project directory structure
mkdir -p researchmate/{models,data,logs}
cd researchmate

# Check Python version
python_version=$(python3 --version 2>&1 | grep -o "3\.[0-9]\+")
if [[ $? -ne 0 ]] || [[ $(echo "$python_version" | cut -d. -f2) -lt 8 ]]; then
    echo "❌ Python 3.8+ required"
    exit 1
fi
echo "✅ Python $python_version detected"

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install fastapi==0.104.1 uvicorn==0.24.0 pydantic==2.5.0
pip install requests==2.31.0 chromadb==0.4.18 sentence-transformers==2.2.2
pip install arxiv==1.4.8 python-multipart==0.0.6

echo "✅ Environment setup complete"
echo "📁 Project structure created in: $(pwd)"
echo "🐍 Virtual environment activated"
EOF

# =============================================================================
# 2_download_model.sh
# =============================================================================
cat > 2_download_model.sh << 'EOF'
#!/bin/bash
echo "📥 Downloading recommended LLM model..."

cd researchmate/models

# Check available space (need ~5GB)
available_space=$(df . | tail -1 | awk '{print $4}')
if [[ $available_space -lt 5000000 ]]; then
    echo "❌ Need ~5GB free space for model"
    exit 1
fi

# Download Llama 3.1 8B Instruct (Q4_K_M quantization)
MODEL_URL="https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
MODEL_FILE="llama-3.1-8b-instruct-q4_k_m.gguf"

if [[ ! -f "$MODEL_FILE" ]]; then
    echo "🔽 Downloading $MODEL_FILE (~4.9GB)..."
    curl -L -o "$MODEL_FILE" "$MODEL_URL"

    if [[ $? -eq 0 ]]; then
        echo "✅ Model downloaded: $MODEL_FILE"
        ls -lh "$MODEL_FILE"
    else
        echo "❌ Download failed"
        echo "💡 Alternative: Download manually from HuggingFace"
        echo "   URL: $MODEL_URL"
        exit 1
    fi
else
    echo "✅ Model already exists: $MODEL_FILE"
fi

echo "🎯 Model ready for llama.cpp server"
echo "📍 Location: $(pwd)/$MODEL_FILE"
EOF

# =============================================================================
# 3_setup_llama_cpp.sh
# =============================================================================
cat > 3_setup_llama_cpp.sh << 'EOF'
#!/bin/bash
echo "🛠️ Setting up llama.cpp server..."

# Check if llama.cpp already exists
if [[ -d "llama.cpp" ]]; then
    echo "📁 llama.cpp directory exists"
    cd llama.cpp

    if [[ -f "server" ]]; then
        echo "✅ llama.cpp server already built"
        exit 0
    fi
else
    # Clone llama.cpp
    echo "📂 Cloning llama.cpp repository..."
    git clone https://github.com/ggerganov/llama.cpp.git
    cd llama.cpp
fi

# Build with optimizations
echo "🔨 Building llama.cpp server..."

# Detect system and build accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use Metal acceleration if available
    if system_profiler SPDisplaysDataType | grep -q "Metal"; then
        echo "🚀 Building with Metal acceleration (macOS)"
        make LLAMA_METAL=1 server
    else
        echo "🔧 Building with CPU only (macOS)"
        make server
    fi
elif command -v nvidia-smi &> /dev/null; then
    # Linux with NVIDIA GPU
    echo "🚀 Building with CUDA acceleration"
    make LLAMA_CUBLAS=1 server
else
    # CPU only
    echo "🔧 Building with CPU only"
    make server
fi

if [[ $? -eq 0 ]]; then
    echo "✅ llama.cpp server built successfully"
    echo "📍 Binary location: $(pwd)/server"
else
    echo "❌ Build failed"
    echo "💡 Try: make clean && make server"
    exit 1
fi
EOF

# =============================================================================
# 4_start_llm_server.sh
# =============================================================================
cat > 4_start_llm_server.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting llama.cpp server..."

# Find model file
MODEL_PATH=""
if [[ -f "researchmate/models/llama-3.1-8b-instruct-q4_k_m.gguf" ]]; then
    MODEL_PATH="researchmate/models/llama-3.1-8b-instruct-q4_k_m.gguf"
elif [[ -f "models/llama-3.1-8b-instruct-q4_k_m.gguf" ]]; then
    MODEL_PATH="models/llama-3.1-8b-instruct-q4_k_m.gguf"
else
    echo "❌ Model file not found"
    echo "💡 Run 2_download_model.sh first"
    exit 1
fi

# Find llama.cpp server
SERVER_PATH=""
if [[ -f "llama.cpp/server" ]]; then
    SERVER_PATH="llama.cpp/server"
elif [[ -f "../llama.cpp/server" ]]; then
    SERVER_PATH="../llama.cpp/server"
else
    echo "❌ llama.cpp server not found"
    echo "💡 Run 3_setup_llama_cpp.sh first"
    exit 1
fi

echo "🤖 Model: $MODEL_PATH"
echo "⚡ Server: $SERVER_PATH"

# Check if port 8080 is available
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8080 is busy. Stopping existing process..."
    pkill -f "server.*8080" 2>/dev/null || true
    sleep 2
fi

# Start server with optimized settings
echo "🎯 Starting LLM server on localhost:8080..."
"$SERVER_PATH" \
    --model "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port 8080 \
    --ctx-size 4096 \
    --threads $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) \
    --batch-size 512 \
    --ubatch-size 256 \
    --log-disable \
    --metrics &

SERVER_PID=$!
echo "📝 Server PID: $SERVER_PID"
echo "$SERVER_PID" > llm_server.pid

# Wait for server to start
echo "⏳ Waiting for server to initialize..."
for i in {1..30}; do
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        echo "✅ LLM server ready!"
        echo "🌐 Health check: http://localhost:8080/health"
        echo "🔧 To stop: kill $SERVER_PID"
        exit 0
    fi
    sleep 2
    echo -n "."
done

echo "❌ Server failed to start within 60 seconds"
echo "🔍 Check logs and try manual start"
exit 1
EOF

# =============================================================================
# 5_start_research_agent.sh
# =============================================================================
cat > 5_start_research_agent.sh << 'EOF'
#!/bin/bash
echo "🔬 Starting ResearchMate Agent..."

# Activate virtual environment
if [[ -f "researchmate/venv/bin/activate" ]]; then
    source researchmate/venv/bin/activate
    cd researchmate
elif [[ -f "venv/bin/activate" ]]; then
    source venv/bin/activate
else
    echo "❌ Virtual environment not found"
    echo "💡 Run 1_setup_environment.sh first"
    exit 1
fi

# Check if LLM server is running
if ! curl -s http://localhost:8080/health >/dev/null 2>&1; then
    echo "❌ LLM server not responding on localhost:8080"
    echo "💡 Run 4_start_llm_server.sh first"
    exit 1
fi

# Check if ResearchMate code exists
if [[ ! -f "main.py" ]]; then
    echo "❌ main.py not found"
    echo "💡 Copy the ResearchMate code to main.py"
    exit 1
fi

# Create logs directory
mkdir -p logs

# Check if port 8000 is available
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8000 is busy. Stopping existing process..."
    pkill -f "uvicorn.*8000" 2>/dev/null || true
    pkill -f "main.py" 2>/dev/null || true
    sleep 2
fi

# Start ResearchMate agent
echo "🚀 Starting ResearchMate on localhost:8000..."
python main.py > logs/agent.log 2>&1 &

AGENT_PID=$!
echo "📝 Agent PID: $AGENT_PID"
echo "$AGENT_PID" > agent.pid

# Wait for agent to start
echo "⏳ Waiting for agent to initialize..."
for i in {1..20}; do
    if curl -s http://localhost:8000/ >/dev/null 2>&1; then
        echo "✅ ResearchMate Agent ready!"
        echo "🌐 API: http://localhost:8000"
        echo "📚 Docs: http://localhost:8000/docs"
        echo "🔧 To stop: kill $AGENT_PID"
        exit 0
    fi
    sleep 1
    echo -n "."
done

echo "❌ Agent failed to start within 20 seconds"
echo "📋 Check logs: tail logs/agent.log"
exit 1
EOF

# =============================================================================
# 6_test_workflow.sh
# =============================================================================
cat > 6_test_workflow.sh << 'EOF'
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
EOF

# =============================================================================
# 7_stop_all.sh
# =============================================================================
cat > 7_stop_all.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping all ResearchMate services..."

# Stop ResearchMate agent
if [[ -f "agent.pid" ]]; then
    AGENT_PID=$(cat agent.pid)
    if kill -0 "$AGENT_PID" 2>/dev/null; then
        echo "🔬 Stopping ResearchMate agent (PID: $AGENT_PID)..."
        kill "$AGENT_PID"
        rm agent.pid
    fi
fi

# Stop LLM server
if [[ -f "llm_server.pid" ]]; then
    SERVER_PID=$(cat llm_server.pid)
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "🤖 Stopping LLM server (PID: $SERVER_PID)..."
        kill "$SERVER_PID"
        rm llm_server.pid
    fi
fi

# Kill any remaining processes
pkill -f "uvicorn.*8000" 2>/dev/null || true
pkill -f "server.*8080" 2>/dev/null || true
pkill -f "main.py" 2>/dev/null || true

# Check if ports are free
sleep 2
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8000 still busy"
else
    echo "✅ Port 8000 freed"
fi

if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8080 still busy"
else
    echo "✅ Port 8080 freed"
fi

echo "🏁 All services stopped"
EOF

# =============================================================================
# 8_cleanup.sh
# =============================================================================
cat > 8_cleanup.sh << 'EOF'
#!/bin/bash
echo "🧹 Cleaning up ResearchMate environment..."

# Stop all services first
bash 7_stop_all.sh

echo "🗑️ Removing temporary files..."

# Remove databases and caches
rm -f researchmate.db
rm -rf chroma_db/
rm -rf __pycache__/
rm -f test_results.json
rm -f *.log

# Remove logs
rm -rf logs/

# Clean Python cache
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

echo "✅ Cleanup complete"
echo "💡 To fully reset:"
echo "   - Remove models/ directory (saves ~5GB)"
echo "   - Remove llama.cpp/ directory"
echo "   - Remove venv/ directory"
EOF

# =============================================================================
# Make all scripts executable
# =============================================================================

chmod +x *.sh

echo "📋 ResearchMate workflow scripts created:"
echo "   1_setup_environment.sh    - Install deps & create venv"
echo "   2_download_model.sh       - Download Llama 3.1 8B model"
echo "   3_setup_llama_cpp.sh      - Build llama.cpp server"
echo "   4_start_llm_server.sh     - Start LLM server (port 8080)"
echo "   5_start_research_agent.sh - Start ResearchMate (port 8000)"
echo "   6_test_workflow.sh        - Run end-to-end test"
echo "   7_stop_all.sh            - Stop all services"
echo "   8_cleanup.sh             - Clean temporary files"
echo ""
echo "🚀 Quick start: ./1_setup_environment.sh && ./2_download_model.sh && ./3_setup_llama_cpp.sh"
EOF