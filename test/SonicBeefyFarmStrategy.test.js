const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SonicBeefyFarmStrategy", function () {
  let strategy, owner, vault, mockSonic, mockBeefy, mockToken, mockBeefyStrategy;

  beforeEach(async function () {
    // Get signers first
    [owner, vault] = await ethers.getSigners();

    try {
      // Deploy mocks one by one with proper error handling
      const MockToken = await ethers.getContractFactory("MockERC20");
      console.log("Deploying MockToken...");
      mockToken = await MockToken.deploy("Mock Token", "MTK");
      await mockToken.waitForDeployment();
      const mockTokenAddress = await mockToken.getAddress();
      console.log("MockToken deployed to:", mockTokenAddress);

      const MockSonic = await ethers.getContractFactory("MockOriginSonic");
      console.log("Deploying MockSonic...");
      mockSonic = await MockSonic.deploy();
      await mockSonic.waitForDeployment();
      console.log("MockSonic deployed to:", await mockSonic.getAddress());

      const MockBeefyStrategy = await ethers.getContractFactory("MockStrategyV7");
      console.log("Deploying MockBeefyStrategy...");
      mockBeefyStrategy = await MockBeefyStrategy.deploy();
      await mockBeefyStrategy.waitForDeployment();
      const mockBeefyStrategyAddress = await mockBeefyStrategy.getAddress();
      console.log("MockBeefyStrategy deployed to:", mockBeefyStrategyAddress);

      // Deploy MockBeefy
      const MockBeefy = await ethers.getContractFactory("MockBeefyVault");
      console.log("Deploying MockBeefy...");
      mockBeefy = await MockBeefy.deploy(mockTokenAddress, {
        gasLimit: 1000000
      });
      await mockBeefy.waitForDeployment();
      console.log("MockBeefy deployed to:", await mockBeefy.getAddress());

      // Deploy strategy
      const Strategy = await ethers.getContractFactory("SonicBeefyFarmStrategy");
      console.log("Deploying Strategy...");
      strategy = await Strategy.deploy(
        await vault.getAddress(),
        await mockSonic.getAddress(),
        await mockToken.getAddress(),
        1, // defaultValidatorId
        await mockBeefy.getAddress()
      );
      await strategy.waitForDeployment();
      console.log("Strategy deployed to:", await strategy.getAddress());

      // Setup initial tokens
      console.log("Setting up initial tokens...");
      await mockToken.mint(await strategy.getAddress(), ethers.parseEther("1000"));
      await mockToken.mint(await vault.getAddress(), ethers.parseEther("1000"));
      await mockToken.connect(vault).approve(await strategy.getAddress(), ethers.MaxUint256);
      await mockToken.connect(vault).approve(await mockBeefy.getAddress(), ethers.MaxUint256);

    } catch (error) {
      console.error("Error during deployment:", error);
      console.error("Error location:", error.stack);
      throw error;
    }
  });

  describe("Initialization", function () {
    it("Should set correct initial values", async function () {
      expect(await strategy.hasRole(await strategy.VAULT_ROLE(), await vault.getAddress())).to.be.true;
      expect(await strategy.beefyVault()).to.equal(await mockBeefy.getAddress());
      expect(await strategy.wrappedSonic()).to.equal(await mockToken.getAddress());
    });
  });

  describe("Beefy Integration", function () {
    it("Should deposit into Beefy vault", async function () {
      const amount = ethers.parseEther("100");
      await mockBeefy.setDepositResult(amount);
      await expect(strategy.connect(vault).depositToBeefyVault(amount))
        .to.emit(strategy, "BeefyDeposited")
        .withArgs(amount);
    });

    it("Should withdraw from Beefy vault", async function () {
      const amount = ethers.parseEther("100");
      await mockBeefy.setWithdrawResult(amount);
      await strategy.connect(vault).depositToBeefyVault(amount);
      await expect(strategy.connect(vault).withdrawFromBeefyVault(amount))
        .to.emit(strategy, "BeefyWithdrawn")
        .withArgs(amount, amount);
    });
  });

  describe("Rewards", function () {
    it("Should harvest rewards", async function () {
      console.log("Setting up harvest test...");
      
      // 1. Get addresses
      const mockTokenAddress = await mockToken.getAddress();
      const mockBeefyAddress = await mockBeefy.getAddress();
      const mockStrategyAddress = await mockBeefyStrategy.getAddress();
      
      // 2. Setup mock strategy first
      console.log("Setting up mock strategy...");
      await mockBeefyStrategy.setWant(mockTokenAddress);
      await mockBeefyStrategy.setVault(mockBeefyAddress);
      
      // 3. Setup mock beefy vault BEFORE deploying main strategy
      console.log("Setting up mock beefy vault...");
      await mockBeefy.setBeefyStrategy(mockStrategyAddress);
      
      // 4. Deploy strategy after Beefy vault is set up
      console.log("Deploying main strategy...");
      const Strategy = await ethers.getContractFactory("SonicBeefyFarmStrategy");
      strategy = await Strategy.deploy(
        await vault.getAddress(),
        await mockSonic.getAddress(),
        await mockToken.getAddress(),
        1, // defaultValidatorId
        mockBeefyAddress
      );
      await strategy.waitForDeployment();
      const strategyAddress = await strategy.getAddress();
      
      // 5. Setup balances
      console.log("Setting up balances...");
      await mockToken.mint(mockBeefyAddress, ethers.parseEther("100"));
      await mockToken.mint(strategyAddress, ethers.parseEther("10"));
      await mockToken.mint(mockStrategyAddress, ethers.parseEther("10"));
      
      // 6. Setup approvals
      console.log("Setting up approvals...");
      await mockToken.connect(vault).approve(strategyAddress, ethers.MaxUint256);
      await mockToken.connect(vault).approve(mockBeefyAddress, ethers.MaxUint256);
      
      // 7. Initial deposit
      console.log("Making initial deposit...");
      const depositAmount = ethers.parseEther("1");
      await mockBeefy.setDepositResult(depositAmount);
      await strategy.connect(vault).depositToBeefyVault(depositAmount);

      // 8. Try harvest
      console.log("Attempting harvest...");
      await expect(strategy.connect(owner).harvest())
          .to.emit(strategy, "StrategyHarvested");
    });

    it("Should earn", async function () {
      await expect(strategy.connect(owner).earn())
        .to.emit(strategy, "BeefyEarned");
    });
  });
}); 