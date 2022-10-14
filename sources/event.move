// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.
module swap::event {
    use std::string::String;

    use aptos_framework::account;
    use aptos_std::event::{EventHandle, emit_event};
    use aptos_std::type_info::type_name;

    friend swap::implements;

    /// Liquidity pool created event.
    struct CreatedEvent has drop, store {
        creator: address,
        coin_x: String,
        coin_y: String
    }

    /// Liquidity pool added event.
    struct AddedEvent has drop, store {
        coin_x: String,
        coin_y: String,
        x_val: u64,
        y_val: u64,
        lp_tokens: u64,
    }

    /// Liquidity pool removed event.
    struct RemovedEvent has drop, store {
        coin_x: String,
        coin_y: String,
        x_val: u64,
        y_val: u64,
        lp_tokens: u64,
    }

    /// Liquidity pool swapped event.
    struct SwappedEvent has drop, store {
        coin_x: String,
        coin_y: String,
        x_in: u64,
        x_out: u64,
        y_in: u64,
        y_out: u64,
    }

    /// Last price oracle.
    struct OracleUpdatedEvent has drop, store {
        coin_x: String,
        coin_y: String,
        x_cumulative: u128,
        // last price of x cumulative.
        y_cumulative: u128,
        // last price of y cumulative.
    }

    /// Withdraw fee coins
    struct WithdrewEvent has drop, store {
        coin: String,
        fee: u64
    }

    struct EventsStore has key {
        created_handle: EventHandle<CreatedEvent>,
        removed_handle: EventHandle<RemovedEvent>,
        added_handle: EventHandle<AddedEvent>,
        swapped_handle: EventHandle<SwappedEvent>,
        oracle_updated_handle: EventHandle<OracleUpdatedEvent>,
        withdrew_handle: EventHandle<WithdrewEvent>
    }

    public(friend) fun initialize(pool_account: &signer) {
        let events_store = EventsStore {
            created_handle: account::new_event_handle<CreatedEvent>(pool_account),
            removed_handle: account::new_event_handle<RemovedEvent>(pool_account),
            added_handle: account::new_event_handle<AddedEvent>(pool_account),
            swapped_handle: account::new_event_handle<SwappedEvent>(pool_account),
            oracle_updated_handle: account::new_event_handle<OracleUpdatedEvent>(pool_account),
            withdrew_handle: account::new_event_handle<WithdrewEvent>(pool_account),
        };

        move_to(pool_account, events_store);
    }

    public(friend) fun created_event<X, Y>(
        pool_address: address,
        creator: address
    ) acquires EventsStore {
        let event_store = borrow_global_mut<EventsStore>(pool_address);

        emit_event(
            &mut event_store.created_handle,
            CreatedEvent {
                creator,
                coin_x: type_name<X>(),
                coin_y: type_name<Y>()
            },
        )
    }

    public(friend) fun added_event<X, Y>(
        pool_address: address,
        x_val: u64,
        y_val: u64,
        lp_tokens: u64
    ) acquires EventsStore {
        let event_store = borrow_global_mut<EventsStore>(pool_address);

        emit_event(
            &mut event_store.added_handle,
            AddedEvent {
                coin_x: type_name<X>(),
                coin_y: type_name<Y>(),
                x_val,
                y_val,
                lp_tokens,
            }
        )
    }

    public(friend) fun removed_event<X, Y>(
        pool_address: address,
        x_val: u64,
        y_val: u64,
        lp_tokens: u64,
    ) acquires EventsStore {
        let event_store = borrow_global_mut<EventsStore>(pool_address);

        emit_event(
            &mut event_store.removed_handle,
            RemovedEvent {
                coin_x: type_name<X>(),
                coin_y: type_name<Y>(),
                x_val,
                y_val,
                lp_tokens,
            }
        )
    }

    public(friend) fun swapped_event<X, Y>(
        pool_address: address,
        x_in: u64,
        x_out: u64,
        y_in: u64,
        y_out: u64
    ) acquires EventsStore {
        let event_store = borrow_global_mut<EventsStore>(pool_address);

        emit_event(
            &mut event_store.swapped_handle,
            SwappedEvent {
                coin_x: type_name<X>(),
                coin_y: type_name<Y>(),
                x_in,
                x_out,
                y_in,
                y_out,
            }
        )
    }

    public(friend) fun update_oracle_event<X, Y>(
        pool_address: address,
        x_cumulative: u128,
        y_cumulative: u128,
    ) acquires EventsStore {
        let event_store = borrow_global_mut<EventsStore>(pool_address);

        emit_event(
            &mut event_store.oracle_updated_handle,
            OracleUpdatedEvent {
                coin_x: type_name<X>(),
                coin_y: type_name<Y>(),
                x_cumulative,
                y_cumulative,
            }
        )
    }

    public(friend) fun withdrew_event<Coin>(
        pool_address: address,
        fee: u64
    ) acquires EventsStore {
        let event_store = borrow_global_mut<EventsStore>(pool_address);

        emit_event(
            &mut event_store.withdrew_handle,
            WithdrewEvent {
                coin: type_name<Coin>(),
                fee
            }
        )
    }
}
