# Location and name of GGUF model for llama.cpp
MODEL_DIR="/Users/donohara/.lmstudio/models/lmstudio-community/DeepSeek-R1-Distill-Qwen-7B-GGUF"
MODEL_NAME="DeepSeek-R1-Distill-Qwen-7B-Q3_K_L.gguf"

# Location of llama.cpp binary
LLAMA_CPP="/opt/homebrew/Cellar/llama.cpp/5740/bin/llama-server"

# Final command to start the llama.cpp server
CMD="$LLAMA_CPP --model $MODEL_DIR/$MODEL_NAME --n-predict 1024 --ctx_size 4096 --threads 32"
echo $CMD
eval $CMD%