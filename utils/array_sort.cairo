%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn, is_nn_le, is_in_range
from starkware.cairo.common.bool import FALSE, TRUE

namespace ArraySorting {

    func get_new_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        arr_len: felt, arr: felt*
    ) {
        alloc_locals;
        let (local arr: felt*) = alloc();
        return (0, arr);
    }


    func assert_check_array_not_empty{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        arr_len: felt
    ) {
        let res = is_not_zero(arr_len);
        with_attr error_message("Empty array") {
            assert res = TRUE;
        }
        return ();
    }


    func index_of_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        arr_len: felt, arr: felt*
    ) -> (index: felt) {
        assert_check_array_not_empty(arr_len);
        return index_of_max_recursive(arr_len, arr, arr[0], 0, 1);
    }

    func index_of_max_recursive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        arr_len: felt, arr: felt*, current_max: felt, current_max_index: felt, current_index: felt
    ) -> (index: felt) {
        if (arr_len == current_index) {
            return (current_max_index,);
        }
        let isLe = is_le(current_max, arr[current_index]);
        if (isLe == TRUE) {
            return index_of_max_recursive(
                arr_len, arr, arr[current_index], current_index, current_index + 1
            );
        }
        return index_of_max_recursive(arr_len, arr, current_max, current_max_index, current_index + 1);
    }

    func assert_index_in_array_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        arr_len: felt, index: felt
    ) {
        let res = is_le(index, arr_len);
        with_attr error_message("Index out of range") {
            assert res = TRUE;
        }
        return ();
    }
    func remove_at{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        arr_len : felt, arr : felt*, index : felt
    ) -> (arr_len : felt, arr : felt*){
        alloc_locals;
        assert_check_array_not_empty(arr_len);
        assert_index_in_array_length(arr_len, index + 1);
        let (new_arr_len, new_arr) = get_new_array();
        memcpy(new_arr, arr, index);
        memcpy(new_arr + index, arr + index + 1, arr_len - index - 1);
        return (arr_len - 1, new_arr);
    }


    func sort_recursive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        old_arr_len: felt, old_arr: felt*, sorted_arr_len: felt, sorted_arr: felt*
    ) -> (arr_len: felt, arr: felt*) {
        alloc_locals;
        // Array to be sorted is empty
        if (old_arr_len == 0) {
            return (sorted_arr_len, sorted_arr);
        }
        let (indexOfMax) = index_of_max(old_arr_len, old_arr);
        // Pushing the max occurence to the last available spot
        assert sorted_arr[sorted_arr_len] = old_arr[indexOfMax];
        // getting a new old array
        let (old_shortened_arr_len, old_shortened_arr) = remove_at(old_arr_len, old_arr, indexOfMax);
        return sort_recursive(old_shortened_arr_len, old_shortened_arr, sorted_arr_len + 1, sorted_arr);
    }
}
