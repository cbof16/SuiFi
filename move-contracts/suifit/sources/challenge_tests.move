#[test_only]
module suifit::challenge_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use std::string;
    use suifit::challenge::{Self, Challenge};
    use suifit::challenge_creator::{Self, CreatorCap};

    const CREATOR: address = @0xCAFE;
    const PARTICIPANT_1: address = @0xFACE;
    const PARTICIPANT_2: address = @0xBEEF;

    // Test challenge creation
    #[test]
    fun test_create_challenge() {
        let scenario = ts::begin(CREATOR);
        let clock = create_clock(&mut scenario, 0);
        
        // Create a challenge as CREATOR
        ts::next_tx(&mut scenario, CREATOR);
        {
            challenge::publish_challenge(
                b"Step Showdown",
                b"Highest steps in 24h wins",
                0, // CHALLENGE_TYPE_STEPS
                24, // 24 hours
                5000000, // 0.005 SUI
                50000000, // 0.05 SUI
                120, // 1.2x multiplier
                &clock,
                ts::ctx(&mut scenario)
            );
        };
        
        // Verify challenge is created and accessible
        ts::next_tx(&mut scenario, CREATOR);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let (title, description, challenge_type, _, _, min_stake, max_stake, multiplier, status, participant_count) = 
                challenge::get_challenge_details(&challenge);
            
            assert!(string::to_ascii(&title) == string::to_ascii(&string::utf8(b"Step Showdown")), 0);
            assert!(string::to_ascii(&description) == string::to_ascii(&string::utf8(b"Highest steps in 24h wins")), 0);
            assert!(challenge_type == 0, 0); // CHALLENGE_TYPE_STEPS
            assert!(min_stake == 5000000, 0);
            assert!(max_stake == 50000000, 0);
            assert!(multiplier == 120, 0);
            assert!(status == 0, 0); // STATUS_ACTIVE
            assert!(participant_count == 0, 0);
            
            ts::return_shared(challenge);
        };
        
        destroy_clock(clock, &mut scenario);
        ts::end(scenario);
    }

    // Test joining a challenge
    #[test]
    fun test_join_challenge() {
        let scenario = ts::begin(CREATOR);
        let clock = create_clock(&mut scenario, 0);
        
        // Create a challenge as CREATOR
        ts::next_tx(&mut scenario, CREATOR);
        {
            challenge::publish_challenge(
                b"Step Showdown",
                b"Highest steps in 24h wins",
                0, // CHALLENGE_TYPE_STEPS
                24, // 24 hours
                5000000, // 0.005 SUI
                50000000, // 0.05 SUI
                120, // 1.2x multiplier
                &clock,
                ts::ctx(&mut scenario)
            );
        };
        
        // PARTICIPANT_1 joins challenge
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let stake_coin = coin::mint_for_testing<SUI>(10000000, ts::ctx(&mut scenario)); // 0.01 SUI
            
            challenge::join_challenge(&mut challenge, stake_coin, &clock, ts::ctx(&mut scenario));
            
            // Verify participant count
            let (_, _, _, _, _, _, _, _, _, participant_count) = challenge::get_challenge_details(&challenge);
            assert!(participant_count == 1, 0);
            
            // Verify participant data
            assert!(challenge::is_participant(&challenge, PARTICIPANT_1), 0);
            let (stake_amount, steps, streak_days, _) = challenge::get_participant_data(&challenge, PARTICIPANT_1);
            assert!(stake_amount == 10000000, 0);
            assert!(steps == 0, 0);
            assert!(streak_days == 0, 0);
            
            ts::return_shared(challenge);
        };
        
        destroy_clock(clock, &mut scenario);
        ts::end(scenario);
    }

    // Test updating fitness data
    #[test]
    fun test_update_fitness_data() {
        let scenario = ts::begin(CREATOR);
        let clock = create_clock(&mut scenario, 0);
        
        // Create a challenge as CREATOR
        ts::next_tx(&mut scenario, CREATOR);
        {
            challenge::publish_challenge(
                b"Step Showdown",
                b"Highest steps in 24h wins",
                0, // CHALLENGE_TYPE_STEPS
                24, // 24 hours
                5000000, // 0.005 SUI
                50000000, // 0.05 SUI
                120, // 1.2x multiplier
                &clock,
                ts::ctx(&mut scenario)
            );
        };
        
        // PARTICIPANT_1 joins challenge
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let stake_coin = coin::mint_for_testing<SUI>(10000000, ts::ctx(&mut scenario)); // 0.01 SUI
            
            challenge::join_challenge(&mut challenge, stake_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // Update participant's fitness data
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            challenge::update_fitness_data(&mut challenge, PARTICIPANT_1, 8500, 1, &clock, ts::ctx(&mut scenario));
            
            // Verify updated data
            let (_, steps, streak_days, _) = challenge::get_participant_data(&challenge, PARTICIPANT_1);
            assert!(steps == 8500, 0);
            assert!(streak_days == 1, 0);
            
            ts::return_shared(challenge);
        };
        
        destroy_clock(clock, &mut scenario);
        ts::end(scenario);
    }

    // Test challenge completion and rewards
    #[test]
    fun test_complete_challenge() {
        let scenario = ts::begin(CREATOR);
        let start_time = 0;
        let clock = create_clock(&mut scenario, start_time);
        
        // Create a challenge as CREATOR
        ts::next_tx(&mut scenario, CREATOR);
        {
            challenge::publish_challenge(
                b"Step Showdown",
                b"Highest steps in 24h wins",
                0, // CHALLENGE_TYPE_STEPS
                24, // 24 hours
                5000000, // 0.005 SUI
                50000000, // 0.05 SUI
                120, // 1.2x multiplier
                &clock,
                ts::ctx(&mut scenario)
            );
        };
        
        // PARTICIPANT_1 joins challenge
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let stake_coin = coin::mint_for_testing<SUI>(10000000, ts::ctx(&mut scenario)); // 0.01 SUI
            
            challenge::join_challenge(&mut challenge, stake_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // PARTICIPANT_2 joins challenge
        ts::next_tx(&mut scenario, PARTICIPANT_2);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let stake_coin = coin::mint_for_testing<SUI>(15000000, ts::ctx(&mut scenario)); // 0.015 SUI
            
            challenge::join_challenge(&mut challenge, stake_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // Update participants' fitness data
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            challenge::update_fitness_data(&mut challenge, PARTICIPANT_1, 8500, 1, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        ts::next_tx(&mut scenario, PARTICIPANT_2);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            challenge::update_fitness_data(&mut challenge, PARTICIPANT_2, 10200, 2, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // Advance clock to end challenge time (24 hours + 1 minute)
        advance_clock(&mut clock, &mut scenario, start_time + (24 * 60 * 60 * 1000) + (60 * 1000));
        
        // End the challenge
        ts::next_tx(&mut scenario, CREATOR);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            challenge::end_challenge(&mut challenge, &clock, ts::ctx(&mut scenario));
            
            // Verify challenge is completed
            let (_, _, _, _, _, _, _, _, status, _) = challenge::get_challenge_details(&challenge);
            assert!(status == 1, 0); // STATUS_COMPLETED
            
            ts::return_shared(challenge);
        };
        
        // Check PARTICIPANT_2 received rewards (they had more steps)
        ts::next_tx(&mut scenario, PARTICIPANT_2);
        {
            // Participant_2 should have received all staked coins (0.01 + 0.015 = 0.025 SUI)
            let coins = ts::ids_for_sender<Coin<SUI>>(&scenario);
            assert!(ts::length(&coins) > 0, 0);
            
            let coin = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&coin) == 25000000, 0); // 0.025 SUI
            ts::return_to_sender(&scenario, coin);
        };
        
        destroy_clock(clock, &mut scenario);
        ts::end(scenario);
    }

    // Helper function to create a Clock for testing
    fun create_clock(scenario: &mut Scenario, timestamp_ms: u64): Clock {
        ts::next_tx(scenario, @0x0);
        clock::create_for_testing(ts::ctx(scenario))
    }

    // Helper function to destroy a Clock after testing
    fun destroy_clock(clock: Clock, scenario: &mut Scenario) {
        ts::next_tx(scenario, @0x0);
        clock::destroy_for_testing(clock);
    }

    // Helper function to advance the clock
    fun advance_clock(clock: &mut Clock, scenario: &mut Scenario, new_timestamp_ms: u64) {
        ts::next_tx(scenario, @0x0);
        clock::set_for_testing(clock, new_timestamp_ms);
    }
} 