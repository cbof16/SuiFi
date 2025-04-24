module suifit::challenge_creator {
    use sui::object;
    use sui::transfer;
    use sui::tx_context;
    use sui::clock::{Clock};
    use std::string;
    use suifit::challenge;

    // Error codes
    const EUnauthorized: u64 = 0;
    const EInvalidChallengeType: u64 = 1;

    /// Creator capability for managing challenges
    struct CreatorCap has key, store {
        id: object::UID,
        creator: address,
        name: string::String,
        created_challenges: u64,
    }

    /// Create a new creator capability
    public entry fun create_creator_cap(
        name: vector<u8>,
        ctx: &mut tx_context::TxContext
    ) {
        let creator_cap = CreatorCap {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            name: string::utf8(name),
            created_challenges: 0,
        };
        
        transfer::transfer(creator_cap, tx_context::sender(ctx));
    }

    /// Create a challenge using creator capability 
    public entry fun create_challenge_with_cap(
        cap: &mut CreatorCap,
        challenge_type: u8,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        // Verify creator is the owner of the cap
        let sender = tx_context::sender(ctx);
        assert!(cap.creator == sender, EUnauthorized);
        
        // Validate challenge type (1 = Step Showdown, 2 = Speed Streak)
        assert!(challenge_type == 1 || challenge_type == 2, EInvalidChallengeType);
        
        // Create and publish challenge
        challenge::create_standard_challenge(
            challenge_type,
            clock,
            ctx
        );
        
        // Increment created challenges count
        cap.created_challenges = cap.created_challenges + 1;
    }

    /// Get creator information
    public fun get_creator_info(cap: &CreatorCap): (address, string::String, u64) {
        (cap.creator, cap.name, cap.created_challenges)
    }
} 