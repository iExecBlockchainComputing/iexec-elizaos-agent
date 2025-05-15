# Start Ollama in the background

echo '{ "deterministic-output-path" : "/iexec_out/result.txt" }' > $IEXEC_OUT/computed.json
echo 'eliza agent' > $IEXEC_OUT/result.txt
touch $IEXEC_OUT/stderr.txt
touch $IEXEC_OUT/stdout.txt

# check if dataset (character) file exists
if [ ! -f "$IEXEC_IN/$IEXEC_DATASET_FILENAME" ]; then
    echo "❌ character file not found: $IEXEC_IN/$IEXEC_DATASET_FILENAME" | tee -a $IEXEC_OUT/stderr.txt
    exit 0
fi
echo "📄 Found character file: $IEXEC_IN/$IEXEC_DATASET_FILENAME" | tee -a $IEXEC_OUT/stdout.txt

# Clean JSON, This is useful because AES (especially with padding modes like PKCS7) may produce junk like ^D, ^E, or other non-printable characters at the end of decrypted output.
echo "🟢 Clean the decrypted JSON file by removing non-printable ASCII control characters" | tee -a "$IEXEC_OUT/stdout.txt"
tr -d '\000-\010\013\014\016-\037\177' < $IEXEC_IN/$IEXEC_DATASET_FILENAME > /app/characters/character.json

# check the json
if jq . /app/characters/character.json > /dev/null; then
    echo "🟢 JSON parsed successfully." | tee -a "$IEXEC_OUT/stdout.txt"
else
    echo "❌ Failed to parse JSON from $IEXEC_IN/$IEXEC_DATASET_FILENAME" | tee -a "$IEXEC_OUT/stderr.txt"
    exit 0
fi

# Check args
if [ "$(echo "$1" | wc -w)" -ne 2 ]; then
    echo "❌ The argument must contain exactly two words: MODEL_NAME and EXPECTED_ID." | tee -a $IEXEC_OUT/stderr.txt
    echo "📌 Usage: $0 \"<MODEL_NAME EXPECTED_ID>\"" | tee -a $IEXEC_OUT/stderr.txt
    exit 0
fi

# Split arguments
read MODEL_NAME EXPECTED_ID <<< "$1"

echo "📦 Argument 1 - MODEL_NAME: $MODEL_NAME" | tee -a $IEXEC_OUT/stdout.txt
echo "📦 Argument 2 - EXPECTED_ID: $EXPECTED_ID" | tee -a $IEXEC_OUT/stdout.txt

/bin/ollama serve &

# Pause for Ollama to start
sleep 5
echo "🟢 Retrieving model ($MODEL_NAME)..." | tee -a $IEXEC_OUT/stdout.txt

# Download Ollama model
if ! ollama pull "$MODEL_NAME"; then
    echo "❌ Failed to download model: $MODEL_NAME" | tee -a $IEXEC_OUT/stderr.txt
    exit 0
fi

echo "🟢 Model download complete!" | tee -a $IEXEC_OUT/stdout.txt
# Fetch ID from download
ACTUAL_ID=$(ollama list | grep "^$MODEL_NAME" | awk '{print $2}')

# Check ID is not empty
if [ -z "$ACTUAL_ID" ]; then
    echo "❌ Failed to retrieve model ID for $MODEL_NAME" | tee -a $IEXEC_OUT/stderr.txt
    exit 0
fi

# Check ID
if [ "$ACTUAL_ID" != "$EXPECTED_ID" ]; then
    echo "❌ Model ID does not match!" | tee -a $IEXEC_OUT/stderr.txt
    exit 0
fi
echo "🟢 Model ID match confirmed!" | tee -a $IEXEC_OUT/stdout.txt

echo "🟢 Injecting secrets and model config" | tee -a $IEXEC_OUT/stdout.txt
sed -i "s/TWITTER_USERNAME_TO_REPLACE/$IEXEC_REQUESTER_SECRET_1/" .env
sed -i "s/TWITTER_PASSWORD_TO_REPLACE/$IEXEC_REQUESTER_SECRET_2/" .env
sed -i "s/TWITTER_EMAIL_TO_REPLACE/$IEXEC_REQUESTER_SECRET_3/" .env
sed -i "s/OLLAMA_MODEL_NAME_TO_REPLACE/$MODEL_NAME/" .env

echo "🟢 Start Eliza Agent" | tee -a $IEXEC_OUT/stdout.txt
pnpm start --character="characters/character.json" > >(tee -a "$IEXEC_OUT/stdout.txt") 2> >(tee -a "$IEXEC_OUT/stderr.txt" >&2) &
ELIZA_PID=$!

# ⏳ Wait for 5 minute
echo "⏳ The agent will run for 5 minute to post tweets using the character file..." | tee -a $IEXEC_OUT/stdout.txt
sleep 300

# ⏱️ Task: Enforce timeout – stop Eliza and clean up after 5 minutes
echo "🟢 5 minute elapsed. Stopping Eliza agent." | tee -a $IEXEC_OUT/stdout.txt

# Kill Eliza process specifically
kill $ELIZA_PID 2>/dev/null

# Kill all Node and Ollama processes
pkill -f node
pkill -f ollama

# Clean up all child processes
kill -- -$$

# Final cleanup with SIGKILL if needed
kill -9 $(pgrep node) 2>/dev/null
kill -9 $(pgrep ollama) 2>/dev/null

# Ensure the script exits
echo "🟢 Cleanup complete, exiting container" | tee -a $IEXEC_OUT/stdout.txt
exit 0
