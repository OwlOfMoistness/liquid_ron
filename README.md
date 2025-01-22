# Liquid Ron

**Liquid Ron is a Ronin staking protocol that automates user staking actions.**

Deposit RON, get liquid RON, a token representing your stake in the validation process of the Ronin Network.

Liquid RON stakes and harvests rewards automatically, auto compounding your rewards and ensuring the best yield possible.

## How does it work?

Liquid RON is built on the [ERC-4626](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/) foundation, a token interest bearing vault. As users deposit RON, it gets staked in the validation process, and the vault tokens price per share will increase over time as rewards are realised. 

Users can freely transfer Liquid RON.

## Deposits

Users can call the `deposit()` function to send RON directly to the vault. The vault will then issue the correct amount of Liquid RON. Alternatively you can use the standard `deposit` or `mint` functions of the [ERC-4626](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/) standard. 


## Witdrawals

User withdrawals are done via the vault standard. If not enough liquidity is present at any given time, users can request withdrawal by locking their tokens and an operator will process those amounts once/twice a week (TBD).

## Expected contract behaviours

- RON tokens can only go from users to the vault, vault to staking proxies, and proxies to the Ronin staking contract. The inverse flow is also true.
- Users can query any function available from the [ERC-4626](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/) as well as requesting withdrawals and depositing RON natively
- Operators can manage how RON tokens are staked on various proxies and validators. The point is to granulate the stakes enough that if big withdrawals are needed, we can both stake and unstake without having locked positions for 72 hours.
- RON will be allocated to generate the best yield
- Proxies deployed by the vault can only be called by the vault, ensuring funds are not at risk
- A performance fee will be applied to any rewards realised (TBD).


=================================================

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
