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

# Get clock object
CLOCK=$(sui client objects --json | grep -oP '"objectId": "\K[0-9a-zA-Z]+(?=")' | grep -i 'clock')
if [ -z "$CLOCK" ]; then
  echo "Clock not found"
else
  echo "Found clock: $CLOCK"
fi

# Initialize matching pools
echo "Initializing matching pools..."
sui client call \
  --package $PACKAGE_ID \
  --module challenge \
  --function initialize_matching_pools \
  --gas-budget 10000000

# Create a Step Showdown challenge
echo "Creating a Step Showdown challenge..."
sui client call \
  --package $PACKAGE_ID \
  --module challenge \
  --function create_standard_challenge \
  --args 1 $CLOCK \
  --gas-budget 10000000

# Create a Speed Streak challenge
echo "Creating a Speed Streak challenge..."
sui client call \
  --package $PACKAGE_ID \
  --module challenge \
  --function create_standard_challenge \
  --args 2 $CLOCK \
  --gas-budget 10000000

# Get the challenge IDs
echo "Getting challenge IDs..."
CHALLENGES=$(sui client objects --json | jq -r '.[] | select(.data.type | contains("'$PACKAGE_ID'::challenge::Challenge")).objectId')
echo "Challenge IDs: $CHALLENGES"

# Get the matchmaking pool IDs
echo "Getting matchmaking pool IDs..."
POOLS=$(sui client objects --json | jq -r '.[] | select(.data.type | contains("'$PACKAGE_ID'::challenge::MatchingPool")).objectId')
echo "Matchmaking Pool IDs: $POOLS"

# Extract the individual pool IDs
STEP_SHOWDOWN_POOL=$(echo "$POOLS" | head -1)
SPEED_STREAK_POOL=$(echo "$POOLS" | tail -1)
echo "Step Showdown Pool ID: $STEP_SHOWDOWN_POOL"
echo "Speed Streak Pool ID: $SPEED_STREAK_POOL"

echo "Deployment completed successfully!"
echo 
echo "To join the Step Showdown matching pool, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function join_matching_pool --args $STEP_SHOWDOWN_POOL $CLOCK --gas-budget 10000000"
echo 
echo "To join the Speed Streak matching pool, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function join_matching_pool --args $SPEED_STREAK_POOL $CLOCK --gas-budget 10000000"
echo 
echo "To create a match from waiting pool, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function create_match --args <POOL_ID> $CLOCK --gas-budget 10000000"
echo 
echo "To join a challenge directly, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function join_challenge --args <CHALLENGE_ID> <COIN_OBJECT_ID> $CLOCK --gas-budget 10000000"
echo 
echo "To submit fitness data, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function submit_steps --args <CHALLENGE_ID> <STEPS> <AVG_SPEED> $CLOCK --gas-budget 10000000"
echo 
echo "To end a challenge, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function end_challenge --args <CHALLENGE_ID> $CLOCK --gas-budget 10000000"
echo 
echo "To cancel a challenge, run:"
echo "sui client call --package $PACKAGE_ID --module challenge --function cancel_challenge --args <CHALLENGE_ID> --gas-budget 10000000" 