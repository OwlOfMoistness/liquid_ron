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

## Contract function explanation

Escrow.sol - Contract deployed by the vault to act an intermediary to hold funds for the vault to prevent miscaculations in how the vault mints and burns shares. The vault is handling wrapped RON while users commonly use native RON. To simplify the user flow, we allow users to deposit native ron directly. The escrow contract is also used to hold pending withdrawable funds as well as deposit for users.

- `deposit(uint256 _amount, address _receiver)` - Called by the vault `deposit()` function. Only the vault can call this function to prevent malicious extraction of funds from the escrow. The escrow account then calls the [ERC-4626](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/) `deposit(uint256 _amount, address _receiver)` function to deposit on behalf of the receiver.

RonHelper.sol - Internal abstract contract to help the vault and proxy contracts to handle native token deposit/withdrawals.

- `_depositRONTo(address to, uint256 amount)` - Deposit RON into wrapped RON and transfer them to the recipient

- `_withdrawRONTo(address to, uint256 amount)` - Withdrawn RON from wrapped RON and transfer them to the recipient

LiquidProxy.sol - Contracts deployed by the vault that interact directly with the Ronin Staking Contract (RSC acronym used for later reference). As their name suggests, they act as proxies to reduce the impact of staking rules. Once you stake on a validator, you can't remove your stake for 72 hours. Having multiple proxies allows us to stake on one proxy and unstake from another if necessary. Only the vault can call proxy functions:

- `harvest(address[] calldata _consensusAddrs)`: Proxy calls the claimRewards function on the RSC and sends them back to the vault. Rewards are claimed on the given consensus Addresses passed as argument.

- `harvestAndDelegateRewards(address[] calldata _consensusAddrs, address _consensusAddrDst)`: Proxy calls the delegateRewards function on the RSC to compound rewards and stake them on the designated _consensusAddrDst. 

- `delegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrs)`: Proxy calls the delegate function to delegate the amounts given to each consensus address given as argument. 

- `redelegateAmount( uint256[] calldata _amounts, address[] calldata _consensusAddrsSrc, address[] calldata _consensusAddrsDs)`: Proxy calls the redelegate function on the RSC which will move the stake from on consensus address to another. The stake reallocations are given by the lists of amounts, address sources and address destinations.

- `undelegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrs)`: Proxy calls the undelegate function on the RSC and sends back the RON back to the vault in from of wrapped RON.


LiquidRon.sol - Contract inheriting from  the [ERC-4626 standard](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/) that allows user to deposit their RON and get vault shares representing the RON in the vault. This ron will be then sent from the vault to the proxies deployed by it and staked on various validators to maximise rewards and therefore increase the RON per share over time. Proxies are used to granulate the stake and reduce the downsides behaviours of staking/claiming from the RSC

- `harvest(uint256 _proxyIndex, address[] calldata _consensusAddrs)` - Vault calls a proxy's `harvest` function. Operator only call.

- `harvestAndDelegateRewards( uint256 _proxyIndex, address[] calldata _consensusAddrs, address _consensusAddrDst)` - Vault calls a proxy's `harvestAndDelegateRewards` function. Operator only call.

- `delegateAmount(uint256 _proxyIndex, uint256[] calldata _amounts, address[] calldata _consensusAddrs)` - Vault calls a proxy's `delegateAmount` function. Operator only call.

- `redelegateAmount(uint256 _proxyIndex, uint256[] calldata _amounts, address[] calldata _consensusAddrsSrc, address[] calldata _consensusAddrsDst)` - Vault calls a proxy's `redelegateAmount` function. Operator only call.

- `undelegateAmount(uint256 _proxyIndex, uint256[] calldata _amounts, address[] calldata _consensusAddrs)` - Vault calls a proxy's `undelegateAmount` function. Operator only call.

- `pruneValidatorList()` - Function callable my anyone. This will remove validators from the list inside the vault if their sum of total staked amount and total rewards are 0 both. This is to make sure we don't ommit validators that renounce as they won't be available on chain via function calls to the ronin validator set contracts. By keeping record in the vault, we keep track where all our funds are and we can remove them once all stakes and rewards have been removed.

- `finaliseRonRewardsForEpoch()` - Function called by the operator if users have requested a withdrawal. This will occur if the amount of assets in the vault is lower than what a user would like to withdraw. In such case, we will have an operator claim rewards or undelegate enough funds to cover the requested amount assets to be redeemed. The funds will then be sent to the escrow contract for future redemption by users that requested withdrawal on that epoch.

- `withdraw(uint256 _assets, address _receiver, address _owner)` - User function to withdraw assets. This has been overriden to add the functionality of sending back native RON abck to users. For this to work, the vault must switch the receiver to itself to receive the assets, then withdraw the RON before sending to the user. The `Withdraw` event is then emitted here instead of `_withdraw` to fix the wrong receiver from being added.

- - `redeem(uint256 shares, address _receiver, address _owner)` - User function to redeem shares. This has been overriden to add the functionality of sending back native RON abck to users. For this to work, the vault must switch the receiver to itself to receive the assets, then withdraw the RON before sending to the user. The `Withdraw` event is then emitted here instead of `_withdraw` to fix the wrong receiver from being added.

- `deposit()` - User function to deposit native ron into the vault. We still support the other `deposit` and `mint` functions but this functinos allows user to send RON directly to the vault. We deposit the wrapped RON in the escrow contract and make the deposit from there to prevent share minting miscalculations. 

- `requestWithdrawal(uint256 _shares)` - User function to request withdrawl of assets from given shares. Ideally this should only be called if the amount of assets to be expected is larger than what the vault currently holds sitting idle. Otherwise, `withdraw` and `redeem` should be the suggested route.

- `redeem(uint256 _epoch)` User function to redeem the shares locked during a withdrawal request. Wrapped ron are taken from the escrow and sent to users as native RON.

- `receive()` - Allows users to send directly RON to the vault and convert it to shares on their behalf. Only scenario this doesnt happen is when RON is sent from the wrapped contract in which case, the vault will do nothing and accept the transfer.

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
