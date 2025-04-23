#!/bin/bash
set -e

# This script demonstrates a complete SuiFit challenge lifecycle
# Replace these values with your actual values from deployment
PACKAGE_ID=$1
CHALLENGE_ID=$2
CLOCK=$3

if [ -z "$PACKAGE_ID" ] || [ -z "$CHALLENGE_ID" ] || [ -z "$CLOCK" ]; then
  echo "Usage: ./test_challenge.sh <PACKAGE_ID> <CHALLENGE_ID> <CLOCK_ID>"
  exit 1
fi

# Get current account address
ACCOUNT=$(sui client active-address)
echo "Active account: $ACCOUNT"

# Get a SUI coin for staking
COINS=$(sui client gas --json)
COIN_ID=$(echo "$COINS" | jq -r '.data[0].id.id' 2>/dev/null || echo "$COINS" | grep -oP 'ID: \K[0-9a-zA-Z]+' | head -1)
echo "Using coin: $COIN_ID"

# 1. Join the challenge
echo "Joining the challenge with ID $CHALLENGE_ID..."
sui client call \
  --package $PACKAGE_ID \
  --module challenge \
  --function join_challenge \
  --args $CHALLENGE_ID $COIN_ID $CLOCK \
  --gas-budget 10000000

# 2. Submit fitness data 
echo "Submitting fitness data..."
sui client call \
  --package $PACKAGE_ID \
  --module challenge \
  --function submit_steps \
  --args $CHALLENGE_ID 10000 500 $CLOCK \
  --gas-budget 10000000

# 3. Check challenge details
echo "Challenge details:"
sui client object $CHALLENGE_ID

# 4. End challenge (would normally wait for duration to pass)
echo "Ending the challenge..."
sui client call \
  --package $PACKAGE_ID \
  --module challenge \
  --function end_challenge \
  --args $CHALLENGE_ID $CLOCK \
  --gas-budget 10000000

# 5. Check final state
echo "Final challenge state:"
sui client object $CHALLENGE_ID 