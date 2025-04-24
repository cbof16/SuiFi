module suifit::challenge {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::dynamic_field as df;
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
    const EInvalidChallengeType: u64 = 7;
    const EAlreadyInPool: u64 = 8;
    const ENotEnoughPlayers: u64 = 9;

    // Challenge types
    const CHALLENGE_TYPE_STEP_SHOWDOWN: u8 = 1;
    const CHALLENGE_TYPE_SPEED_STREAK: u8 = 2;

    // Status values
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_COMPLETED: u8 = 1;
    const STATUS_CANCELLED: u8 = 2;

    // Fixed stake amounts
    const STAKE_AMOUNT_STEP_SHOWDOWN: u64 = 10000000; // 0.01 SUI
    const STAKE_AMOUNT_SPEED_STREAK: u64 = 20000000; // 0.02 SUI

    // Event structures
    struct PlayerJoinedPool has copy, drop {
        player: address,
        challenge_type: u8,
        stake_amount: u64,
        timestamp: u64,
    }

    struct MatchCreated has copy, drop {
        player1: address,
        player2: address,
        challenge_type: u8,
        challenge_id: address,
    }

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
        stake_amount: u64,  // Fixed amount instead of min/max
        multiplier: u64,
        reward_pool: Balance<SUI>,
    }

    // Matching pool for pairing players
    struct MatchingPool has key, store {
        id: UID,
        challenge_type: u8,
        stake_amount: u64,
        waiting_players: vector<address>,
        timestamps: vector<u64>, // When players joined
    }

    // Creates a new challenge object
    fun create_challenge(
        creator: address,
        title: String,
        description: String,
        challenge_type: u8,
        duration: u64,
        stake_amount: u64,
        multiplier: u64,
        start_time: u64,
        ctx: &mut TxContext
    ): Challenge {
        Challenge {
            id: object::new(ctx),
            creator,
            title,
            description,
            challenge_type,
            status: STATUS_ACTIVE,
            participants: vector::empty(),
            start_time,
            end_time: start_time + duration,
            stake_amount,
            multiplier,
            reward_pool: balance::zero<SUI>(),
        }
    }

    // Create and publish a standard challenge
    public entry fun create_standard_challenge(
        challenge_type: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate challenge type
        assert!(
            challenge_type == CHALLENGE_TYPE_STEP_SHOWDOWN || 
            challenge_type == CHALLENGE_TYPE_SPEED_STREAK,
            EInvalidChallengeType
        );
        
        // Set parameters based on challenge type
        let (title, description, stake_amount, duration, multiplier) = if (challenge_type == CHALLENGE_TYPE_STEP_SHOWDOWN) {
            (
                string::utf8(b"Step Showdown"),
                string::utf8(b"Most steps in 24h wins it all!"),
                STAKE_AMOUNT_STEP_SHOWDOWN,
                86400000, // 24 hours in ms
                120 // 1.2x multiplier
            )
        } else {
            (
                string::utf8(b"Speed Streak"),
                string::utf8(b"Maintain your daily step goal for 48h"),
                STAKE_AMOUNT_SPEED_STREAK,
                172800000, // 48 hours in ms
                150 // 1.5x multiplier
            )
        };
        
        // Create and share challenge
        let challenge = create_challenge(
            tx_context::sender(ctx),
            title,
            description,
            challenge_type,
            duration,
            stake_amount,
            multiplier,
            clock::timestamp_ms(clock),
            ctx
        );
        
        transfer::share_object(challenge);
    }

    // Initialize matching pools for standard challenge types
    public entry fun initialize_matching_pools(ctx: &mut TxContext) {
        let step_showdown_pool = MatchingPool {
            id: object::new(ctx),
            challenge_type: CHALLENGE_TYPE_STEP_SHOWDOWN,
            stake_amount: STAKE_AMOUNT_STEP_SHOWDOWN,
            waiting_players: vector::empty(),
            timestamps: vector::empty(),
        };
        
        let speed_streak_pool = MatchingPool {
            id: object::new(ctx),
            challenge_type: CHALLENGE_TYPE_SPEED_STREAK,
            stake_amount: STAKE_AMOUNT_SPEED_STREAK,
            waiting_players: vector::empty(),
            timestamps: vector::empty(),
        };
        
        transfer::share_object(step_showdown_pool);
        transfer::share_object(speed_streak_pool);
    }

    // Join a matching pool to find an opponent
    public entry fun join_matching_pool(
        pool: &mut MatchingPool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let player = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        
        // Check if player is already in the pool
        let i = 0;
        let len = vector::length(&pool.waiting_players);
        let already_in_pool = false;
        
        while (i < len) {
            if (*vector::borrow(&pool.waiting_players, i) == player) {
                already_in_pool = true;
                break;
            };
            i = i + 1;
        };
        
        assert!(!already_in_pool, EAlreadyInPool);
        
        // Add player to waiting pool
        vector::push_back(&mut pool.waiting_players, player);
        vector::push_back(&mut pool.timestamps, current_time);
        
        // Emit event for frontend to track
        event::emit(PlayerJoinedPool {
            player,
            challenge_type: pool.challenge_type,
            stake_amount: pool.stake_amount,
            timestamp: current_time,
        });
    }

    // Create a match from the waiting pool
    public entry fun create_match(
        pool: &mut MatchingPool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Need at least 2 players to match
        assert!(vector::length(&pool.waiting_players) >= 2, ENotEnoughPlayers);
        
        // Get first two players (FIFO)
        let player1 = vector::remove(&mut pool.waiting_players, 0);
        let _timestamp1 = vector::remove(&mut pool.timestamps, 0);
        
        let player2 = vector::remove(&mut pool.waiting_players, 0);
        let _timestamp2 = vector::remove(&mut pool.timestamps, 0);
        
        // Create appropriate challenge
        let current_time = clock::timestamp_ms(clock);
        let (title, description, stake_amount, duration, multiplier) = if (pool.challenge_type == CHALLENGE_TYPE_STEP_SHOWDOWN) {
            (
                string::utf8(b"Step Showdown"),
                string::utf8(b"Most steps in 24h wins it all!"),
                STAKE_AMOUNT_STEP_SHOWDOWN,
                86400000, // 24 hours in ms
                120 // 1.2x multiplier
            )
        } else {
            (
                string::utf8(b"Speed Streak"),
                string::utf8(b"Maintain your daily step goal for 48h"),
                STAKE_AMOUNT_SPEED_STREAK,
                172800000, // 48 hours in ms
                150 // 1.5x multiplier
            )
        };
        
        let challenge = create_challenge(
            tx_context::sender(ctx),
            title,
            description,
            pool.challenge_type,
            duration,
            stake_amount,
            multiplier,
            current_time,
            ctx
        );
        
        // Store matched players reference using dynamic fields
        df::add(&mut challenge.id, b"player1", player1);
        df::add(&mut challenge.id, b"player2", player2);
        
        // Share the challenge
        let challenge_id = object::uid_to_address(&challenge.id);
        transfer::share_object(challenge);
        
        // Emit event for frontend
        event::emit(MatchCreated {
            player1,
            player2,
            challenge_type: pool.challenge_type,
            challenge_id,
        });
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
        let player = tx_context::sender(ctx);
        
        // Validate stake amount is exactly the required amount
        assert!(stake_amount == challenge.stake_amount, EInvalidStake);
        
        // Verify challenge is still active
        assert!(challenge.status == STATUS_ACTIVE, EChallengeEnded);
        assert!(current_time < challenge.end_time, EChallengeEnded);
        
        // Verify player is part of the match (if this is a matched challenge)
        if (df::exists_(&challenge.id, b"player1") && df::exists_(&challenge.id, b"player2")) {
            let player1 = *df::borrow<vector<u8>, address>(&challenge.id, b"player1");
            let player2 = *df::borrow<vector<u8>, address>(&challenge.id, b"player2");
            assert!(player == player1 || player == player2, ENotParticipant);
        };
        
        // Add participant to the challenge
        let participant = Participant {
            user: player,
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

    // Helper function to get winner and runner-up
    fun get_top_performers(challenge: &Challenge): (Option<address>, Option<address>) {
        let participant_count = vector::length(&challenge.participants);
        
        // Ensure there are participants
        if (participant_count == 0) {
            return (option::none(), option::none())
        };
        
        // For a single participant, they're the winner with no runner-up
        if (participant_count == 1) {
            let participant = vector::borrow(&challenge.participants, 0);
            return (option::some(participant.user), option::none())
        };
        
        // Initialize with first participant
        let best_value = 0;
        let second_best = 0;
        let best_idx = 0;
        let second_idx = 0;
        let i = 0;

        // First pass to find the best
        while (i < participant_count) {
            let participant = vector::borrow(&challenge.participants, i);
            
            // Calculate value based on challenge type
            let value_to_compare = if (challenge.challenge_type == CHALLENGE_TYPE_STEP_SHOWDOWN) {
                participant.steps
            } else {
                // For Speed Streak, consider both steps and avg_speed
                participant.steps + participant.avg_speed
            };

            if (value_to_compare > best_value) {
                // Current best becomes second
                second_best = best_value;
                second_idx = best_idx;
                
                // New best
                best_value = value_to_compare;
                best_idx = i;
            } else if (value_to_compare > second_best) {
                // New second best
                second_best = value_to_compare;
                second_idx = i;
            };
            
            i = i + 1;
        };

        // If no one has made progress, return none
        if (best_value == 0) {
            return (option::none(), option::none())
        };
        
        // Convert to addresses
        let winner = vector::borrow(&challenge.participants, best_idx).user;
        
        // Only return runner-up if they have a non-zero value
        if (second_best > 0) {
            let runner_up = vector::borrow(&challenge.participants, second_idx).user;
            (option::some(winner), option::some(runner_up))
        } else {
            (option::some(winner), option::none())
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
            
            // Get top performers
            let (winner_opt, runner_up_opt) = get_top_performers(challenge);
            
            // Calculate total reward
            let total_reward = balance::value(&challenge.reward_pool);
            
            if (option::is_some(&winner_opt)) {
                let winner = option::extract(&mut winner_opt);
                
                // Winner gets 80% of pool
                let winner_share = (total_reward * 80) / 100;
                let winner_coin = coin::from_balance(
                    balance::split(&mut challenge.reward_pool, winner_share), 
                    ctx
                );
                transfer::public_transfer(winner_coin, winner);
                
                // Runner-up gets 15% if they exist
                if (option::is_some(&runner_up_opt)) {
                    let runner_up = option::extract(&mut runner_up_opt);
                    let runner_up_share = (total_reward * 15) / 100;
                    let runner_up_coin = coin::from_balance(
                        balance::split(&mut challenge.reward_pool, runner_up_share),
                        ctx
                    );
                    transfer::public_transfer(runner_up_coin, runner_up);
                };
                
                // Remaining 5% stays in contract (platform fee)
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
    public fun get_challenge_details(challenge: &Challenge): (String, String, u8, u64, u64, u64, u64, u8, u64) {
        (
            challenge.title,
            challenge.description,
            challenge.challenge_type,
            challenge.start_time,
            challenge.end_time,
            challenge.stake_amount,
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
    
    /// Get waiting players count in a matching pool
    public fun get_waiting_players_count(pool: &MatchingPool): u64 {
        vector::length(&pool.waiting_players)
    }
} 