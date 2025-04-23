# SuiFit - Move Smart Contracts

SuiFit is a blockchain-powered social fitness challenge platform where users stake SUI tokens to compete in fun, predefined fitness duels. Winners are determined based on fitness data, and smart contracts handle rewards trustlessly.

## Overview

This repository contains the Move smart contracts for SuiFit, built on the Sui blockchain. The contracts allow users to:

1. Create fitness challenges with custom parameters
2. Join challenges by staking SUI tokens
3. Submit fitness data (steps, speed, etc.)
4. Complete challenges with automatic reward distribution to winners
5. Cancel challenges if needed (creator only)

## Contract Structure

The codebase consists of the following main modules:

- `challenge.move`: Core challenge logic including joining, data submission, and reward distribution
- `challenge_creator.move`: Helper module for challenge creators with special permissions
- `challenge_tests.move`: Tests for the challenge functionality (not used in production)

## Challenge Types

SuiFit supports different types of fitness challenges:

1. **Steps Challenge (Type 1)**: Highest steps in a defined period wins
2. **Speed Challenge (Type 2)**: First to reach a target speed or highest speed wins
3. **Average Challenge (Type 3)**: Best average performance across metrics wins

## Deployment Instructions

### Prerequisites

Make sure you have the Sui CLI installed and configured with a wallet. You also need to have enough SUI tokens for gas fees.

```bash
# Check if Sui CLI is installed
sui --version

# Configure Sui client
sui client
```

### Deploy Contracts

We provide a helper script to build and deploy the contracts:

```bash
# Make sure the script is executable
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

This script will:
1. Build the Move contracts
2. Publish the package to the Sui network
3. Create a creator capability
4. Create a sample challenge
5. Print instructions for interacting with the challenge

### Manual Deployment

If you prefer to deploy manually, follow these steps:

1. Build the contracts:
```bash
sui move build
```

2. Publish the package:
```bash
sui client publish --gas-budget 100000000
```

3. Note the package ID from the output, you'll need it for interactions.

## Interacting with the Contracts

After deployment, you can interact with the contracts using the Sui CLI.

### 1. Create a Challenge

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function publish_challenge \
  --args "Challenge Name" "Challenge Description" 1 86400000 5000000 50000000 120 <CLOCK_ID> \
  --gas-budget 10000000
```

Parameters:
- Challenge name
- Challenge description
- Challenge type (1 = Steps, 2 = Speed, 3 = Average)
- Duration in milliseconds (86400000 = 24 hours)
- Minimum stake (in MIST, 1 SUI = 1,000,000,000 MIST)
- Maximum stake (in MIST)
- Multiplier (in basis points, 120 = 1.2x)
- Clock ID (system clock object)

### 2. Join a Challenge

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function join_challenge \
  --args <CHALLENGE_ID> <COIN_OBJECT_ID> <CLOCK_ID> \
  --gas-budget 10000000
```

### 3. Submit Fitness Data

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function submit_steps \
  --args <CHALLENGE_ID> <STEPS_COUNT> <SPEED_VALUE> <CLOCK_ID> \
  --gas-budget 10000000
```

### 4. End a Challenge

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function end_challenge \
  --args <CHALLENGE_ID> <CLOCK_ID> \
  --gas-budget 10000000
```

### 5. Cancel a Challenge (Creator Only)

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module challenge \
  --function cancel_challenge \
  --args <CHALLENGE_ID> \
  --gas-budget 10000000
```

## Testing

We've included a test script that demonstrates a complete challenge lifecycle:

```bash
# Make the script executable
chmod +x test_challenge.sh

# Run the test script
./test_challenge.sh <PACKAGE_ID> <CHALLENGE_ID> <CLOCK_ID>
```

## Security Notes

- Only the challenge creator can cancel challenges
- Participants can only update their own fitness data
- Challenges automatically determine winners based on the challenge type
- Stakes are automatically returned if a challenge is cancelled

## License

This project is licensed under the MIT License. 