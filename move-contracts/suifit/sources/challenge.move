module suifit::challenge {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use std::option::{Self, Option};
    use std::vector;
    use std::string::{Self, String};

    // Error codes
    const EChallengeNotEnded: u64 = 1;
    const ENoParticipants: u64 = 2;
    const ENotCreator: u64 = 3;
    const ENotParticipant: u64 = 4;
    const EInvalidStake: u64 = 5;
    const EChallengeEnded: u64 = 6;

    // Challenge types
    const CHALLENGE_TYPE_STEPS: u8 = 1;
    const CHALLENGE_TYPE_SPEED: u8 = 2;
    const CHALLENGE_TYPE_AVERAGE: u8 = 3;

    // Status values
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_COMPLETED: u8 = 1;
    const STATUS_CANCELLED: u8 = 2;

    // Participant struct to track individual data
    struct Participant has store, drop, copy {
        user: address,
        stake: u64,
        steps: u64,
        avg_speed: u64,
        join_time: u64,
    }

    // Challenge struct
    struct Challenge has key, store {
        id: UID,
        creator: address,
        title: String,
        description: String,
        challenge_type: u8,
        status: u8,
        participants: vector<Participant>,
        start_time: u64,
        end_time: u64,
        min_stake: u64,
        max_stake: u64,
        multiplier: u64,
        reward_pool: Balance<SUI>,
    }

    // Creates a new challenge object
    fun create_challenge(
        creator: address,
        title: vector<u8>,
        description: vector<u8>,
        challenge_type: u8,
        duration: u64,
        min_stake: u64,
        max_stake: u64,
        multiplier: u64,
        start_time: u64,
        ctx: &mut TxContext
    ): Challenge {
        Challenge {
            id: object::new(ctx),
            creator,
            title: string::utf8(title),
            description: string::utf8(description),
            challenge_type,
            status: STATUS_ACTIVE,
            participants: vector::empty(),
            start_time,
            end_time: start_time + duration,
            min_stake,
            max_stake,
            multiplier,
            reward_pool: balance::zero<SUI>(),
        }
    }

    // Create and publish a new challenge
    public entry fun publish_challenge(
        title: vector<u8>,
        description: vector<u8>,
        challenge_type: u8,
        duration: u64,
        min_stake: u64,
        max_stake: u64,
        multiplier: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let challenge = create_challenge(
            tx_context::sender(ctx),
            title,
            description,
            challenge_type,
            duration,
            min_stake,
            max_stake,
            multiplier,
            clock::timestamp_ms(clock),
            ctx
        );

        transfer::share_object(challenge);
    }

    // Join a challenge by staking SUI
    public entry fun join_challenge(
        challenge: &mut Challenge,
        stake_coin: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let stake_amount = coin::value(&stake_coin);
        let current_time = clock::timestamp_ms(clock);
        
        // Validate stake amount is within range
        assert!(
            stake_amount >= challenge.min_stake && stake_amount <= challenge.max_stake,
            EInvalidStake
        );
        
        // Verify challenge is still active
        assert!(challenge.status == STATUS_ACTIVE, EChallengeEnded);
        assert!(current_time < challenge.end_time, EChallengeEnded);
        
        // Add participant to the challenge
        let participant = Participant {
            user: tx_context::sender(ctx),
            stake: stake_amount,
            steps: 0,
            avg_speed: 0,
            join_time: current_time,
        };
        
        vector::push_back(&mut challenge.participants, participant);
        
        // Add stake to reward pool
        balance::join(&mut challenge.reward_pool, coin::into_balance(stake_coin));
    }

    // Submit fitness data for the challenge
    public entry fun submit_steps(
        challenge: &mut Challenge,
        steps: u64,
        avg_speed: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        
        // Verify challenge is still active
        assert!(challenge.status == STATUS_ACTIVE, EChallengeEnded);
        assert!(current_time < challenge.end_time, EChallengeEnded);
        
        let len = vector::length(&challenge.participants);
        let i = 0;
        let found = false;
        
        while (i < len) {
            let participant = vector::borrow_mut(&mut challenge.participants, i);
            if (participant.user == sender) {
                participant.steps = steps;
                participant.avg_speed = avg_speed;
                found = true;
                break;
            };
            i = i + 1;
        };
        
        assert!(found, ENotParticipant);
    }

    // Helper function to determine the winner based on challenge type
    fun get_winner(challenge: &Challenge): Option<address> {
        let i = 0;
        let participant_count = vector::length(&challenge.participants);
        
        // Ensure there are participants
        if (participant_count == 0) {
            return option::none()
        };
        
        let max_value = 0;
        let winner_idx = 0;

        while (i < participant_count) {
            let participant = vector::borrow(&challenge.participants, i);
            
            // Depending on the challenge type, determine the winner
            let value_to_compare = if (challenge.challenge_type == CHALLENGE_TYPE_STEPS) {
                participant.steps
            } else if (challenge.challenge_type == CHALLENGE_TYPE_SPEED) {
                participant.avg_speed
            } else if (challenge.challenge_type == CHALLENGE_TYPE_AVERAGE) {
                // For average challenge, use a simple average calculation
                if (participant.steps > 0 && participant.avg_speed > 0) {
                    (participant.steps + participant.avg_speed) / 2
                } else {
                    0
                }
            } else {
                0 // Default case, shouldn't happen
            };

            if (value_to_compare > max_value) {
                max_value = value_to_compare;
                winner_idx = i;
            };
            
            i = i + 1;
        };

        // If no one has made progress, return none
        if (max_value == 0) {
            option::none()
        } else {
            option::some(vector::borrow(&challenge.participants, winner_idx).user)
        }
    }

    // End a challenge, determine winner and distribute rewards
    public entry fun end_challenge(
        challenge: &mut Challenge,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Check if challenge has ended
        assert!(current_time >= challenge.end_time || tx_context::sender(ctx) == challenge.creator, EChallengeNotEnded);
        
        // Only complete challenges that are still active
        if (challenge.status == STATUS_ACTIVE) {
            challenge.status = STATUS_COMPLETED;
            
            // Get the participant count
            let participant_count = vector::length(&challenge.participants);
            
            // Ensure there are participants
            assert!(participant_count > 0, ENoParticipants);
            
            let winner_opt = get_winner(challenge);
            
            if (option::is_some(&winner_opt)) {
                let winner = option::extract(&mut winner_opt);
                
                // Calculate rewards based on total reward pool
                let reward_amount = balance::value(&challenge.reward_pool);
                let reward_coin = coin::from_balance(balance::split(&mut challenge.reward_pool, reward_amount), ctx);
                
                // Transfer rewards to winner
                transfer::public_transfer(reward_coin, winner);
            };
        };
    }

    // Cancel a challenge (only creator can cancel)
    public entry fun cancel_challenge(
        challenge: &mut Challenge,
        ctx: &mut TxContext
    ) {
        // Only creator can cancel
        assert!(tx_context::sender(ctx) == challenge.creator, ENotCreator);
        
        // Only active challenges can be cancelled
        assert!(challenge.status == STATUS_ACTIVE, EChallengeEnded);
        
        challenge.status = STATUS_CANCELLED;
        
        // Return stakes to participants
        let i = 0;
        let len = vector::length(&challenge.participants);
        
        while (i < len) {
            let participant = vector::borrow(&challenge.participants, i);
            let return_amount = participant.stake;
            
            if (return_amount > 0 && balance::value(&challenge.reward_pool) >= return_amount) {
                let return_coin = coin::from_balance(balance::split(&mut challenge.reward_pool, return_amount), ctx);
                transfer::public_transfer(return_coin, participant.user);
            };
            
            i = i + 1;
        };
    }

    // --- View functions ---

    /// Get challenge details
    public fun get_challenge_details(challenge: &Challenge): (String, String, u8, u64, u64, u64, u64, u64, u8, u64) {
        (
            challenge.title,
            challenge.description,
            challenge.challenge_type,
            challenge.start_time,
            challenge.end_time,
            challenge.min_stake,
            challenge.max_stake,
            challenge.multiplier,
            challenge.status,
            vector::length(&challenge.participants)
        )
    }

    /// Check if an address is a participant in the challenge
    public fun is_participant(challenge: &Challenge, participant: address): bool {
        let i = 0;
        let len = vector::length(&challenge.participants);
        
        while (i < len) {
            let p = vector::borrow(&challenge.participants, i);
            if (p.user == participant) {
                return true
            };
            i = i + 1;
        };
        
        false
    }

    /// Get participant data if available
    public fun get_participant_data(challenge: &Challenge, participant_addr: address): (u64, u64, u64, u64) {
        let i = 0;
        let len = vector::length(&challenge.participants);
        
        while (i < len) {
            let p = vector::borrow(&challenge.participants, i);
            if (p.user == participant_addr) {
                return (p.stake, p.steps, p.avg_speed, p.join_time)
            };
            i = i + 1;
        };
        
        abort ENotParticipant
    }

    /// Get total reward pool amount
    public fun get_reward_pool(challenge: &Challenge): u64 {
        balance::value(&challenge.reward_pool)
    }
} 