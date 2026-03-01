# should remove this file 
# just for test

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ENVS_DIR="$SCRIPT_DIR/../../envs" # adjust relative to script location

if [ -f "$ENVS_DIR/gps.env" ]; then
    cp "$ENVS_DIR/gps.env" "./.env"
    echo "✅ envs/gps.env to ./.env"
else
    echo "⚠ No env file found at $ENVS_DIR, skipping copy"
fi
