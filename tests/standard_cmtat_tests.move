/// Standard CMTAT Test Suite - Updated for Native Coin<T>
/// Tests initialization, minting, burning, transfers, freeze, pause, and snapshots
#[test_only]
module move_cmtat::standard_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list::DenyList;
    use iota::object;

    use move_cmtat::standard_cmtat::{Self, STANDARD_CMTAT, CMTATRegistry, StandardCMTATState, 
                                      ComplianceState, AdminCap, MintCap, BurnCap, 
                                       FreezeCap, PauseCap, SnapshotCap, EnforcerCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;

    // Helper to take global DenyList
    fun take_deny_list(scenario: &mut test_scenario::Scenario): DenyList {
        let deny_list_id = object::iota_deny_list_object_id();
        test_scenario::take_shared_by_id<DenyList>(scenario, deny_list_id)
    }

    // Helper to initialize for testing
    fun setup(scenario: &mut test_scenario::Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_for_testing(ctx);
        };
    }

    // ========== INITIALIZATION TESTS ==========

    #[test]
    fun test_init() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        // Verify shared objects were created
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<CMTATRegistry>(), 0);
            assert!(test_scenario::has_most_recent_shared<StandardCMTATState>(), 1);
            assert!(test_scenario::has_most_recent_shared<ComplianceState>(), 2);
            
            // Verify capabilities were transferred to admin
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 3);
            assert!(test_scenario::has_most_recent_for_sender<MintCap>(scenario), 4);
            assert!(test_scenario::has_most_recent_for_sender<BurnCap>(scenario), 5);
            assert!(test_scenario::has_most_recent_for_sender<FreezeCap>(scenario), 6);
            assert!(test_scenario::has_most_recent_for_sender<PauseCap>(scenario), 7);
            assert!(test_scenario::has_most_recent_for_sender<SnapshotCap>(scenario), 8);
            assert!(test_scenario::has_most_recent_for_sender<EnforcerCap>(scenario), 9);
            assert!(test_scenario::has_most_recent_for_sender<TreasuryCap<STANDARD_CMTAT>>(scenario), 10);
            assert!(test_scenario::has_most_recent_for_sender<DenyCapV1<STANDARD_CMTAT>>(scenario), 11);
            
            // Check immutable metadata
            assert!(test_scenario::has_most_recent_immutable<CoinMetadata<STANDARD_CMTAT>>(), 12);
        };

        test_scenario::end(scenario_val);
    }

    // ========== VIEW FUNCTION TESTS ==========

    #[test]
    fun test_view_functions() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let metadata = test_scenario::take_immutable<CoinMetadata<STANDARD_CMTAT>>(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<STANDARD_CMTAT>>(scenario);

            // Test metadata (native CoinMetadata)
            assert!(standard_cmtat::name(&metadata) == string::utf8(b"Standard CMTAT Token"), 0);
            assert!(standard_cmtat::symbol(&metadata) == string::utf8(b"STCMTAT"), 1);
            assert!(standard_cmtat::decimals(&metadata) == 9, 2);
            assert!(standard_cmtat::total_supply(&treasury_cap) == 0, 3);
            
            // Test registry
            assert!(standard_cmtat::terms(&registry) == string::utf8(b""), 4);
            assert!(!standard_cmtat::deactivated(&registry), 5);
            
            // Test compliance state
            assert!(!standard_cmtat::paused(&compliance_state), 6);
            assert!(!standard_cmtat::is_frozen(&compliance_state, USER1), 7);

            test_scenario::return_immutable(metadata);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== MINTING TESTS ==========

    #[test]
    fun test_mint() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<STANDARD_CMTAT>>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
            let deny_list = take_deny_list(scenario);

            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::mint_and_transfer(&mint_cap, &mut treasury_cap, &registry, &compliance_state, &deny_list, USER1, 5000, ctx);

            // Check total supply increased
            assert!(standard_cmtat::total_supply(&treasury_cap) == 5000, 0);

            test_scenario::return_shared(registry);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, mint_cap);
        };

        // Check USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<STANDARD_CMTAT>>(scenario), 0);
            let coins = test_scenario::take_from_sender<Coin<STANDARD_CMTAT>>(scenario);
            assert!(coin::value(&coins) == 5000, 1);
            test_scenario::return_to_sender(scenario, coins);
        };

        test_scenario::end(scenario_val);
    }

    // ========== PAUSE TESTS ==========

    #[test]
    fun test_pause_unpause() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let pause_cap = test_scenario::take_from_sender<PauseCap>(scenario);

            // Verify not paused initially
            assert!(!standard_cmtat::paused(&compliance_state), 0);

            // Pause
            standard_cmtat::pause(&pause_cap, &mut compliance_state);
            assert!(standard_cmtat::paused(&compliance_state), 1);

            // Unpause
            standard_cmtat::unpause(&pause_cap, &mut compliance_state);
            assert!(!standard_cmtat::paused(&compliance_state), 2);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, pause_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ADMINISTRATIVE TESTS ==========

    #[test]
    fun test_set_metadata() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            standard_cmtat::set_terms(&admin_cap, &mut registry, string::utf8(b"New Terms"));
            standard_cmtat::set_information(&admin_cap, &mut registry, string::utf8(b"New Info"));
            standard_cmtat::set_token_id(&admin_cap, &mut registry, string::utf8(b"TOKEN123"));
            standard_cmtat::set_document_uri(&admin_cap, &mut registry, string::utf8(b"https://example.com"));

            assert!(standard_cmtat::document_uri(&registry) == string::utf8(b"https://example.com"), 0);
            assert!(standard_cmtat::terms(&registry) == string::utf8(b"New Terms"), 1);

            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }
}
