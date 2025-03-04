# Cult of Ronin Strategy Contracts

Smart contracts for Cult of Ronin's yield farming strategies, enabling automated yield optimization across multiple protocols.

## Strategies

- **SonicBeefyFarmStrategy**: Auto-compounds rewards from Sonic into Beefy vaults
- **AaveSonicCrossChainStrategy**: Cross-chain strategy leveraging Aave lending and Sonic farming and Debridge for cross-chain transfers

## Setup
bash
npm install
npx hardhat compile
npx hardhat test


## Security

- Contracts use OpenZeppelin's security standards
- Access control implementation for secure management
- Reentrancy protection on critical functions

## License

MIT
