# Decentralized Stablecoin

This project is a DeFi application that enables users to mint, burn, and manage a stablecoin (SC) backed by real-world assets and pegged to the US dollar. The system leverages Chainlink oracles for real-time price feeds and OpenZeppelin for secure smart contract development.

## Features

- Exogenously Collateralized: Uses external assets as collateral to ensure SC value stability.
- Dollar Pegged: Maintains a 2:1 value with the US dollar, offering a stable and predictable currency.
- Algorithmically Stable: Uses sophisticated algorithms to manage supply and demand in volatile markets.
- Overcollateralization: Requires overcollateralization to ensure system security and stability.

## Technologies Used

- Solidity: The programming language used to write smart contracts for the Ethereum blockchain.
- Chainlink: Provides real-time price feeds to smart contracts, ensuring accurate valuation of collateral.
- Foundry: A development environment for Ethereum that allows for compiling, testing, and deploying smart contracts.
- OpenZeppelin: Library for secure smart contract development.

## Project Structure

- src: Contains the smart contracts (SCEngine.sol, StableCoin.sol), library contracts (ChainlinkManager.sol, Utilis.sol), and test files for the smart contracts.
- script: Contains deployment scripts for the smart contracts & mocks contracts for testing purpose.
- test: Contains unit and fuzz tests for the project.

<pre>
  ├── lib
  ├── script>
  │  &emsp; └── deploy
  │  &emsp;&emsp;&emsp;&emsp; ├── DeploySCEngine.s.sol
  │  &emsp;&emsp;&emsp;&emsp; ├── HelperConfig.s.sol
  │  &emsp;&emsp;&emsp;&emsp; └── mocks
  │  &emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&ensp; └── all mock contracts & deployments
  ├── src
  │  &emsp; ├── SCEngine.sol
  │  &emsp; ├── StableCoin.sol
  │  &emsp; └── Libraries
  │  &emsp;&emsp;&emsp;&emsp;&emsp; ├── ChainlinkManager.sol
  │  &emsp;&emsp;&emsp;&emsp;&emsp; └── Utilis.sol
  ├── test
  │  &emsp; └── fuzz
  │  &emsp; └── unit
  ├── README.md
  ├── foundry.toml
</pre>

<br>

## Getting Started

To get started with this project, clone the repository and install the dependencies:

## Prerequisites

- Bash
- Foundry
- Ethereum wallet

### Quickstart

Clone the repository and navigate to the newly created folder:

```bash
git clone https://github.com/Ehsan-The-Coder/StableCoin.git
cd StableCoin
forge install
```

### Build

```bash
forge build
```

### Testing

```bash
forge test
```

```bash
forge test --match-test your-test-name
```

### Test Coverage

```bash
forge coverage
```

and for coverage based testing:

```bash
forge coverage --report debug
```

### Usage with a local node

```bash
anvil
```

<br>

## License

This project is licensed under the MIT License.

## Acknowledgments

- [Solidity](https://soliditylang.org/)
- [Foundry](https://https://book.getfoundry.sh/)
- [Chainlink](https://docs.chain.link/data-feeds/price-feeds/)
- [OpenZeppelin](https://openzeppelin.com/)
- [PatrickCollins](https://github.com/PatrickAlphaC)

## Connect with me

- [Linkedin](https://www.linkedin.com/in/ehsanthecoder/)
- [X/Twitter](https://twitter.com/ehsanthecoder)
- [Github](https://github.com/Ehsan-The-Coder)
- [Gmail] ehsangondal1@gmail.com
