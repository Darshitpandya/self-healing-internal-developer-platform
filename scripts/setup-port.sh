#!/usr/bin/env bash
# Setup script for Port.io — creates blueprint, entities, scorecards, and actions.
# Requires: PORT_CLIENT_ID and PORT_CLIENT_SECRET in .env or environment.
#
# Usage: ./scripts/setup-port.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load .env if present
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

: "${PORT_CLIENT_ID:?Set PORT_CLIENT_ID in .env}"
: "${PORT_CLIENT_SECRET:?Set PORT_CLIENT_SECRET in .env}"
PORT_BASE_URL="${PORT_BASE_URL:-https://api.getport.io}"

echo "🔧 Self-Healing Platform — Port.io Setup"
echo "──────────────────────────────────────────"

# Get access token
echo -e "\n📡 Authenticating with Port.io..."
TOKEN=$(curl -s -X POST "${PORT_BASE_URL}/v1/auth/access_token" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\": \"${PORT_CLIENT_ID}\", \"clientSecret\": \"${PORT_CLIENT_SECRET}\"}" \
  | jq -r '.accessToken')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Authentication failed. Check PORT_CLIENT_ID and PORT_CLIENT_SECRET."
  exit 1
fi
echo "✅ Authenticated"

# Helper function
port_api() {
  local method=$1 path=$2 data=${3:-}
  if [ -n "$data" ]; then
    curl -s -X "$method" "${PORT_BASE_URL}${path}" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$data"
  else
    curl -s -X "$method" "${PORT_BASE_URL}${path}" \
      -H "Authorization: Bearer $TOKEN"
  fi
}

# Step 1: Create blueprint
echo -e "\n📋 Creating service blueprint..."
BLUEPRINT=$(cat "$ROOT_DIR/port/blueprints/service.json")
port_api POST "/v1/blueprints" "$BLUEPRINT" > /dev/null
echo "✅ Blueprint created: service"

# Step 2: Create entities from sample data
echo -e "\n📦 Creating service entities..."
SERVICES=$(cat "$ROOT_DIR/sample-data/services.json")
COUNT=$(echo "$SERVICES" | jq length)

for i in $(seq 0 $((COUNT - 1))); do
  ENTITY=$(echo "$SERVICES" | jq ".[$i]")
  ID=$(echo "$ENTITY" | jq -r '.identifier')
  port_api POST "/v1/blueprints/service/entities?upsert=true" "$ENTITY" > /dev/null
  echo "  ├── $ID"
done
echo "✅ $COUNT entities created"

# Step 3: Create scorecards
echo -e "\n📊 Creating scorecards..."
for SCORECARD_FILE in "$ROOT_DIR"/port/scorecards/*.json; do
  SCORECARD=$(cat "$SCORECARD_FILE")
  NAME=$(echo "$SCORECARD" | jq -r '.identifier')
  port_api POST "/v1/blueprints/service/scorecards" "$SCORECARD" > /dev/null
  echo "  ├── $NAME"
done
echo "✅ Scorecards created"

# Step 4: Create self-service actions
echo -e "\n⚡ Creating self-service actions..."
for ACTION_FILE in "$ROOT_DIR"/port/actions/*.json; do
  ACTION=$(cat "$ACTION_FILE")
  NAME=$(echo "$ACTION" | jq -r '.identifier')
  port_api POST "/v1/blueprints/service/actions" "$ACTION" > /dev/null
  echo "  ├── $NAME"
done
echo "✅ Actions created"

echo -e "\n──────────────────────────────────────────"
echo "🔧 Setup complete!"
echo "   Open Port.io to see your services, scorecards, and actions."
echo "   Dashboard URL: https://app.getport.io"
