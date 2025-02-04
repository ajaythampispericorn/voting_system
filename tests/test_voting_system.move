#[test_only]
module voting_addr::voting_system_tests {
    use std::string;
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use voting_addr::voting_system::{
        Self, 
        VotingSystem, 
        VoterRecord, 
        Candidate
    };

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
        voting_system::get_resource_address(signer::address_of(signer))
    }

    #[test]
    fun test_init_voting_system(admin: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);
        
        let resource_addr = get_resource_address(&admin);
        assert!(voting_system::is_initialized(signer::address_of(&admin)), 0);
    }

    #[test]
    fun test_create_election_success(admin: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        vector::push_back(&mut candidates, string::utf8(b"Candidate 2"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

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

        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        vector::push_back(&mut candidates, string::utf8(b"Candidate 2"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

        voting_system::cast_vote(&voter, 0, 1);

        assert!(voting_system::has_voted(signer::address_of(&voter), 0), 0);

        let (_, candidates) = voting_system::get_election_details(0);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates, 1)) == 1, 1);
    }

    #[test]
    #[expected_failure(abort_code = E_ALREADY_VOTED)]
    fun test_cast_vote_duplicate(admin: signer, voter: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

        voting_system::cast_vote(&voter, 0, 0);
        voting_system::cast_vote(&voter, 0, 0); // Should fail
    }

    #[test]
    #[expected_failure(abort_code = E_INVALID_CANDIDATE)]
    fun test_cast_vote_invalid_candidate(admin: signer, voter: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

        voting_system::cast_vote(&voter, 0, 99); // Invalid candidate index
    }

    #[test]
    #[expected_failure(abort_code = E_ELECTION_NOT_FOUND)]
    fun test_get_nonexistent_election(admin: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        voting_system::get_election_details(99); // Non-existent election
    }

    #[test]
    fun test_multiple_elections_and_votes(admin: signer, voter1: signer, voter2: signer) {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        setup_test(&aptos_framework);
        
        voting_system::initialize(&admin);

        let candidates1 = vector::empty<string::String>();
        vector::push_back(&mut candidates1, string::utf8(b"Candidate 1"));
        vector::push_back(&mut candidates1, string::utf8(b"Candidate 2"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Election 1"),
            candidates1
        );

        let candidates2 = vector::empty<string::String>();
        vector::push_back(&mut candidates2, string::utf8(b"Candidate A"));
        vector::push_back(&mut candidates2, string::utf8(b"Candidate B"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Election 2"),
            candidates2
        );

        voting_system::cast_vote(&voter1, 0, 0);
        voting_system::cast_vote(&voter2, 0, 1);
        voting_system::cast_vote(&voter1, 1, 1);
        voting_system::cast_vote(&voter2, 1, 0);

        assert!(voting_system::has_voted(signer::address_of(&voter1), 0), 0);
        assert!(voting_system::has_voted(signer::address_of(&voter1), 1), 1);
        assert!(voting_system::has_voted(signer::address_of(&voter2), 0), 2);
        assert!(voting_system::has_voted(signer::address_of(&voter2), 1), 3);

        let (_, candidates1) = voting_system::get_election_details(0);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates1, 0)) == 1, 4);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates1, 1)) == 1, 5);

        let (_, candidates2) = voting_system::get_election_details(1);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates2, 0)) == 1, 6);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates2, 1)) == 1, 7);
    }
}