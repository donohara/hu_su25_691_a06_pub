
#MODEL_DIR="/Users/donohara/.lmstudio/models/RichardErkhov/distilbert_-_distilgpt2-gguf"
#MODEL_NAME="distilgpt2.Q4_0.gguf"

MODEL_DIR="/Users/donohara/.lmstudio/models/lmstudio-community/DeepSeek-R1-Distill-Qwen-7B-GGUF"
MODEL_NAME="DeepSeek-R1-Distill-Qwen-7B-Q3_K_L.gguf"

LLAMA_CPP="/opt/homebrew/Cellar/llama.cpp/5740/bin/llama-server"

#CMD="$LLAMA_CPP --model $MODEL_DIR/$MODEL_NAME --prompt \"Hello, world!\" --n-predict 100 --ctx_size 256 --threads 1"
CMD="$LLAMA_CPP --model $MODEL_DIR/$MODEL_NAME --n-predict 1024 --ctx_size 4096 --threads 32"

echo $CMD
eval $CMD%