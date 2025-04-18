#!/bin/bash
set -x  # Debug mode: show commands as they are executed

# Create output files
echo '{ "deterministic-output-path" : "/iexec_out/result.txt" }' > $IEXEC_OUT/computed.json
echo 'eliza agent' > $IEXEC_OUT/result.txt
touch $IEXEC_OUT/stderr.txt
touch $IEXEC_OUT/stdout.txt

# Check args
if [ "$(echo "$1" | wc -w)" -ne 2 ]; then
    echo "❌ The argument must contain exactly two words: MODEL_NAME and EXPECTED_ID." >> $IEXEC_OUT/stderr.txt 
    echo "📌 Usage: $0 \"<MODEL_NAME EXPECTED_ID>\"" >> $IEXEC_OUT/stderr.txt
    exit 0
fi

# Split arguments
read MODEL_NAME EXPECTED_ID <<< "$1"

echo "📦 Argument 1 - MODEL_NAME: $MODEL_NAME" | tee -a $IEXEC_OUT/stdout.txt
echo "📦 Argument 2 - EXPECTED_ID: $EXPECTED_ID" | tee -a $IEXEC_OUT/stdout.txt

# Start Ollama
echo "🟢 Starting Ollama server..." >> $IEXEC_OUT/stdout.txt
/bin/ollama serve >> $IEXEC_OUT/stdout.txt 2>> $IEXEC_OUT/stderr.txt &
OLLAMA_PID=$!

# Wait for server to initialize
sleep 5

# Check if ollama is available
if ! command -v ollama >/dev/null 2>&1; then
    echo "❌ 'ollama' command not found in PATH" >> $IEXEC_OUT/stderr.txt
    exit 0
fi

echo "🟢 Retrieving model ($MODEL_NAME)..." >> $IEXEC_OUT/stdout.txt

# Attempt to pull the model and capture all output
OLLAMA_PULL_LOG="$IEXEC_OUT/ollama_pull.log"
if ! ollama pull "$MODEL_NAME" > "$OLLAMA_PULL_LOG" 2>&1; then
    echo "❌ Failed to download model: $MODEL_NAME" >> $IEXEC_OUT/stderr.txt
    echo "📄 ollama pull logs:" >> $IEXEC_OUT/stderr.txt
    cat "$OLLAMA_PULL_LOG" >> $IEXEC_OUT/stderr.txt
    exit 0
fi

echo "🟢 Model download complete!" >> $IEXEC_OUT/stdout.txt

# Fetch actual model ID
ACTUAL_ID=$(ollama list | grep "^$MODEL_NAME" | awk '{print $2}')

if [ -z "$ACTUAL_ID" ]; then
    echo "❌ Failed to retrieve model ID for $MODEL_NAME" >> $IEXEC_OUT/stderr.txt
    exit 0
fi

# Check model ID
if [ "$ACTUAL_ID" != "$EXPECTED_ID" ]; then
    echo "❌ Model ID does not match!" >> $IEXEC_OUT/stderr.txt
    echo "📌 Expected: $EXPECTED_ID, got: $ACTUAL_ID" >> $IEXEC_OUT/stderr.txt
    exit 0
fi

echo "✅ Model ID match confirmed!" >> $IEXEC_OUT/stdout.txt

# Inject secrets
echo "🟢 Injecting secrets and model config" >> $IEXEC_OUT/stdout.txt
sed -i "s/TWITTER_USERNAME_TO_REPLACE/$IEXEC_REQUESTER_SECRET_1/" .env
sed -i "s/TWITTER_PASSWORD_TO_REPLACE/$IEXEC_REQUESTER_SECRET_2/" .env
sed -i "s/TWITTER_EMAIL_TO_REPLACE/$IEXEC_REQUESTER_SECRET_3/" .env
sed -i "s/OLLAMA_MODEL_NAME_TO_REPLACE/$MODEL_NAME/" .env

# Start Eliza Agent
echo "🟢 Start Eliza Agent" >> $IEXEC_OUT/stdout.txt
pnpm start >> $IEXEC_OUT/stdout.txt 2>> $IEXEC_OUT/stderr.txt &
ELIZA_PID=$!

echo "⏳ The agent will run for 5 minute to post tweets using the character file..." >> $IEXEC_OUT/stdout.txt
sleep 300

echo "🛑 5 minute elapsed. Stopping Eliza agent." >> $IEXEC_OUT/stdout.txt
kill $ELIZA_PID 2>/dev/null

# Stop node and ollama processes
pkill -f node
pkill -f ollama

# Cleanup child processes
kill -- -$$
kill -9 $(pgrep node) 2>/dev/null
kill -9 $(pgrep ollama) 2>/dev/null

echo "🟢 Cleanup complete, exiting container" >> $IEXEC_OUT/stdout.txt
exit 0
