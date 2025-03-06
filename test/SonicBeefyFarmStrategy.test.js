const { expect } = require("chai");
const hre = require("hardhat");

describe("SonicBeefyFarmStrategy", function () {
  let strategy, owner, vault, mockSonic, mockBeefy, mockToken, mockBeefyStrategy;

  beforeEach(async function () {
    [owner, vault] = await hre.ethers.getSigners();

    // Deploy mocks
    const MockToken = await hre.ethers.getContractFactory("MockERC20");
    mockToken = await MockToken.deploy("Mock Token", "MTK");

    const MockSonic = await hre.ethers.getContractFactory("MockOriginSonic");
    mockSonic = await MockSonic.deploy();

    const MockBeefyStrategy = await hre.ethers.getContractFactory("MockStrategyV7");
    mockBeefyStrategy = await MockBeefyStrategy.deploy();

    const MockBeefy = await hre.ethers.getContractFactory("MockBeefyVault");
    mockBeefy = await MockBeefy.deploy(
      await mockToken.getAddress(),
      await mockBeefyStrategy.getAddress()
    );

    // Deploy strategy
    const Strategy = await hre.ethers.getContractFactory("SonicBeefyStrategy");
    strategy = await Strategy.deploy(
      await vault.getAddress(),
      await mockSonic.getAddress(),
      await mockToken.getAddress(),
      1, // defaultValidatorId
      await mockBeefy.getAddress()
    );

    // Setup initial tokens
    await mockToken.mint(await strategy.getAddress(), hre.ethers.parseEther("1000"));
    await mockToken.mint(await vault.getAddress(), hre.ethers.parseEther("1000"));
    await mockToken.connect(vault).approve(await strategy.getAddress(), hre.ethers.MaxUint256);
    await mockToken.connect(vault).approve(await mockBeefy.getAddress(), hre.ethers.MaxUint256);
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
      const amount = hre.ethers.parseEther("100");
      await expect(strategy.connect(vault).depositToBeefyVault(amount))
        .to.emit(strategy, "BeefyDeposited")
        .withArgs(amount);
    });

    it("Should withdraw from Beefy vault", async function () {
      const amount = hre.ethers.parseEther("100");
      await strategy.connect(vault).depositToBeefyVault(amount);
      await expect(strategy.connect(vault).withdrawFromBeefyVault(amount))
        .to.emit(strategy, "BeefyWithdrawn")
        .withArgs(amount, amount);
    });
  });

  describe("Rewards", function () {
    it("Should harvest rewards", async function () {
      await expect(strategy.connect(owner).harvest())
        .to.emit(strategy, "StrategyHarvested");
    });

    it("Should earn", async function () {
      await expect(strategy.connect(owner).earn())
        .to.emit(strategy, "BeefyEarned");
    });
  });
}); 