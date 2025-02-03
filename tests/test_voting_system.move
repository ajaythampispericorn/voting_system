#[test_only]
module voting_addr::voting_system_tests {
    use std::string;
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use voting_addr::voting_system::{Self, VotingSystem, VoterRecord};

    // Error codes from the main module
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ELECTION_NOT_FOUND: u64 = 2;
    const E_ALREADY_VOTED: u64 = 3;
    const E_INVALID_CANDIDATE: u64 = 4;
    const E_ALREADY_INITIALIZED: u64 = 5;

    #[test_only]
    fun setup_test(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
    }

    #[test_only]
    fun get_resource_address(signer: &signer): address {
        voting_system::get_resource_address(signer)
    }

    #[test]
    fun test_init_voting_system(admin: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);
        
        let resource_addr = get_resource_address(&admin);
        assert!(exists<VotingSystem>(resource_addr), 0);
    }

    #[test]
    fun test_create_election_success(admin: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        // Create election
        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        vector::push_back(&mut candidates, string::utf8(b"Candidate 2"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

        // Verify election details
        let (title, candidates) = voting_system::get_election_details(0);
        assert!(title == string::utf8(b"Test Election"), 0);
        assert!(vector::length(&candidates) == 2, 1);
    }

    #[test]
    #[expected_failure(abort_code = E_NOT_AUTHORIZED)]
    fun test_create_election_unauthorized(admin: signer, voter: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        // Try to create election with non-admin account
        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        
        voting_system::create_election(
            &voter,
            string::utf8(b"Test Election"),
            candidates
        );
    }

    #[test]
    fun test_cast_vote_success(admin: signer, voter: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        // Create election
        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        vector::push_back(&mut candidates, string::utf8(b"Candidate 2"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

        // Cast vote
        voting_system::cast_vote(&voter, 0, 1);

        // Verify vote was recorded
        assert!(voting_system::has_voted(signer::address_of(&voter), 0), 0);

        // Verify vote count
        let (_, candidates) = voting_system::get_election_details(0);
        assert!(vector::borrow(&candidates, 1).vote_count == 1, 1);
    }

    #[test]
    #[expected_failure(abort_code = E_ALREADY_VOTED)]
    fun test_cast_vote_duplicate(admin: signer, voter: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        // Create election
        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

        // Cast vote twice
        voting_system::cast_vote(&voter, 0, 0);
        voting_system::cast_vote(&voter, 0, 0); // Should fail
    }

    #[test]
    #[expected_failure(abort_code = E_INVALID_CANDIDATE)]
    fun test_cast_vote_invalid_candidate(admin: signer, voter: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        // Create election
        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

        // Try to vote for non-existent candidate
        voting_system::cast_vote(&voter, 0, 99);
    }

    #[test]
    #[expected_failure(abort_code = E_ELECTION_NOT_FOUND)]
    fun test_get_nonexistent_election(admin: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        // Try to get details of non-existent election
        voting_system::get_election_details(99);
    }

    #[test]
    fun test_multiple_elections_and_votes(admin: signer, voter1: signer, voter2: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        // Create first election
        let candidates1 = vector::empty<string::String>();
        vector::push_back(&mut candidates1, string::utf8(b"Candidate 1"));
        vector::push_back(&mut candidates1, string::utf8(b"Candidate 2"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Election 1"),
            candidates1
        );

        // Create second election
        let candidates2 = vector::empty<string::String>();
        vector::push_back(&mut candidates2, string::utf8(b"Candidate A"));
        vector::push_back(&mut candidates2, string::utf8(b"Candidate B"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Election 2"),
            candidates2
        );

        // Cast votes
        voting_system::cast_vote(&voter1, 0, 0);
        voting_system::cast_vote(&voter2, 0, 1);
        voting_system::cast_vote(&voter1, 1, 1);
        voting_system::cast_vote(&voter2, 1, 0);

        // Verify votes
        assert!(voting_system::has_voted(signer::address_of(&voter1), 0), 0);
        assert!(voting_system::has_voted(signer::address_of(&voter1), 1), 1);
        assert!(voting_system::has_voted(signer::address_of(&voter2), 0), 2);
        assert!(voting_system::has_voted(signer::address_of(&voter2), 1), 3);

        // Verify vote counts for first election
        let (_, candidates1) = voting_system::get_election_details(0);
        assert!(vector::borrow(&candidates1, 0).vote_count == 1, 4);
        assert!(vector::borrow(&candidates1, 1).vote_count == 1, 5);

        // Verify vote counts for second election
        let (_, candidates2) = voting_system::get_election_details(1);
        assert!(vector::borrow(&candidates2, 0).vote_count == 1, 6);
        assert!(vector::borrow(&candidates2, 1).vote_count == 1, 7);
    }
}