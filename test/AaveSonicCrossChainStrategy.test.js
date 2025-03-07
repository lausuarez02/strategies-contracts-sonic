const { expect } = require("chai");
const hre = require("hardhat");

describe("AaveSonicCrossChainStrategy", function () {
  let strategy, owner, manager;
  let mockToken, mockAave, mockDeBridge, mockSonicFarm;

  beforeEach(async function () {
    [owner, manager] = await hre.ethers.getSigners();

    // Deploy mock tokens and contracts
    const MockToken = await hre.ethers.getContractFactory("MockERC20");
    mockToken = await MockToken.deploy("Mock Token", "MTK");

    const MockAave = await hre.ethers.getContractFactory("MockAaveLendingPool");
    mockAave = await MockAave.deploy();

    const MockDeBridge = await hre.ethers.getContractFactory("MockDeBridgeGateway");
    mockDeBridge = await MockDeBridge.deploy();

    const MockSonicFarm = await hre.ethers.getContractFactory("MockSonicFarm");
    mockSonicFarm = await MockSonicFarm.deploy();

    // Deploy strategy
    const Strategy = await hre.ethers.getContractFactory("AaveSonicCrossChainStrategy");
    strategy = await Strategy.deploy(
      await mockToken.getAddress(),
      await mockAave.getAddress(),
      await mockDeBridge.getAddress(),
      await mockSonicFarm.getAddress(),
      123 // destinationChainId
    );

    // Grant manager role
    await strategy.grantRole(await strategy.MANAGER_ROLE(), manager.address);

    // Setup initial tokens
    await mockToken.mint(manager.address, hre.ethers.parseEther("1000"));
    await mockToken.connect(manager).approve(await strategy.getAddress(), hre.ethers.MaxUint256);
  });

  describe("Initialization", function () {
    it("Should set correct initial values", async function () {
      expect(await strategy.asset()).to.equal(await mockToken.getAddress());
      expect(await strategy.aaveLendingPool()).to.equal(await mockAave.getAddress());
      expect(await strategy.deBridge()).to.equal(await mockDeBridge.getAddress());
      expect(await strategy.sonicFarm()).to.equal(await mockSonicFarm.getAddress());
      expect(await strategy.destinationChainId()).to.equal(123);
    });

    it("Should set correct roles", async function () {
      expect(await strategy.hasRole(await strategy.DEFAULT_ADMIN_ROLE(), owner.address)).to.be.true;
      expect(await strategy.hasRole(await strategy.MANAGER_ROLE(), manager.address)).to.be.true;
    });
  });

  describe("Basic Operations", function () {
    it("Should supply to Aave", async function () {
      const amount = hre.ethers.parseEther("100");
      await expect(strategy.connect(manager).supplyToAave(amount))
        .to.emit(strategy, "Supplied")
        .withArgs(amount);
      
      expect(await strategy.totalSupplied()).to.equal(amount);
    });

    it("Should borrow and bridge", async function () {
      const amount = hre.ethers.parseEther("50");
      await expect(strategy.connect(manager).borrowAndBridge(amount))
        .to.emit(strategy, "Borrowed")
        .withArgs(amount)
        .to.emit(strategy, "BridgedToSonic")
        .withArgs(amount);
      
      expect(await strategy.totalBorrowed()).to.equal(amount);
    });

    it("Should farm in Sonic", async function () {
      const amount = hre.ethers.parseEther("25");
      await expect(strategy.connect(manager).farmInSonic(amount))
        .to.emit(strategy, "FarmedInSonic")
        .withArgs(amount);
    });

    it("Should withdraw and repay", async function () {
      const amount = hre.ethers.parseEther("10");
      await expect(strategy.connect(manager).withdrawAndRepay(amount))
        .to.emit(strategy, "WithdrawnFromSonic")
        .withArgs(amount)
        .to.emit(strategy, "RepaidToAave")
        .withArgs(amount);
    });
  });

  describe("Admin Operations", function () {
    it("Should update destination chain ID", async function () {
      const newChainId = 456;
      await strategy.setDestinationChainId(newChainId);
      expect(await strategy.destinationChainId()).to.equal(newChainId);
    });

    it("Should fail if non-admin tries to update chain ID", async function () {
      await expect(
        strategy.connect(manager).setDestinationChainId(456)
      ).to.be.revertedWith(/AccessControl: account .* is missing role .*/);
    });
  });
}); 