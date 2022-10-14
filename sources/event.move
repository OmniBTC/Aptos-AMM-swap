/// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.

module swap::event {
    use std::signer;

    use aptos_framework::account;
    use aptos_std::event;

    /// Liquidity pool created event.
    struct CreatedEvent<phantom X, phantom Y> has drop, store {
        creator: address,
    }

    /// Liquidity pool added event.
    struct AddedEvent<phantom X, phantom Y> has drop, store {
        x_val: u64,
        y_val: u64,
        lp_tokens: u64,
    }

    /// Liquidity pool removed event.
    struct RemovedEvent<phantom X, phantom Y> has drop, store {
        x_val: u64,
        y_val: u64,
        lp_tokens: u64,
    }

    /// Liquidity pool swapped event.
    struct SwappedEvent<phantom X, phantom Y> has drop, store {
        x_in: u64,
        x_out: u64,
        y_in: u64,
        y_out: u64,
    }

    /// Last price oracle.
    struct OracleUpdatedEvent<phantom X, phantom Y> has drop, store {
        x_cumulative: u128,
        // last price of x cumulative.
        y_cumulative: u128,
        // last price of y cumulative.
    }

    struct EventsStore<phantom X, phantom Y> has key {
        created_handle: event::EventHandle<CreatedEvent<X, Y>>,
        removed_handle: event::EventHandle<RemovedEvent<X, Y>>,
        added_handle: event::EventHandle<AddedEvent<X, Y>>,
        swapped_handle: event::EventHandle<SwappedEvent<X, Y>>,
        oracle_updated_handle: event::EventHandle<OracleUpdatedEvent<X, Y>>,
    }

    public fun create_events_store<X, Y>(pool_account: &signer, acc: &signer) {
        let events_store = EventsStore<X, Y> {
            created_handle: account::new_event_handle<CreatedEvent<X, Y>>(pool_account),
            removed_handle: account::new_event_handle<RemovedEvent<X, Y>>(pool_account),
            added_handle: account::new_event_handle<AddedEvent<X, Y>>(pool_account),
            swapped_handle: account::new_event_handle<SwappedEvent<X, Y>>(pool_account),
            oracle_updated_handle: account::new_event_handle<OracleUpdatedEvent<X, Y>>(pool_account),
        };

        event::emit_event(
            &mut events_store.created_handle,
            CreatedEvent<X, Y> {
                creator: signer::address_of(acc)
            },
        );

        move_to(pool_account, events_store);
    }

    public fun removed_event<X, Y>(
        coin_x: u64,
        coin_y: u64,
        lp: u64
    ) acquires EventsStore {
        let events_store = borrow_global_mut<EventsStore<X, Y>>(@swap_pool_account);
        event::emit_event(
            &mut events_store.removed_handle,
            RemovedEvent<X, Y> {
                x_val: coin_x,
                y_val: coin_y,
                lp_tokens: lp,
            });
    }

    public fun added_event<X, Y>(
        coin_x: u64,
        coin_y: u64,
        lp: u64
    ) acquires EventsStore {
        let events_store = borrow_global_mut<EventsStore<X, Y>>(@swap_pool_account);
        event::emit_event(
            &mut events_store.added_handle,
            AddedEvent<X, Y> {
                x_val: coin_x,
                y_val: coin_y,
                lp_tokens: lp,
            });
    }

    public fun swapped_event<X, Y>(
        x_in: u64,
        x_out: u64,
        y_in: u64,
        y_out: u64
    ) acquires EventsStore {
        let events_store = borrow_global_mut<EventsStore<X, Y>>(@swap_pool_account);
        event::emit_event(
            &mut events_store.swapped_handle,
            SwappedEvent<X, Y> {
                x_in,
                x_out,
                y_in,
                y_out,
            });
    }

    public fun update_oracle_event<X, Y>(
        x_cumulative: u128,
        y_cumulative: u128,
    ) acquires EventsStore {
        let events_store = borrow_global_mut<EventsStore<X, Y>>(@swap_pool_account);
        event::emit_event(
            &mut events_store.oracle_updated_handle,
            OracleUpdatedEvent<X, Y> {
                x_cumulative,
                y_cumulative,
            });
    }
}
