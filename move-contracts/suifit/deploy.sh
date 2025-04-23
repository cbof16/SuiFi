#!/bin/bash
set -e

# Build the contract
echo "Building the SuiFit contract..."
sui move build

# Publish the contract
echo "Publishing the SuiFit contract..."
PUBLISH_OUTPUT=$(sui client publish --gas-budget 100000000)
echo "$PUBLISH_OUTPUT" 

# Parse the package ID from publish output
PACKAGE_ID=$(echo "$PUBLISH_OUTPUT" | grep -oP 'Created Objects:.*?ID: \K[0-9a-zA-Z]+' | head -1)
echo "Package ID: $PACKAGE_ID"

# Get current account address
ACCOUNT=$(sui client active-address)
echo "Active account: $ACCOUNT"

# Get a SUI coin for staking
COINS=$(sui client gas --json)
COIN_ID=$(echo "$COINS" | jq -r '.data[0].id.id' 2>/dev/null || echo "$COINS" | grep -oP 'ID: \K[0-9a-zA-Z]+' | head -1)
echo "Using coin: $COIN_ID"

# Create a clock object if needed
CLOCK=$(sui client objects --json | grep -oP '"objectId": "\K[0-9a-zA-Z]+(?=")' | grep -i 'clock')
if [ -z "$CLOCK" ]; then
  echo "Clock not found"
else
  echo "Found clock: $CLOCK"
fi

# Create a creator capability
echo "Creating a creator capability..."
sui client call \
  --package $PACKAGE_ID \
  --module challenge_creator \
  --function create_creator_cap \
  --args "SuiFit Creator" \
  --gas-budget 10000000

# Get the creator cap ID
CREATOR_CAP=$(sui client objects --json | jq -r '.[] | select(.data.type | contains("'$PACKAGE_ID'::challenge_creator::CreatorCap")).objectId')
echo "Creator Cap ID: $CREATOR_CAP"

# Create a new challenge
echo "Creating a new challenge..."
sui client call \
  --package $PACKAGE_ID \
  --module challenge \
  --function publish_challenge \
  --args "Step Showdown" "Highest steps in 24h wins" 1 86400000 5000000 50000000 120 $CLOCK \
  --gas-budget 10000000

# Get the challenge ID
CHALLENGE_ID=$(sui client objects --json | jq -r '.[] | select(.data.type | contains("'$PACKAGE_ID'::challenge::Challenge")).objectId')
echo "Challenge ID: $CHALLENGE_ID"

echo "To join the challenge, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function join_challenge --args $CHALLENGE_ID <COIN_OBJECT_ID> $CLOCK --gas-budget 10000000"

echo "To submit fitness data, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function submit_steps --args $CHALLENGE_ID 10000 500 $CLOCK --gas-budget 10000000"

echo "To end the challenge, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function end_challenge --args $CHALLENGE_ID $CLOCK --gas-budget 10000000"

echo "To cancel the challenge (only creator), run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function cancel_challenge --args $CHALLENGE_ID --gas-budget 10000000" 