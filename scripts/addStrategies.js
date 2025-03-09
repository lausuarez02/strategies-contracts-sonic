const { ethers } = require('ethers');

// SuperVault ABI (just the functions we need)
const ABI = [
  "function addPool(string calldata poolName, address poolAddress) external",
  "function getPoolList() external view returns (string[] memory)"
];

async function main() {
  // Connect to the network
  const provider = new ethers.JsonRpcProvider("https://rpc.soniclabs.com");
  const signer = new ethers.Wallet("", provider);

  const SUPERVAULT_ADDRESS = "0x4BdE0740740b8dBb5f6Eb8c9ccB4Fc01171e953C";
//   const STRATEGY_ADDRESS = "0xC4012a3D99BC96637A03BF91A2e7361B1412FD17"; // Replace with your strategy address
const STRATEGY_ADDRESS = "0xa1057829b37d1b510785881B2E87cC87fb4cccD3"; // Replace with your strategy address
  
  // Get the SuperVault contract instance
  const supervault = new ethers.Contract(SUPERVAULT_ADDRESS, ABI, signer);
  
  console.log("Adding new pool...");

  try {
    const tx = await supervault.addPool("STRATEGY_2", STRATEGY_ADDRESS);
    await tx.wait();
    console.log(`Successfully added pool with address ${STRATEGY_ADDRESS}`);
    
    // Verify the pool was added
    const poolList = await supervault.getPoolList();
    console.log("Current pool list:", poolList);
  } catch (error) {
    console.error("Failed to add pool:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 