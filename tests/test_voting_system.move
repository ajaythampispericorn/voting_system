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

    #[test(aptos_framework = @0x1, admin = @voting_addr)]
    fun test_init_voting_system(aptos_framework: signer, admin: signer) {
        setup_test(&aptos_framework);
        account::create_account_for_test(signer::address_of(&admin));
        
        voting_system::initialize(&admin);
        
        assert!(voting_system::is_initialized(signer::address_of(&admin)), 0);
    }

    #[test(aptos_framework = @0x1, admin = @voting_addr)]
    fun test_create_election_success(aptos_framework: signer, admin: signer) {
        setup_test(&aptos_framework);
        account::create_account_for_test(signer::address_of(&admin));
        
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

    #[test(aptos_framework = @0x1, admin = @voting_addr, voter = @0x456)]
    #[expected_failure(abort_code = E_NOT_AUTHORIZED, location = voting_addr::voting_system)]
    fun test_create_election_unauthorized(aptos_framework: signer, admin: signer, voter: signer) {
        setup_test(&aptos_framework);
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&voter));
        
        voting_system::initialize(&admin);

        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        
        voting_system::create_election(
            &voter,
            string::utf8(b"Test Election"),
            candidates
        );
    }

    #[test(aptos_framework = @0x1, admin = @voting_addr, voter = @0x456)]
    fun test_cast_vote_success(aptos_framework: signer, admin: signer, voter: signer) {
        setup_test(&aptos_framework);
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&voter));
        
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

    #[test(aptos_framework = @0x1, admin = @voting_addr, voter = @0x456)]
    #[expected_failure(abort_code = E_ALREADY_VOTED, location = voting_addr::voting_system)]
    fun test_cast_vote_duplicate(aptos_framework: signer, admin: signer, voter: signer) {
        setup_test(&aptos_framework);
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&voter));
        
        voting_system::initialize(&admin);

        let candidates = vector::empty<string::String>();
        vector::push_back(&mut candidates, string::utf8(b"Candidate 1"));
        
        voting_system::create_election(
            &admin,
            string::utf8(b"Test Election"),
            candidates
        );

        voting_system::cast_vote(&voter, 0, 0);
        voting_system::cast_vote(&voter, 0, 0);
    }

    #[test(aptos_framework = @0x1, admin = @voting_addr)]
    #[expected_failure(abort_code = E_ELECTION_NOT_FOUND, location = voting_addr::voting_system)]
    fun test_get_nonexistent_election(aptos_framework: signer, admin: signer) {
        setup_test(&aptos_framework);
        account::create_account_for_test(signer::address_of(&admin));
        
        voting_system::initialize(&admin);
        voting_system::get_election_details(99);
    }

    #[test(aptos_framework = @0x1, admin = @voting_addr, voter1 = @0x456, voter2 = @0x789)]
    fun test_multiple_elections_and_votes(
        aptos_framework: signer,
        admin: signer,
        voter1: signer,
        voter2: signer
    ) {
        setup_test(&aptos_framework);
        account::create_account_for_test(signer::address_of(&admin));
        account::create_account_for_test(signer::address_of(&voter1));
        account::create_account_for_test(signer::address_of(&voter2));
        
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

        // Verify vote counts
        let (_, candidates1) = voting_system::get_election_details(0);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates1, 0)) == 1, 4);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates1, 1)) == 1, 5);

        let (_, candidates2) = voting_system::get_election_details(1);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates2, 0)) == 1, 6);
        assert!(voting_system::get_candidate_vote_count(vector::borrow(&candidates2, 1)) == 1, 7);
    }
}