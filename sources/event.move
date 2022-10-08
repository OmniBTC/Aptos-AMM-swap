
module swap::event {
  use std::signer;

  use aptos_std::event;
  use aptos_framework::account;

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
    x_cumulative: u128, // last price of x cumulative.
    y_cumulative: u128, // last price of y cumulative.
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
}
