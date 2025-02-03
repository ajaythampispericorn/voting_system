// module voting_addr::voting_system {
//     use std::string::{String};
//     use std::vector;
//     use std::signer;
//     use aptos_framework::account::{Self, SignerCapability};
//     use aptos_framework::event::{Self, EventHandle};
//     use aptos_std::simple_map::{Self, SimpleMap};

//     // Error codes
//     const E_NOT_AUTHORIZED: u64 = 1;
//     const E_ELECTION_NOT_FOUND: u64 = 2;
//     const E_ALREADY_VOTED: u64 = 3;
//     const E_INVALID_CANDIDATE: u64 = 4;
//     const E_ALREADY_INITIALIZED: u64 = 5;

//     struct Candidate has store, drop, copy {
//         name: String,
//         vote_count: u64
//     }

//     struct Election has store {
//         id: u64,
//         title: String,
//         candidates: vector<Candidate>,
//         is_active: bool
//     }

//     struct VotingSystem has key {
//         elections: SimpleMap<u64, Election>,
//         election_counter: u64,
//         admin: address,
//         signer_cap: SignerCapability,
//         election_events: EventHandle<ElectionCreatedEvent>,
//         vote_events: EventHandle<VoteCastEvent>
//     }

//     struct VoterRecord has key {
//         voted_elections: vector<u64>
//     }

//     #[event]
//     struct ElectionCreatedEvent has drop, store {
//         election_id: u64,
//         title: String
//     }

//     #[event]
//     struct VoteCastEvent has drop, store {
//         election_id: u64,
//         voter: address,
//         candidate_index: u64
//     }

//     // Initialize function for production
//     fun init_module(resource_account: &signer) {
//         initialize_internal(resource_account);
//     }

//     // Public initialize function for testing
//     public entry fun initialize(account: &signer) {
//         initialize_internal(account);
//     }

//     // Internal initialize function
//     fun initialize_internal(account: &signer) {
//         let resource_addr = get_resource_address(account);
//         assert!(!exists<VotingSystem>(resource_addr), E_ALREADY_INITIALIZED);

//         // Create resource account using deployer address as bytes
//         let seed = vector::empty<u8>();
//         let deployer_addr = signer::address_of(account);
//         let addr_bytes = address_to_bytes(deployer_addr);
//         vector::append(&mut seed, addr_bytes);

//         let (resource_signer, resource_signer_cap) = account::create_resource_account(
//             account,
//             seed
//         );

//         let voting_system = VotingSystem {
//             elections: simple_map::create<u64, Election>(),
//             election_counter: 0,
//             admin: signer::address_of(account),
//             signer_cap: resource_signer_cap,
//             election_events: account::new_event_handle<ElectionCreatedEvent>(&resource_signer),
//             vote_events: account::new_event_handle<VoteCastEvent>(&resource_signer)
//         };
//         move_to(&resource_signer, voting_system);
//     }

//     // Helper function to convert address to bytes
//     fun address_to_bytes(addr: address): vector<u8> {
//         let bytes = vector::empty();
//         let i = 0;
//         while (i < 32) {  // Address is 32 bytes
//             let byte = (addr >> ((31 - i) * 8)) & 0xFF;
//             vector::push_back(&mut bytes, (byte as u8));
//             i = i + 1;
//         };
//         bytes
//     }

//     public entry fun create_election(
//         account: &signer,
//         title: String,
//         candidate_names: vector<String>
//     ) acquires VotingSystem {
//         let addr = signer::address_of(account);
//         let resource_addr = get_resource_address(account);
//         let voting_system = borrow_global_mut<VotingSystem>(resource_addr);
        
//         assert!(addr == voting_system.admin, E_NOT_AUTHORIZED);
        
//         let candidates = vector::empty<Candidate>();
//         let i = 0;
//         while (i < vector::length(&candidate_names)) {
//             let candidate = Candidate {
//                 name: *vector::borrow(&candidate_names, i),
//                 vote_count: 0
//             };
//             vector::push_back(&mut candidates, candidate);
//             i = i + 1;
//         };

//         let election = Election {
//             id: voting_system.election_counter,
//             title,
//             candidates,
//             is_active: true
//         };

//         simple_map::add(&mut voting_system.elections, voting_system.election_counter, election);
        
//         event::emit_event(&mut voting_system.election_events, ElectionCreatedEvent {
//             election_id: voting_system.election_counter,
//             title
//         });

//         voting_system.election_counter = voting_system.election_counter + 1;
//     }

//     public entry fun cast_vote(
//         account: &signer,
//         election_id: u64,
//         candidate_index: u64
//     ) acquires VotingSystem, VoterRecord {
//         let addr = signer::address_of(account);
//         let resource_addr = get_resource_address(account);
//         let voting_system = borrow_global_mut<VotingSystem>(resource_addr);
        
//         // Ensure election exists and is active
//         assert!(simple_map::contains_key(&voting_system.elections, &election_id), E_ELECTION_NOT_FOUND);
//         let election = simple_map::borrow_mut(&mut voting_system.elections, &election_id);
//         assert!(election.is_active, E_ELECTION_NOT_FOUND);
        
//         // Check if voter has already voted
//         if (!exists<VoterRecord>(addr)) {
//             move_to(account, VoterRecord { voted_elections: vector::empty() });
//         };
        
//         let voter_record = borrow_global_mut<VoterRecord>(addr);
//         let i = 0;
//         let len = vector::length(&voter_record.voted_elections);
//         while (i < len) {
//             assert!(*vector::borrow(&voter_record.voted_elections, i) != election_id, E_ALREADY_VOTED);
//             i = i + 1;
//         };
        
//         // Ensure candidate index is valid
//         assert!(candidate_index < vector::length(&election.candidates), E_INVALID_CANDIDATE);
        
//         // Record vote
//         let candidate = vector::borrow_mut(&mut election.candidates, candidate_index);
//         candidate.vote_count = candidate.vote_count + 1;
//         vector::push_back(&mut voter_record.voted_elections, election_id);
        
//         // Emit vote event
//         event::emit_event(&mut voting_system.vote_events, VoteCastEvent {
//             election_id,
//             voter: addr,
//             candidate_index
//         });
//     }

//     public fun get_election_details(election_id: u64): (String, vector<Candidate>) acquires VotingSystem {
//         let resource_addr = get_resource_address(&@voting_addr);
//         let voting_system = borrow_global<VotingSystem>(resource_addr);
        
//         assert!(simple_map::contains_key(&voting_system.elections, &election_id), E_ELECTION_NOT_FOUND);
//         let election = simple_map::borrow(&voting_system.elections, &election_id);
        
//         (election.title, election.candidates)
//     }

//     public fun has_voted(addr: address, election_id: u64): bool acquires VoterRecord {
//         if (!exists<VoterRecord>(addr)) {
//             return false
//         };
        
//         let voter_record = borrow_global<VoterRecord>(addr);
//         let i = 0;
//         let len = vector::length(&voter_record.voted_elections);
//         while (i < len) {
//             if (*vector::borrow(&voter_record.voted_elections, i) == election_id) {
//                 return true
//             };
//             i = i + 1;
//         };
//         false
//     }

//     // Helper function to get resource account address
//     public fun get_resource_address(account: &signer): address {
//         let seed = vector::empty<u8>();
//         vector::append(&mut seed, address_to_bytes(signer::address_of(account)));
//         account::create_resource_address(&@voting_addr, seed)
//     }
// }

module voting_addr::voting_system {
    use std::string::{String};
    use std::vector;
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_std::simple_map::{Self, SimpleMap};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ELECTION_NOT_FOUND: u64 = 2;
    const E_ALREADY_VOTED: u64 = 3;
    const E_INVALID_CANDIDATE: u64 = 4;
    const E_ALREADY_INITIALIZED: u64 = 5;

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
        elections: SimpleMap<u64, Election>,
        election_counter: u64,
        admin: address,
        signer_cap: SignerCapability,
        election_events: EventHandle<ElectionCreatedEvent>,
        vote_events: EventHandle<VoteCastEvent>
    }

    struct VoterRecord has key {
        voted_elections: vector<u64>
    }

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

    // Initialize function for production
    fun init_module(resource_account: &signer) {
        initialize_internal(resource_account);
    }

    // Public initialize function for testing
    public entry fun initialize(account: &signer) {
        initialize_internal(account);
    }

    // Internal initialize function
    fun initialize_internal(account: &signer) {
        let resource_addr = get_resource_address(signer::address_of(account));
        assert!(!exists<VotingSystem>(resource_addr), E_ALREADY_INITIALIZED);

        let (resource_signer, resource_signer_cap) = account::create_resource_account(
            account,
            vector::empty<u8>() // No seed, using deployed address
        );

        let voting_system = VotingSystem {
            elections: simple_map::create<u64, Election>(),
            election_counter: 0,
            admin: signer::address_of(account),
            signer_cap: resource_signer_cap,
            election_events: account::new_event_handle<ElectionCreatedEvent>(&resource_signer),
            vote_events: account::new_event_handle<VoteCastEvent>(&resource_signer)
        };
        move_to(&resource_signer, voting_system);
    }

    public fun get_resource_address(deployer: address): address {
        account::create_resource_address(&deployer, vector::empty<u8>())
    }

    public entry fun create_election(
        account: &signer,
        title: String,
        candidate_names: vector<String>
    ) acquires VotingSystem {
        let addr = signer::address_of(account);
        let resource_addr = get_resource_address(addr);
        let voting_system = borrow_global_mut<VotingSystem>(resource_addr);
        
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

        simple_map::add(&mut voting_system.elections, voting_system.election_counter, election);
        
        event::emit_event(&mut voting_system.election_events, ElectionCreatedEvent {
            election_id: voting_system.election_counter,
            title
        });

        voting_system.election_counter = voting_system.election_counter + 1;
    }

    public entry fun cast_vote(
        account: &signer,
        election_id: u64,
        candidate_index: u64
    ) acquires VotingSystem, VoterRecord {
        let addr = signer::address_of(account);
        let resource_addr = get_resource_address(addr);
        let voting_system = borrow_global_mut<VotingSystem>(resource_addr);
        
        // Ensure election exists and is active
        assert!(simple_map::contains_key(&voting_system.elections, &election_id), E_ELECTION_NOT_FOUND);
        let election = simple_map::borrow_mut(&mut voting_system.elections, &election_id);
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
        
        // Emit vote event
        event::emit_event(&mut voting_system.vote_events, VoteCastEvent {
            election_id,
            voter: addr,
            candidate_index
        });
    }

    public fun get_election_details(election_id: u64): (String, vector<Candidate>) acquires VotingSystem {
        let resource_addr = get_resource_address(@voting_addr);
        let voting_system = borrow_global<VotingSystem>(resource_addr);
        
        assert!(simple_map::contains_key(&voting_system.elections, &election_id), E_ELECTION_NOT_FOUND);
        let election = simple_map::borrow(&voting_system.elections, &election_id);
        
        (election.title, election.candidates)
    }

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
