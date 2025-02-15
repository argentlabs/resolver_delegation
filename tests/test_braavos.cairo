%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.braavos import domain_to_address, claim_name, transfer_name, _get_amount_of_chars, open_registration, close_registration, _is_registration_open
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.uint256 import Uint256
from src.interface.braavos_resolver import IBraavosResolver


@external
func __setup__() {
    //Should deploy contract and open registration 
    %{ 
        from starkware.starknet.compiler.compile import get_selector_from_name

        logic_contract_class_hash = declare("./src/braavos.cairo").class_hash
        context.braavos_resolver_contract = deploy_contract("./lib/cairo_contracts/src/openzeppelin/upgrades/presets/Proxy.cairo", [logic_contract_class_hash,
            get_selector_from_name("initializer"), 1,
            123]).contract_address 
    %}
    return ();
}

@external
func test_claim_name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local braavos_resolver_contract;
    %{ 
        ids.braavos_resolver_contract = context.braavos_resolver_contract
        stop_prank_callable = start_prank(123, context.braavos_resolver_contract) 
        stop_mock = mock_call(123, "get_implementation", [456])
        stop_mock = mock_call(456, "get_implementation", [456])
    %}
    IBraavosResolver.open_registration(braavos_resolver_contract); 
    IBraavosResolver.set_wl_class_hash(braavos_resolver_contract, 456); 

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    let (prev_owner) = IBraavosResolver.domain_to_address(braavos_resolver_contract, 1, new (1426911989));
    assert prev_owner = 0;

    IBraavosResolver.claim_name(braavos_resolver_contract, 1426911989); 

    let (owner) = IBraavosResolver.domain_to_address(braavos_resolver_contract, 1, new (1426911989));
    assert owner = 123;

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    IBraavosResolver.transfer_name(braavos_resolver_contract, 1426911989, 456);
    %{ stop_prank_callable() %}
    let (owner) = IBraavosResolver.domain_to_address(braavos_resolver_contract, 1, new (1426911989));
    assert owner = 456;

    return ();
}

@external
func test_claim_not_allowed_name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local braavos_resolver_contract;
    %{ 
        ids.braavos_resolver_contract = context.braavos_resolver_contract
        stop_prank_callable = start_prank(123, context.braavos_resolver_contract) 
        stop_mock = mock_call(123, "get_implementation", [456])
    %}
    IBraavosResolver.open_registration(braavos_resolver_contract); 
    IBraavosResolver.set_wl_class_hash(braavos_resolver_contract, 456); 

    // Should revert because of names are less than 4 chars (with the encoded domain "ben").
    %{ 
        expect_revert(error_message="You can not register a Braavos name with less than 4 characters.") 
    %}
    IBraavosResolver.claim_name(braavos_resolver_contract, 18925);

    return ();
}

@external
func test_claim_taken_name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local braavos_resolver_contract;
    %{ 
        ids.braavos_resolver_contract = context.braavos_resolver_contract
        stop_prank_callable = start_prank(123, context.braavos_resolver_contract) 
        stop_mock = mock_call(123, "get_implementation", [456])
    %}
    IBraavosResolver.open_registration(braavos_resolver_contract); 
    IBraavosResolver.set_wl_class_hash(braavos_resolver_contract, 456); 

    // Should revert because the name is taken (with the encoded domain "thomas").
    IBraavosResolver.claim_name(braavos_resolver_contract, 1426911989);
    %{ 
        stop_prank_callable()
        stop_prank_callable = start_prank(789, context.braavos_resolver_contract) 
        stop_mock = mock_call(789, "get_implementation", [456])
        expect_revert(error_message="This Braavos name is taken.") 
     %}
    IBraavosResolver.claim_name(braavos_resolver_contract, 1426911989);

    return ();
}

@external
func test_claim_two_names{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local braavos_resolver_contract;
    %{ 
        ids.braavos_resolver_contract = context.braavos_resolver_contract
        stop_prank_callable = start_prank(123, context.braavos_resolver_contract) 
        stop_mock = mock_call(123, "get_implementation", [456])
    %}
    IBraavosResolver.open_registration(braavos_resolver_contract); 
    IBraavosResolver.set_wl_class_hash(braavos_resolver_contract, 456); 

    // Should revert because the name is taken (with the encoded domain "thomas" and "motty").
    IBraavosResolver.claim_name(braavos_resolver_contract, 1426911989);
    %{ 
        expect_revert(error_message="You already registered a Braavos name.") 
     %}
    IBraavosResolver.claim_name(braavos_resolver_contract, 51113812);


    return ();
}

@external
func test_open_registration{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local braavos_resolver_contract;
    %{ 
        ids.braavos_resolver_contract = context.braavos_resolver_contract
        stop_prank_callable = start_prank(123, context.braavos_resolver_contract) 
        stop_mock = mock_call(123, "get_implementation", [456])
    %}
    IBraavosResolver.set_wl_class_hash(braavos_resolver_contract, 456); 

    // Should revert because the registration is closed (with the encoded domain "thomas").
    %{ 
        expect_revert(error_message="The registration is closed.") 
     %}
    IBraavosResolver.claim_name(braavos_resolver_contract, 1426911989);

    return ();
}

@external
func test_implementation_class_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local braavos_resolver_contract;
    %{ 
        ids.braavos_resolver_contract = context.braavos_resolver_contract
        stop_prank_callable = start_prank(123, context.braavos_resolver_contract) 
        stop_mock = mock_call(123, "get_implementation", [456])
    %}
    IBraavosResolver.open_registration(braavos_resolver_contract); 

    // Should revert because the implementation class hash is not set
    %{ 
        expect_revert(error_message="Your wallet is not a Braavos wallet, change your wallet to a Braavos wallet.") 
     %}
    IBraavosResolver.claim_name(braavos_resolver_contract, 1426911989); 

    // Should revert because the implementation class hash of the receiver is not whitelisted
    IBraavosResolver.set_wl_class_hash(braavos_resolver_contract, 456); 
    IBraavosResolver.claim_name(braavos_resolver_contract, 1426911989); 
    %{ 
        expect_revert(error_message="The receiver wallet is not a Braavos wallet, change it to a Braavos wallet.") 
     %}
    IBraavosResolver.transfer_name(braavos_resolver_contract, 1426911989, 'argent-x');


    return ();
}


@external
func test_get_amount_of_chars{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // Should return 0 (empty string)
    let chars_amount = _get_amount_of_chars(Uint256(0, 0));
    assert chars_amount = 0;

    // Should return 4 ("toto")
    let chars_amount = _get_amount_of_chars(Uint256(796195, 0));
    assert chars_amount = 4;

    // Should return 5 ("aloha")
    let chars_amount = _get_amount_of_chars(Uint256(77554770, 0));
    assert chars_amount = 5;

    // Should return 9 ("chocolate")
    let chars_amount = _get_amount_of_chars(Uint256(19565965532212, 0));
    assert chars_amount = 9;

    // Should return 30 ("这来abcdefghijklmopqrstuvwyq1234")
    let (high, low) = split_felt(801855144733576077820330221438165587969903898313);
    let chars_amount = _get_amount_of_chars(Uint256(low, high));
    assert chars_amount = 30;

    return ();
}