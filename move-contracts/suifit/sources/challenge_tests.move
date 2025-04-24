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

    // Fixed stake amounts
    const STAKE_AMOUNT_STEP_SHOWDOWN: u64 = 10000000; // 0.01 SUI
    const STAKE_AMOUNT_SPEED_STREAK: u64 = 20000000; // 0.02 SUI

    // Challenge types
    const CHALLENGE_TYPE_STEP_SHOWDOWN: u8 = 1;
    const CHALLENGE_TYPE_SPEED_STREAK: u8 = 2;

    // Test challenge creation
    #[test]
    fun test_create_challenge() {
        let scenario = ts::begin(CREATOR);
        let clock = create_clock(&mut scenario, 0);
        
        // Create a Step Showdown challenge
        ts::next_tx(&mut scenario, CREATOR);
        {
            challenge::create_standard_challenge(
                CHALLENGE_TYPE_STEP_SHOWDOWN,
                &clock,
                ts::ctx(&mut scenario)
            );
        };
        
        // Verify challenge is created and accessible
        ts::next_tx(&mut scenario, CREATOR);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let (title, description, challenge_type, _, _, stake_amount, multiplier, status, participant_count) = 
                challenge::get_challenge_details(&challenge);
            
            assert!(string::to_ascii(&title) == string::to_ascii(&string::utf8(b"Step Showdown")), 0);
            assert!(string::to_ascii(&description) == string::to_ascii(&string::utf8(b"Most steps in 24h wins it all!")), 0);
            assert!(challenge_type == CHALLENGE_TYPE_STEP_SHOWDOWN, 0);
            assert!(stake_amount == STAKE_AMOUNT_STEP_SHOWDOWN, 0);
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
            challenge::create_standard_challenge(
                CHALLENGE_TYPE_STEP_SHOWDOWN,
                &clock,
                ts::ctx(&mut scenario)
            );
        };
        
        // PARTICIPANT_1 joins challenge
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let stake_coin = coin::mint_for_testing<SUI>(STAKE_AMOUNT_STEP_SHOWDOWN, ts::ctx(&mut scenario));
            
            challenge::join_challenge(&mut challenge, stake_coin, &clock, ts::ctx(&mut scenario));
            
            // Verify participant count
            let (_, _, _, _, _, _, _, _, participant_count) = challenge::get_challenge_details(&challenge);
            assert!(participant_count == 1, 0);
            
            // Verify participant data
            assert!(challenge::is_participant(&challenge, PARTICIPANT_1), 0);
            let (stake_amount, steps, avg_speed, _) = challenge::get_participant_data(&challenge, PARTICIPANT_1);
            assert!(stake_amount == STAKE_AMOUNT_STEP_SHOWDOWN, 0);
            assert!(steps == 0, 0);
            assert!(avg_speed == 0, 0);
            
            ts::return_shared(challenge);
        };
        
        destroy_clock(clock, &mut scenario);
        ts::end(scenario);
    }

    // Test submitting steps data
    #[test]
    fun test_submit_steps() {
        let scenario = ts::begin(CREATOR);
        let clock = create_clock(&mut scenario, 0);
        
        // Create a challenge as CREATOR
        ts::next_tx(&mut scenario, CREATOR);
        {
            challenge::create_standard_challenge(
                CHALLENGE_TYPE_STEP_SHOWDOWN,
                &clock,
                ts::ctx(&mut scenario)
            );
        };
        
        // PARTICIPANT_1 joins challenge
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let stake_coin = coin::mint_for_testing<SUI>(STAKE_AMOUNT_STEP_SHOWDOWN, ts::ctx(&mut scenario));
            
            challenge::join_challenge(&mut challenge, stake_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // Update participant's steps data
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            challenge::submit_steps(&mut challenge, 8500, 120, &clock, ts::ctx(&mut scenario));
            
            // Verify updated data
            let (_, steps, avg_speed, _) = challenge::get_participant_data(&challenge, PARTICIPANT_1);
            assert!(steps == 8500, 0);
            assert!(avg_speed == 120, 0);
            
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
            challenge::create_standard_challenge(
                CHALLENGE_TYPE_STEP_SHOWDOWN,
                &clock,
                ts::ctx(&mut scenario)
            );
        };
        
        // PARTICIPANT_1 joins challenge
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let stake_coin = coin::mint_for_testing<SUI>(STAKE_AMOUNT_STEP_SHOWDOWN, ts::ctx(&mut scenario));
            
            challenge::join_challenge(&mut challenge, stake_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // PARTICIPANT_2 joins challenge
        ts::next_tx(&mut scenario, PARTICIPANT_2);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            let stake_coin = coin::mint_for_testing<SUI>(STAKE_AMOUNT_STEP_SHOWDOWN, ts::ctx(&mut scenario));
            
            challenge::join_challenge(&mut challenge, stake_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // Submit steps for participants
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            challenge::submit_steps(&mut challenge, 9500, 120, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        ts::next_tx(&mut scenario, PARTICIPANT_2);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            challenge::submit_steps(&mut challenge, 8500, 110, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // Fast forward 24 hours to end the challenge
        clock::increment_for_testing(&mut clock, 86400000);
        
        // End the challenge
        ts::next_tx(&mut scenario, CREATOR);
        {
            let challenge = ts::take_shared<Challenge>(&scenario);
            challenge::end_challenge(&mut challenge, &clock, ts::ctx(&mut scenario));
            ts::return_shared(challenge);
        };
        
        // Verify PARTICIPANT_1 received rewards (80% of pool)
        ts::next_tx(&mut scenario, PARTICIPANT_1);
        {
            let coins = ts::ids_for_sender<Coin<SUI>>(&scenario);
            assert!(coins.length() > 0, 0);
        };
        
        // Verify PARTICIPANT_2 received rewards (15% of pool as runner-up)
        ts::next_tx(&mut scenario, PARTICIPANT_2);
        {
            let coins = ts::ids_for_sender<Coin<SUI>>(&scenario);
            assert!(coins.length() > 0, 0);
        };
        
        destroy_clock(clock, &mut scenario);
        ts::end(scenario);
    }
    
    // Test matchmaking pool
    #[test]
    fun test_matchmaking() {
        let scenario = ts::begin(CREATOR);
        let clock = create_clock(&mut scenario, 0);
        
        // Initialize matching pools
        ts::next_tx(&mut scenario, CREATOR);
        {
            challenge::initialize_matching_pools(ts::ctx(&mut scenario));
        };
        
        // Verify matching pools were created
        ts::next_tx(&mut scenario, CREATOR);
        {
            let pools = ts::shared_objects<challenge::MatchingPool>(&scenario);
            assert!(pools.length() == 2, 0); // Should have 2 pools (one for each challenge type)
            
            let step_showdown_pool = ts::take_shared<challenge::MatchingPool>(&scenario);
            let speed_streak_pool = ts::take_shared<challenge::MatchingPool>(&scenario);
            
            let count1 = challenge::get_waiting_players_count(&step_showdown_pool);
            let count2 = challenge::get_waiting_players_count(&speed_streak_pool);
            assert!(count1 == 0, 0);
            assert!(count2 == 0, 0);
            
            ts::return_shared(step_showdown_pool);
            ts::return_shared(speed_streak_pool);
        };
        
        destroy_clock(clock, &mut scenario);
        ts::end(scenario);
    }
    
    // Helper to create a clock for testing
    fun create_clock(scenario: &mut Scenario, time_ms: u64): Clock {
        ts::next_tx(scenario, @0);
        let clock = clock::create_for_testing(ts::ctx(scenario));
        clock::set_for_testing(&mut clock, time_ms);
        clock
    }
    
    // Helper to destroy a clock
    fun destroy_clock(clock: Clock, scenario: &mut Scenario) {
        ts::next_tx(scenario, @0);
        clock::destroy_for_testing(clock);
    }
} 