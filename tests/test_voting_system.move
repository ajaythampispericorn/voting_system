#[test_only]
module voting_addr::voting_system_tests {
    use std::string;
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use voting_addr::voting_system::{Self, VotingSystem, VoterRecord};

    // Test addresses
    const ADMIN: address = @voting_addr;  // Changed to match the module address
    const VOTER1: address = @0x123;
    const VOTER2: address = @0x456;

    // Error codes from the main module
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ELECTION_NOT_FOUND: u64 = 2;
    const E_ALREADY_VOTED: u64 = 3;
    const E_INVALID_CANDIDATE: u64 = 4;
    const E_ALREADY_INITIALIZED: u64 = 5;

    // Helper function to set up test environment
    fun setup_test(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
    }

    // Helper function to create test accounts
    fun create_test_accounts(): (signer, signer, signer) {
        let admin = account::create_account_for_test(ADMIN);
        let voter1 = account::create_account_for_test(VOTER1);
        let voter2 = account::create_account_for_test(VOTER2);
        (admin, voter1, voter2)
    }

    #[test]
    fun test_init_voting_system() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        let (admin, _voter1, _voter2) = create_test_accounts();
        voting_system::initialize(&admin);

        let resource_addr = voting_system::get_resource_address();
        assert!(exists<VotingSystem>(resource_addr), 0);
    }

    #[test]
    fun test_create_election_success() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        let (admin, _voter1, _voter2) = create_test_accounts();
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
    fun test_create_election_unauthorized() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        let (admin, voter1, _voter2) = create_test_accounts();
        voting_system::initialize(&admin);

        // Try to create election with non-admin account
        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        
        voting_system::create_election(
            &voter1,
            string::utf8(b"Test Election"),
            candidates
        );
    }

    #[test]
    fun test_cast_vote_success() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        let (admin, voter1, _voter2) = create_test_accounts();
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
        voting_system::cast_vote(&voter1, 0, 1);

        // Verify vote was recorded
        assert!(voting_system::has_voted(signer::address_of(&voter1), 0), 0);
    }

    #[test]
    #[expected_failure(abort_code = E_ALREADY_VOTED)]
    fun test_cast_vote_duplicate() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        let (admin, voter1, _voter2) = create_test_accounts();
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
        voting_system::cast_vote(&voter1, 0, 0);
        voting_system::cast_vote(&voter1, 0, 0); // Should fail
    }

    #[test]
    #[expected_failure(abort_code = E_INVALID_CANDIDATE)]
    fun test_cast_vote_invalid_candidate() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        let (admin, voter1, _voter2) = create_test_accounts();
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
        voting_system::cast_vote(&voter1, 0, 99);
    }

    #[test]
    #[expected_failure(abort_code = E_ELECTION_NOT_FOUND)]
    fun test_get_nonexistent_election() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        let (admin, _voter1, _voter2) = create_test_accounts();
        voting_system::initialize(&admin);

        // Try to get details of non-existent election
        voting_system::get_election_details(99);
    }

    #[test]
    fun test_multiple_elections_and_votes() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        let (admin, voter1, voter2) = create_test_accounts();
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
    }
}