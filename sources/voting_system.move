module voting_addr::voting_system {
    use std::string::{String};
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_std::table::{Self, Table};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ELECTION_NOT_FOUND: u64 = 2;
    const E_ALREADY_VOTED: u64 = 3;
    const E_INVALID_CANDIDATE: u64 = 4;

    // Structs
    struct Candidate has store, drop, copy {
        name: String,
        vote_count: u64
    }

    struct Election has store {
        id: u64,
        title: String,
        candidates: vector<Candidate>,
        is_active: bool
    }

    struct VotingSystem has key {
        elections: Table<u64, Election>,
        election_counter: u64,
        admin: address,
        election_events: EventHandle<ElectionCreatedEvent>,
        vote_events: EventHandle<VoteCastEvent>
    }

    struct VoterRecord has key {
        voted_elections: vector<u64>
    }

    // Events
    #[event]
    struct ElectionCreatedEvent has drop, store {
        election_id: u64,
        title: String
    }

    #[event]
    struct VoteCastEvent has drop, store {
        election_id: u64,
        voter: address,
        candidate_index: u64
    }

    // Initialize the voting system
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        let voting_system = VotingSystem {
            elections: table::new(),
            election_counter: 0,
            admin: addr,
            election_events: account::new_event_handle<ElectionCreatedEvent>(account),
            vote_events: account::new_event_handle<VoteCastEvent>(account)
        };
        move_to(account, voting_system);
    }

    // Create a new election
    public entry fun create_election(
        account: &signer,
        title: String,
        candidate_names: vector<String>
    ) acquires VotingSystem {
        let addr = signer::address_of(account);
        let voting_system = borrow_global_mut<VotingSystem>(@voting_addr);
        
        assert!(addr == voting_system.admin, E_NOT_AUTHORIZED);
        
        let candidates = vector::empty<Candidate>();
        let i = 0;
        while (i < vector::length(&candidate_names)) {
            let candidate = Candidate {
                name: *vector::borrow(&candidate_names, i),
                vote_count: 0
            };
            vector::push_back(&mut candidates, candidate);
            i = i + 1;
        };

        let election = Election {
            id: voting_system.election_counter,
            title,
            candidates,
            is_active: true
        };

        table::add(&mut voting_system.elections, voting_system.election_counter, election);
        
        event::emit_event(&mut voting_system.election_events, ElectionCreatedEvent {
            election_id: voting_system.election_counter,
            title
        });

        voting_system.election_counter = voting_system.election_counter + 1;
    }

    // Cast a vote in an election
    public entry fun cast_vote(
        account: &signer,
        election_id: u64,
        candidate_index: u64
    ) acquires VotingSystem, VoterRecord {
        let addr = signer::address_of(account);
        let voting_system = borrow_global_mut<VotingSystem>(@voting_addr);
        
        // Ensure election exists and is active
        assert!(table::contains(&voting_system.elections, election_id), E_ELECTION_NOT_FOUND);
        let election = table::borrow_mut(&mut voting_system.elections, election_id);
        assert!(election.is_active, E_ELECTION_NOT_FOUND);
        
        // Check if voter has already voted
        if (!exists<VoterRecord>(addr)) {
            move_to(account, VoterRecord { voted_elections: vector::empty() });
        };
        
        let voter_record = borrow_global_mut<VoterRecord>(addr);
        let i = 0;
        let len = vector::length(&voter_record.voted_elections);
        while (i < len) {
            assert!(*vector::borrow(&voter_record.voted_elections, i) != election_id, E_ALREADY_VOTED);
            i = i + 1;
        };
        
        // Ensure candidate index is valid
        assert!(candidate_index < vector::length(&election.candidates), E_INVALID_CANDIDATE);
        
        // Record vote
        let candidate = vector::borrow_mut(&mut election.candidates, candidate_index);
        candidate.vote_count = candidate.vote_count + 1;
        vector::push_back(&mut voter_record.voted_elections, election_id);
        
        event::emit_event(&mut voting_system.vote_events, VoteCastEvent {
            election_id,
            voter: addr,
            candidate_index
        });
    }

    // Get election details
    public fun get_election_details(election_id: u64): (String, vector<Candidate>) acquires VotingSystem {
        let voting_system = borrow_global<VotingSystem>(@voting_addr);
        assert!(table::contains(&voting_system.elections, election_id), E_ELECTION_NOT_FOUND);
        let election = table::borrow(&voting_system.elections, election_id);
        (election.title, election.candidates)
    }

    // Check if an address has voted in a specific election
    public fun has_voted(addr: address, election_id: u64): bool acquires VoterRecord {
        if (!exists<VoterRecord>(addr)) {
            return false
        };
        
        let voter_record = borrow_global<VoterRecord>(addr);
        let i = 0;
        let len = vector::length(&voter_record.voted_elections);
        while (i < len) {
            if (*vector::borrow(&voter_record.voted_elections, i) == election_id) {
                return true
            };
            i = i + 1;
        };
        false
    }
}