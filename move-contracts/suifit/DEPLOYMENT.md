# SuiFit Smart Contract Deployment Guide

This guide provides step-by-step instructions for deploying the SuiFit smart contracts to the Sui blockchain.

## Prerequisites

Before you begin, make sure you have:

1. Installed the Sui CLI (v1.0.0 or newer)
2. Set up a Sui wallet with sufficient SUI tokens for gas
3. Connected to the Sui network (testnet or mainnet)

## Step 1: Configure Sui Client

Ensure your Sui client is properly configured and connected to the right network:

```bash
# Check current active address
sui client active-address

# Connect to testnet if needed
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
sui client switch --env testnet

# Request testnet tokens (if needed)
# Visit https://faucet.sui.io and enter your address
```

## Step 2: Build the Smart Contracts

Build the Move contracts to make sure they compile correctly:

```bash
cd suifit/move-contracts/suifit
sui move build
```

## Step 3: Publish the Smart Contracts

Deploy the contracts to the Sui network:

```bash
sui client publish --gas-budget 100000000
```

The output will provide you with a package ID. Save this value as you'll need it for all future interactions.

## Step 4: Create a Creator Capability

Create a creator capability to manage challenges:

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module challenge_creator \
  --function create_creator_cap \
  --args "SuiFit Creator" \
  --gas-budget 10000000
```

Get the creator capability object ID:

```bash
sui client objects --json | grep -i creator
```

## Step 5: Create Your First Challenge

Create a new fitness challenge:

```bash
# First find the system clock object
CLOCK=$(sui client objects --json | grep -io \"0x6\".*clock | grep -o "0x.*\"" | tr -d \")

# Create the challenge
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function publish_challenge \
  --args "Step Showdown" "Highest steps in 24h wins" 1 86400000 5000000 50000000 120 $CLOCK \
  --gas-budget 10000000
```

Parameters explained:
- "Step Showdown": Challenge name
- "Highest steps in 24h wins": Challenge description
- 1: Challenge type (1=steps, 2=speed, 3=average)
- 86400000: Duration in milliseconds (24 hours)
- 5000000: Minimum stake (0.005 SUI)
- 50000000: Maximum stake (0.05 SUI)
- 120: Multiplier in basis points (1.2x)
- $CLOCK: System clock object ID

## Step 6: Find the Challenge Object ID

Get the challenge object ID:

```bash
sui client objects --json | grep -i challenge
```

## Step 7: Join and Interact with the Challenge

Join the challenge by staking SUI:

```bash
# Get a SUI coin for staking
COINS=$(sui client gas --json)
COIN_ID=$(echo "$COINS" | jq -r '.data[0].id.id')

# Join the challenge
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function join_challenge \
  --args <CHALLENGE_ID> $COIN_ID $CLOCK \
  --gas-budget 10000000
```

Submit fitness data:

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function submit_steps \
  --args <CHALLENGE_ID> 10000 500 $CLOCK \
  --gas-budget 10000000
```

## Step 8: End the Challenge

When the challenge duration is over, end the challenge:

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function end_challenge \
  --args <CHALLENGE_ID> $CLOCK \
  --gas-budget 10000000
```

## Step 9: Verify Results

Check the final state of the challenge:

```bash
sui client object <CHALLENGE_ID>
```

## Troubleshooting

### Common Issues:

1. **Insufficient gas**: Increase the gas budget value.
2. **Transaction failed**: Make sure you're using the correct object IDs.
3. **Challenge not ending**: Verify that you're the creator or the duration has passed.

## Automated Testing

Use the included test scripts for easier testing:

```bash
# Deploy all contracts and create a sample challenge
./deploy.sh

# Run through a complete challenge lifecycle
./test_challenge.sh <PACKAGE_ID> <CHALLENGE_ID> <CLOCK_ID>
```

---

By following these steps, you'll successfully deploy and interact with the SuiFit smart contracts on the Sui blockchain.

## Monitoring Transactions

You can view the status of your transactions and objects on the Sui Explorer:
https://explorer.sui.io/?network=testnet

 