%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_number,
    get_block_timestamp,
)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import (
    assert_not_zero,
    assert_not_equal,
    assert_nn_le,
    split_felt,
    assert_lt_felt,
    assert_le_felt,
    assert_le,
    unsigned_div_rem,
    signed_div_rem,
)
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_le, uint256_lt, assert_uint256_le, uint256_mul, uint256_add
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn, is_in_range, is_nn_le
from contracts.openzeppelin.token.ERC20.interfaces.IERC20 import IERC20
from contracts.openzeppelin.access.ownable import Ownable
from contracts.Libraries.DolvenMerkleVerifier import DolvenMerkleVerifier
from contracts.openzeppelin.security.pausable import Pausable
from contracts.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from contracts.Libraries.DolvenApprover import DolvenApprover
from contracts.openzeppelin.token.erc721.enumerable.library import ERC721Enumerable
from contracts.openzeppelin.token.erc721.library import ERC721
from contracts.openzeppelin.introspection.erc165.library import ERC165
from contracts.NFT.starkGuardiansMetadata import (
    ERC721_Metadata_initializer,
    ERC721_Metadata_tokenURI,
    ERC721_Metadata_setBaseTokenURI,
)
from contracts.NFT.utils.array_sort import ArraySorting

struct UserVotes {
    index : felt,
    isVoted : felt,
    voteTime : felt,
    depositedEth : felt,
    user_mint_alloc : felt,
    minted_token_count : felt,
}

struct Price {
    vote_count : felt,
    cost : felt,
}

@storage_var
func mint_limit_for_whitelist() -> (res: felt) {
}

@storage_var
func supply_limit() -> (res: felt) {
}

@storage_var
func merkle_root() -> (res: felt) {
}
// 0 => mint status
// 1 => vote status
// 2 => refund status
// 3 => cancel vote status
@storage_var
func case_status(index : felt) -> (res: felt) {
}

@storage_var
func payment_methods() -> (index: felt) {
}

@storage_var
func user_vote(user_address : felt) -> (index: UserVotes) {
}
// 0 => default
@storage_var
func mint_per_wallet(index : felt) -> (res: felt) {
}

@storage_var
func price_options(index : felt) -> (res: Price) {
}

@storage_var
func price_options_size() -> (res: felt) {
}

@storage_var
func total_deposited_eth() -> (res: felt) {
}


@storage_var
func stable_price_index() -> (res: felt) {
}


@event
func new_minting_event(owner : felt, token_id : Uint256) {
}

@event
func voting_event(vote_from : felt, vote_amount : felt,  vote_option : felt) {
}

@event
func refund_event(refund_from : felt, refund_amount : felt) {
}


@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    name: felt, symbol : felt, mintLimit : felt, _supply_limit : felt, manager : felt, _payment_method : felt, _merkle_root : felt, prices_len : felt, prices: felt*, mintLimitForClass_len : felt, mintLimitForClass : felt*
) {
    Ownable.initializer(manager);
    ERC721.initializer(name, symbol);
    ERC721Enumerable.initializer();
    ERC721_Metadata_initializer();
    mint_limit_for_whitelist.write(mintLimit);
    payment_methods.write(_payment_method);
    supply_limit.write(_supply_limit);
    case_status.write(1, TRUE);
    case_status.write(3, TRUE);
    merkle_root.write(_merkle_root);
    price_options_size.write(prices_len);
    recursiveSetPrices(prices, prices_len, 0);
    recursiveSetLimits(mintLimitForClass, mintLimitForClass_len, 0);

    return();
}

// viewers


@view
func totalSupply{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (totalSupply: Uint256) = ERC721Enumerable.total_supply();
    return (totalSupply,);
}

@view
func tokenByIndex{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    index: Uint256
) -> (tokenId: Uint256) {
    let (tokenId: Uint256) = ERC721Enumerable.token_by_index(index);
    return (tokenId,);
}

@view
func tokenOfOwnerByIndex{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    owner: felt, index: Uint256
) -> (tokenId: Uint256) {
    let (tokenId: Uint256) = ERC721Enumerable.token_of_owner_by_index(owner, index);
    return (tokenId,);
}

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    let (success) = ERC165.supports_interface(interfaceId);
    return (success,);
}

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    let (name) = ERC721.name();
    return (name,);
}

@view
func payment_method{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (method: felt) {
    let (method) = payment_methods.read();
    return (method,);
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    let (symbol) = ERC721.symbol();
    return (symbol,);
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) -> (
    balance: Uint256
) {
    let (balance: Uint256) = ERC721.balance_of(owner);
    return (balance,);
}

@view
func returnUserVote{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    user_address : felt
) -> (userVote : UserVotes) {
    let (_vote) = user_vote.read(user_address);
    return (_vote,);
}

@view
func ownerOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: Uint256) -> (
    owner: felt
) {
    let (owner: felt) = ERC721.owner_of(tokenId);
    return (owner,);
}

@view
func getApproved{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenId: Uint256
) -> (approved: felt) {
    let (approved: felt) = ERC721.get_approved(tokenId);
    return (approved,);
}

@view
func isApprovedForAll{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, operator: felt
) -> (isApproved: felt) {
    let (isApproved: felt) = ERC721.is_approved_for_all(owner, operator);
    return (isApproved,);
}


@view
func tokenURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: Uint256
) -> (token_uri_len: felt, token_uri: felt*) {
    let (token_uri_len, token_uri) = ERC721_Metadata_tokenURI(token_id);
    return (token_uri_len=token_uri_len, token_uri=token_uri);
}


@view
func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    let (owner: felt) = Ownable.owner();
    return (owner,);
}


@view
func returnAllTokensOfUser{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt
) -> (tokens_len : felt, tokens : felt*) {
    alloc_locals;
    let (user_balance : Uint256) = balanceOf(user_address);
    let balance_as_felt : felt = uint256_to_felt(user_balance);
    let (tokens_len : felt, tokens : felt*) = recursive_tokens(user_address, 0, balance_as_felt);
    return(tokens_len, tokens - tokens_len);
}

func recursive_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address : felt, index : felt, loop_size : felt
) -> (tokens_len : felt, tokens : felt*){
    alloc_locals;
   

    if(loop_size == index){
        let (found_tokens: felt*) = alloc();
        return (0, found_tokens,);
    }
    
    let uint_index : Uint256 = felt_to_uint256(index);
    let (userToken : Uint256) = tokenOfOwnerByIndex(user_address, uint_index);
    let felt_token_id : felt = uint256_to_felt(userToken); 

    let (tokens_len, token_location: felt*) = recursive_tokens(user_address, index + 1, loop_size);
    assert [token_location] = felt_token_id;
    return (tokens_len + 1, token_location + 1,);
}


@view
func return_mint_limit_for_whitelist{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
) -> (res : felt) {
    let res : felt = mint_limit_for_whitelist.read();
    return(res,);
}

@view
func return_mint_per_wallet{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
class : felt) -> (res : felt) {
    let (res) = mint_per_wallet.read(class);
    return(res,);
}

@view
func return_prices{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
index : felt) -> (res : Price) {
    let (res) = price_options.read(index);
    return(res,);
}

@view
func return_root{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt) {
    let (res) = merkle_root.read();
    return(res,);
}

@view
func return_supply_limit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt) {
    let (res) = supply_limit.read();
    return(res,);
}

@view
func returnDepositedAmount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt) {
    let (res) = total_deposited_eth.read();
    return(res,);
}

@view
func isWhitelisted{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user_address : felt, user_class : felt, user_proof_len: felt,  user_proof : felt*
) -> (res : felt) {
    alloc_locals;
    let _merkle_root : felt = merkle_root.read();
    let (leaf) = hash_user_data(user_address, user_class);
    let isVerified : felt = DolvenMerkleVerifier.verify(leaf, _merkle_root, user_proof_len, user_proof);
    return (isVerified,);
}

@view
func returnCases{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    index : felt
) -> (res : felt) {
    let status : felt = case_status.read(index);
    return (status,);
}

@view
func _isPaused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let (status) = Pausable.is_paused();
    return (status,);
}



@view
func returnSalePrice_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res_index: felt, cost : felt) {
    let price_index : felt = stable_price_index.read();
    let _price_cost : Price = price_options.read(price_index);
    return (price_index, _price_cost.cost,);
}

@view
func sort_votings{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    alloc_locals;

    let size : felt = price_options_size.read();
    let (sorted_add_len, sorted_add) = ArraySorting.get_new_array();

    let (vote_array_len, vote_array) = get_prices_array_recursive(0, size);

    let (sortedArray_len, sortedArray) = ArraySorting.sort_recursive(vote_array_len, vote_array - vote_array_len, sorted_add_len, sorted_add);
    return (sortedArray[0],);
}

func get_prices_array_recursive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index : felt, size : felt
) -> (votes_len : felt, votes : felt*) {
    alloc_locals;
    let (price_detail) = price_options.read(index);

    if(index == size){
        let (listed_votes : felt*) = alloc();
        return(0, listed_votes);
    }

    let (votes_len, votes : felt*) = get_prices_array_recursive(index + 1, size);
    assert [votes] = price_detail.vote_count;
    return(votes_len + 1, votes + 1);

}

// externals

@external
func mintForTeam{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    mint_amount : felt, 
) {
    Ownable.assert_only_owner();
    let (msg_sender) = get_caller_address();
    recursive_mint(mint_amount, 0, msg_sender);
    return();
}

@external
func setMerkleRoot{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    root : felt
) {
    Ownable.assert_only_owner();
    merkle_root.write(root);
    return();
}

@external
func switchContract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) {
    Ownable.assert_only_owner();
    let _isContractPaused : felt = _isPaused();
    if(_isContractPaused == TRUE){
        Pausable._pause();
        return();
    }else{
        Pausable._unpause();
        return();
    }
}



@external
func setPriceOptions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index : felt, price : felt
) {
    Ownable.assert_only_owner();
    let oldPrice : Price = price_options.read(index);
    let newPriceOption : Price = Price(
        vote_count=oldPrice.vote_count,
        cost=price
    );
    price_options.write(index, newPriceOption);
    return();
}


@external
func approve{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    to: felt, tokenId: Uint256
) {
    ERC721.approve(to, tokenId);
    return ();
}

@external
func setApprovalForAll{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    operator: felt, approved: felt
) {
    ERC721.set_approval_for_all(operator, approved);
    return ();
}

@external
func transferFrom{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    from_: felt, to: felt, tokenId: Uint256
) {
    ERC721Enumerable.transfer_from(from_, to, tokenId);
    return ();
}

@external
func safeTransferFrom{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    from_: felt, to: felt, tokenId: Uint256, data_len: felt, data: felt*
) {
    ERC721Enumerable.safe_transfer_from(from_, to, tokenId, data_len, data);
    return ();
}


@external
func refund{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    ReentrancyGuard._start();
    let (caller_address) = get_caller_address();
    let (this) = get_contract_address();
    let _supply_limit : felt = return_supply_limit();
    let current_supply : Uint256 = totalSupply();
    let _current_supply_as_felt : felt = uint256_to_felt(current_supply);
    let is_soldout : felt = is_le(_supply_limit, _current_supply_as_felt);
    let _status : felt = case_status.read(2);
    with_attr error_message("StarkGuardians::refunds are not available") {
        assert _status = TRUE;
    }
    let user_vote_data : UserVotes = returnUserVote(caller_address); 
   
    soldOutCheck(is_soldout, user_vote_data.index);
    
    with_attr error_message("StarkGuardians::not voted") {
        assert user_vote_data.isVoted = TRUE;
    }
    let has_deposited_eth : felt = is_le(1, user_vote_data.depositedEth);
    with_attr error_message("StarkGuardians::user is not eligible for refund") {
        assert has_deposited_eth = TRUE;
    }
    let payment_method : felt = payment_methods.read();

    let userNewData : UserVotes = UserVotes(
        index=user_vote_data.index,
        isVoted=user_vote_data.isVoted,
        voteTime=user_vote_data.voteTime,
        depositedEth=0,
        user_mint_alloc=0,
        minted_token_count=user_vote_data.minted_token_count
    );
    user_vote.write(caller_address, userNewData);

    let old_deposited : felt = returnDepositedAmount();
    total_deposited_eth.write(old_deposited - user_vote_data.depositedEth);
    refund_event.emit(caller_address, user_vote_data.depositedEth);
    let deposited_eth_uint : Uint256 = felt_to_uint256(user_vote_data.depositedEth);
    let (success) = IERC20.transfer(payment_method, caller_address, deposited_eth_uint);
    with_attr error_message("StarkGuardians::payment failed") {
        assert success = TRUE;
    }
    ReentrancyGuard._end();
    return();
}


@external
func cancelVote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    ReentrancyGuard._start();
    let (caller_address) = get_caller_address();
    let (this) = get_contract_address();
    
    let _status : felt = case_status.read(3);
    with_attr error_message("StarkGuardians::cancelling vote is not available") {
        assert _status = TRUE;
    }
    
    let user_vote_data : UserVotes = returnUserVote(caller_address); 
    with_attr error_message("StarkGuardians::not voted") {
        assert user_vote_data.isVoted = TRUE;
    }

    let payment_method : felt = payment_methods.read();

    let userNewData : UserVotes = UserVotes(
        index=0,
        isVoted=FALSE,
        voteTime=0,
        depositedEth=0,
        user_mint_alloc=0,
        minted_token_count=user_vote_data.minted_token_count,
    );
    user_vote.write(caller_address, userNewData);

    let old_deposited : felt = returnDepositedAmount();
    total_deposited_eth.write(old_deposited - user_vote_data.depositedEth);
   
    let price_data : Price = price_options.read(user_vote_data.index);
    let new_price_data : Price = Price(
        vote_count=price_data.vote_count - user_vote_data.user_mint_alloc,
        cost=price_data.cost
    );
    price_options.write(user_vote_data.index, new_price_data);
    refund_event.emit(caller_address, user_vote_data.depositedEth);
    let uint_deposited_eth : Uint256 = felt_to_uint256(user_vote_data.depositedEth);
    let (success) = IERC20.transfer(payment_method, caller_address, uint_deposited_eth);
    with_attr error_message("StarkGuardians::payment failed") {
        assert success = TRUE;
    }
    ReentrancyGuard._end();
    return();
    
}

@external
func vote_for_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    price_index : felt, mint_amount : felt, class : felt, proof_len : felt, proof : felt*
) {
    alloc_locals;
    ReentrancyGuard._start();
    let (caller_address) = get_caller_address();
    let (this) = get_contract_address();
    let (time) = get_block_timestamp();

    let _status : felt = case_status.read(1);
    with_attr error_message("StarkGuardians::voting is not available") {
        assert _status = TRUE;
    }
 
    let user_vote_data : UserVotes = returnUserVote(caller_address); 
    with_attr error_message("StarkGuardians::already voted") {
        assert user_vote_data.isVoted = FALSE;
    }

    if(class == 0){
        let per_wallet : felt = return_mint_per_wallet(0);
        let is_mint_amount_less_than_per_wallet : felt = is_le(mint_amount, per_wallet);
        with_attr error_message("StarkGuardians::cannot mint more than limit ") {
            assert is_mint_amount_less_than_per_wallet = TRUE;
        }

        let price_data : Price = price_options.read(price_index);
        let old_deposited : felt = returnDepositedAmount();
        let payment_method : felt = payment_methods.read();
        let total_cost : felt = price_data.cost * mint_amount;
        let _uint_cost : Uint256 = felt_to_uint256(total_cost);

        let (success) = IERC20.transferFrom(payment_method, caller_address, this, _uint_cost);
        with_attr error_message("StarkGuardians::payment failed") {
            assert success = TRUE;
        }
        total_deposited_eth.write(old_deposited + total_cost);
        
        let new_price_data : Price = Price(
            vote_count=price_data.vote_count + mint_amount,
            cost=price_data.cost
        );

        let newUserData : UserVotes = UserVotes(
            index=price_index,
            isVoted=TRUE,
            voteTime=time,
            depositedEth=total_cost,
            user_mint_alloc=mint_amount,
            minted_token_count=0,
        );
        voting_event.emit(caller_address, mint_amount,  price_index);
        user_vote.write(caller_address, newUserData);
        price_options.write(price_index, new_price_data);

        ReentrancyGuard._end();
        return();

    }else{
        let _merkle_root : felt = merkle_root.read();
        let leaf : felt = hash_user_data(caller_address, class); 
        let isVerified : felt = DolvenMerkleVerifier.verify(leaf, _merkle_root, proof_len, proof);
        with_attr error_message("StarkGuardians::merkle tree verification failed"){
            assert isVerified = 1;
        }

        let per_wallet : felt = return_mint_per_wallet(class);
        let is_mint_amount_less_than_per_wallet : felt = is_le(mint_amount, per_wallet);
        with_attr error_message("StarkGuardians::cannot mint more than limit ") {
            assert is_mint_amount_less_than_per_wallet = TRUE;
        }

        let price_data : Price = price_options.read(price_index);
        let old_deposited : felt = returnDepositedAmount();
        let payment_method : felt = payment_methods.read();
        let total_cost : felt = price_data.cost * mint_amount;
        let _uint_cost : Uint256 = felt_to_uint256(total_cost);

        voting_event.emit(caller_address, mint_amount,  price_index);

        let (success) = IERC20.transferFrom(payment_method, caller_address, this, _uint_cost);
        with_attr error_message("StarkGuardians::payment failed") {
            assert success = TRUE;
        }
        total_deposited_eth.write(old_deposited + total_cost);
        
        let new_price_data : Price = Price(
            vote_count=price_data.vote_count + mint_amount,
            cost=price_data.cost
        );

        let newUserData : UserVotes = UserVotes(
            index=price_index,
            isVoted=TRUE,
            voteTime=time,
            depositedEth=total_cost,
            user_mint_alloc=mint_amount,
            minted_token_count=0,
        );

        user_vote.write(caller_address, newUserData);
        price_options.write(price_index, new_price_data);

        ReentrancyGuard._end();
        return();
    } 

}

@external
func withdrawFunds{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(amount : felt) {
    alloc_locals;
    Ownable.assert_only_owner();
    let is_different_from_zero : felt = is_not_zero(amount);
    let amount_as_uint : Uint256 = felt_to_uint256(amount);
    let (caller_address) = get_caller_address();
    let _payment_method : felt = payment_methods.read();
    if (is_different_from_zero == TRUE){
        let (success : felt) = IERC20.transfer(_payment_method, caller_address, amount_as_uint);
        with_attr error_message("StarkGuardians::payment failed") {
            assert success = TRUE;
        }
        return();
    
    }else{
        let _supply : Uint256 = totalSupply();
        let (_, price) = returnSalePrice_index();
        let price_as_uint : Uint256 = felt_to_uint256(price);
        let (payment_amount, _) = uint256_mul(price_as_uint, _supply);
        let (success : felt) = IERC20.transfer(_payment_method, caller_address, payment_amount);
        with_attr error_message("StarkGuardians::payment failed") {
            assert success = TRUE;
        }
        return();
    }
}


@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(class : felt, mint_amount : felt, proof_len : felt, proof :felt*) {
    alloc_locals;
    ReentrancyGuard._start();
    
    let (caller_address) = get_caller_address();
    let (this) = get_contract_address();
    let (time) = get_block_timestamp();

    let _supply : Uint256 = totalSupply();
    let payment_method : felt = payment_methods.read();

    let _status : felt = case_status.read(0);
    with_attr error_message("StarkGuardians::minting is not available") {
        assert _status = TRUE;
    }
    
    let _supply_limit : felt = supply_limit.read();
    let _supply_limit_as_uint256 : Uint256 = felt_to_uint256(_supply_limit);
    let mint_amount_as_uint : Uint256 = felt_to_uint256(mint_amount);
    let (total_minted_count, _)  = uint256_add(_supply, mint_amount_as_uint);

    with_attr error_message("StarkGuardians::cannot mint more than limited supply") {
        assert_uint256_le(total_minted_count, _supply_limit_as_uint256);
    }

    claimCheck_byVoteCount(caller_address, class, total_minted_count);

    if(class == 0){
        //public user
        internal_mint(class, caller_address, payment_method, this, mint_amount);
        ReentrancyGuard._end();
        return();

    }else{
        //whitelisted user
        
        let _merkle_root : felt = merkle_root.read();
        let leaf : felt = hash_user_data(caller_address, class); 
        let isVerified : felt = DolvenMerkleVerifier.verify(leaf, _merkle_root, proof_len, proof);
        with_attr error_message("StarkGuardians::merkle tree verification failed"){
            assert isVerified = 1;
        }        
        internal_mint(class, caller_address, payment_method, this, mint_amount);
        ReentrancyGuard._end();

        return ();

    }

}


func internal_mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class : felt, caller_address : felt, payment_method : felt, this : felt, mint_amount : felt
) {
        alloc_locals;
        let user_vote_data : UserVotes = returnUserVote(caller_address); 

        let default_per_wallet : felt = return_mint_per_wallet(class);

        let is_user_minted_less_than_limit : felt = is_le(user_vote_data.minted_token_count + mint_amount, default_per_wallet);
        with_attr error_message("StarkGuardians::cannot mint more than class limit ") {
            assert is_user_minted_less_than_limit = TRUE;
        }

        if(user_vote_data.isVoted == TRUE){
            let allocated_amount : felt = user_vote_data.depositedEth;
            let (_, price_as_felt) = returnSalePrice_index();
            let cost : felt = price_as_felt * mint_amount;
            let is_allocated_less_than_mint_amount : felt = is_le(allocated_amount + 1, cost);
            let old_deposited : felt = total_deposited_eth.read();

            //ödediğim para daha az ise

            if(is_allocated_less_than_mint_amount == TRUE){
                let diff : felt = cost - allocated_amount;
                let price_as_uint : Uint256 = felt_to_uint256(diff);
                total_deposited_eth.write(old_deposited - user_vote_data.depositedEth);
                let (success : felt) = IERC20.transferFrom(payment_method, caller_address, this, price_as_uint);
                with_attr error_message("StarkGuardians::payment failed ") {
                    assert success = TRUE;
                }
                //user update
                let newUserDetails : UserVotes = UserVotes(
                    index=user_vote_data.index,
                    isVoted=user_vote_data.isVoted,
                    voteTime=user_vote_data.voteTime,
                    depositedEth=0,
                    user_mint_alloc=0,
                    minted_token_count=user_vote_data.minted_token_count + mint_amount
                );
                user_vote.write(caller_address, newUserDetails);
                recursive_mint(mint_amount, 0, caller_address);
                return();
            }else{
                total_deposited_eth.write(old_deposited - cost);
                let newUserDetails : UserVotes = UserVotes(
                    index=user_vote_data.index,
                    isVoted=user_vote_data.isVoted,
                    voteTime=user_vote_data.voteTime,
                    depositedEth=user_vote_data.depositedEth - cost,
                    user_mint_alloc=user_vote_data.user_mint_alloc - mint_amount,
                    minted_token_count=user_vote_data.minted_token_count + mint_amount
                );
                user_vote.write(caller_address, newUserDetails);
                recursive_mint(mint_amount, 0, caller_address);
                return();
            }

        }else{
            //daha önce deposit etmedim
            let (_, price_as_felt) = returnSalePrice_index();
            let cost : felt = mint_amount * price_as_felt;
            let price_as_uint : Uint256 = felt_to_uint256(cost);
            let (success : felt) = IERC20.transferFrom(payment_method, caller_address, this, price_as_uint);
            with_attr error_message("StarkGuardians::payment failed ") {
                assert success = TRUE;
            }
            let newUserDetails : UserVotes = UserVotes(
                index=user_vote_data.index,
                isVoted=user_vote_data.isVoted,
                voteTime=user_vote_data.voteTime,
                depositedEth=user_vote_data.depositedEth,
                user_mint_alloc=user_vote_data.user_mint_alloc,
                minted_token_count=user_vote_data.minted_token_count + mint_amount
            );
            user_vote.write(caller_address, newUserDetails);
            recursive_mint(mint_amount, 0, caller_address);
            return();
        }
}

func recursive_mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    size : felt, index : felt, to : felt
) {
    let (supply: Uint256) = ERC721Enumerable.total_supply();

    if(size == index){
        return();
    }
    new_minting_event.emit(to, supply);
    ERC721Enumerable._mint(to, supply);
    return recursive_mint(size, index + 1, to);
}

@external
func burn{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(tokenId: Uint256) {
    ERC721.assert_only_token_owner(tokenId);
    ERC721Enumerable._burn(tokenId);
    return ();
}


@external
func setTokenURI{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    base_token_uri_len: felt, base_token_uri: felt*, token_uri_suffix: felt
) {
    Ownable.assert_only_owner();
    ERC721_Metadata_setBaseTokenURI(base_token_uri_len, base_token_uri, token_uri_suffix);
    return ();
}


@external
func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    newOwner: felt
) {
    Ownable.transfer_ownership(newOwner);
    return ();
}

@external
func renounceOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.renounce_ownership();
    return ();
}


@external
func set_price_option_size{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(size : felt) {
    Ownable.assert_only_owner();
    price_options_size.write(size);
    return ();
}


@external
func set_stable_price_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(price_index : felt) {
    Ownable.assert_only_owner();
    stable_price_index.write(price_index);
    return ();
}

@external
func set_mint_per_wallet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(index : felt, req : felt) {
    Ownable.assert_only_owner();
    mint_per_wallet.write(index, req);
    return ();
}


@external
func set_supply_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(req : felt) {
    Ownable.assert_only_owner();
    supply_limit.write(req);
    return ();
}

@external
func set_mint_limit_for_whitelist{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(req : felt) {
    Ownable.assert_only_owner();
    mint_limit_for_whitelist.write(req);
    return ();
}

@external
func set_case_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(case : felt, status: felt) {
    Ownable.assert_only_owner();
    case_status.write(case, status);
    return ();
}

@external
func set_payment_method{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(req : felt) {
    Ownable.assert_only_owner();
    payment_methods.write(req);
    return ();
}



//Internals


func claimCheck_byVoteCount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    msg_sender : felt, class : felt, total_minted_count: Uint256
) {
    let (price_data_index,_) = returnSalePrice_index();
    let (price_detail) = price_options.read(price_data_index);
    let _supply_limit : felt = return_supply_limit();
    let user_vote_data : UserVotes = returnUserVote(msg_sender); 
    let isVotesLtSupplyLimit : felt = is_le(price_detail.vote_count, _supply_limit - 1);
    if(isVotesLtSupplyLimit == TRUE){
        if(class == 0){
            isPublicStarted(total_minted_count);
            return();
        }else{
            return();
        }
    }else{
        //SOLDOUT WITH VOTES
        with_attr error_message("StarkGuardians::soldout::public mint is not available") {
            assert user_vote_data.index = price_data_index;
        }
        return();
    }
}


func isPublicStarted{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    total_minted_count : Uint256
) {
    let _new_supply_felt : felt = uint256_to_felt(total_minted_count);
    let _mint_limit_for_whitelist : felt = mint_limit_for_whitelist.read();
    
    let is_wl_limit_less_than_supply : felt = is_le(_mint_limit_for_whitelist, _new_supply_felt);
    
    with_attr error_message("StarkGuardians::public round not started yet") {
        assert is_wl_limit_less_than_supply = TRUE;
    } 
    return();
}

func soldOutCheck{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    is_soldout : felt, user_price_index : felt
) {
    if(is_soldout == TRUE){
        return();
    }else{
        let (price_data_index,_) = returnSalePrice_index();
        with_attr error_message("StarkGuardians::user cannot be refunded before soldout") {
            assert_not_equal(user_price_index, price_data_index);
        }
        return();
    }
}

func recursiveSetLimits{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    limits: felt*, limits_len : felt, index : felt
) {
    if(index == limits_len){
        return();
    }
    mint_per_wallet.write(index, [limits]);
    recursiveSetLimits(limits + 1, limits_len, index + 1);
    return();
}

func recursiveSetPrices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prices: felt*, prices_len : felt, index : felt
) {
    let _priceData : Price = Price(
        vote_count=0,
        cost=prices[index]
    );
    if(index == prices_len){
        return();
    }
    price_options.write(index, _priceData);
    recursiveSetPrices(prices, prices_len, index + 1);
    return();
}


func hash_user_data{pedersen_ptr : HashBuiltin*}(account : felt, class : felt) -> (
    res : felt
){
    let (res) = hash2{hash_ptr=pedersen_ptr}(account, class);
    return (res=res);
}

func felt_to_uint256{range_check_ptr}(x) -> (uint_x: Uint256) {
    let (high, low) = split_felt(x);
    return (Uint256(low=low, high=high),);
}

func uint256_to_felt{range_check_ptr}(value: Uint256) -> (value: felt) {
    assert_lt_felt(value.high, 2 ** 123);
    return (value.high * (2 ** 128) + value.low,);
}