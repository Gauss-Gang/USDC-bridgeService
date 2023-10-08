const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('GUDStable Contract Tests', function () {
  let gudStable;
  let mockStableCoin;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const MockStableCoin = await ethers.getContractFactory('MockStableCoin');
    const GUDStable = await ethers.getContractFactory('GUDStable');

    mockStableCoin = await MockStableCoin.deploy();
    gudStable = await GUDStable.deploy(mockStableCoin.getAddress());

    return {mockStableCoin, gudStable, owner, addr1, addr2};
  });


  it('Should deploy the contract correctly', async function () {
    expect(await gudStable.name()).to.equal('Gauss Stable');
    expect(await gudStable.symbol()).to.equal('GUD');
    expect(await gudStable.decimals()).to.equal(6);
  });


  it('Should initialize the contract correctly on Gauss Mainnet', async function () {
    // Call init with addr1 as the bridge address
    await gudStable.init(addr1.address);

    // Check if the contract correctly identifies the chain as Gauss
    expect((await ethers.provider.getNetwork()).chainId).to.equal(1777);
    expect(await gudStable._isGauss()).to.equal(true);
    expect(await gudStable.gudBridge()).to.equal(addr1.address);
    expect(await gudStable._initialized()).to.equal(true);
  });


  it('Should initialize the contract correctly on Polygon', async function () {
    // Call init with addr1 as the bridge address
    await gudStable.init(addr1.address);

    // Check if the contract correctly identifies the chain as Polygon
    expect(await gudStable._isGauss()).to.equal(false);
    expect(await gudStable.gudBridge()).to.equal(addr1.address);
    expect(await gudStable._initialized()).to.equal(true);
  });


  it('Should test token approval and transferFrom', async function () {
    await gudStable.init(addr1.address);
    await gudStable.connect(addr1).mint(owner.address, ethers.parseEther('100'));
    
    const spender = addr1.address;

    const amountToApprove = ethers.parseEther('100');
    const transferAmount = ethers.parseEther('50');
  
    await gudStable.approve(spender, amountToApprove);
    expect(await gudStable.allowance(owner.address, spender)).to.equal(amountToApprove);
  
    await gudStable.connect(addr1).transferFrom(owner.address, addr2.address, transferAmount);
    expect(await gudStable.balanceOf(addr2.address)).to.equal(transferAmount);
  });


  it('Should test event emission for token transfers', async function () {
    await gudStable.init(addr1.address);
    await gudStable.connect(addr1).mint(owner.address, ethers.parseEther('10'));

    const amountToTransfer = ethers.parseEther('10');
  
    const transferTx = await gudStable.transfer(addr1.address, amountToTransfer);
  
    expect(transferTx.events[0].event).to.equal('Transfer');
    expect(transferTx.events[0].args.from).to.equal(owner.address);
    expect(transferTx.events[0].args.to).to.equal(addr1.address);
    expect(transferTx.events[0].args.value).to.equal(amountToTransfer);
  });


  it('Should pause and unpause token trading', async function () {
    await gudStable.pause();
    expect(await gudStable.paused()).to.equal(true);

    await gudStable.unpause();
    expect(await gudStable.paused()).to.equal(false);
  });


  it('Should test event emission for pause and unpause', async function () {
    const pauseTx = await gudStable.pause();
    await pauseTx.wait();
  
    // Check if the 'Paused' event was emitted
    const pauseEvents = await gudStable.queryFilter('Paused');
    expect(pauseEvents.length).to.equal(1); // Ensure one 'Paused' event was emitted
    expect(pauseEvents[0].args).to.deep.equal([owner.address]);
  
    const unpauseTx = await gudStable.unpause();
    await unpauseTx.wait();
  
    // Check if the 'Unpaused' event was emitted
    const unpauseEvents = await gudStable.queryFilter('Unpaused');
    expect(unpauseEvents.length).to.equal(1); // Ensure one 'Unpaused' event was emitted
    expect(unpauseEvents[0].args).to.deep.equal([owner.address]);
  });


  it('Should reject unauthorized address for pausing and unpausing', async function () {
    const unauthorizedAddress = addr2;
  
    // Unauthorized address tries to pause
    await expect(gudStable.connect(unauthorizedAddress).pause())
      .to.be.revertedWith('Ownable: caller is not the owner');
  
    // Unauthorized address tries to unpause
    await expect(gudStable.connect(unauthorizedAddress).unpause())
      .to.be.revertedWith('Ownable: caller is not the owner');
  });


  it('Should mint and burn GUD tokens', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address

    await gudStable.connect(addr1).mint(addr1.address, ethers.parseEther('100'));
    expect(await gudStable.balanceOf(addr1.address)).to.equal(ethers.parseEther('100'));

    await gudStable.connect(addr1).burn(ethers.parseEther('25'));
    expect(await gudStable.balanceOf(addr1.address)).to.equal(ethers.parseEther('75'));
  });


  it('Should reject unauthorized mint and burn attempts', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address
    const unauthorizedAddress = addr2;
  
    // Unauthorized address tries to mint
    await expect(gudStable.connect(unauthorizedAddress).mint(addr2.address, ethers.parseEther('50')))
      .to.be.revertedWith('Address not authorized');
  
    // Unauthorized address tries to burn
    await gudStable.connect(addr1).mint(unauthorizedAddress.address, ethers.parseEther('50'));
    await expect(gudStable.connect(unauthorizedAddress).burn(ethers.parseEther('50')))
      .to.be.revertedWith('Address not authorized');
  });


  it('Should update the GUD Bridge address', async function () {
    await gudStable.init(addr1.address);
    const newBridgeAddress = addr2.address;
    await gudStable.updateBridge(newBridgeAddress);
    expect(await gudStable.gudBridge()).to.equal(newBridgeAddress);
  });


  it('Should not allow unauthorized address to update bridge', async function () {
    await gudStable.init(addr1.address);
    const unauthorizedAddress = addr2;
    await expect(gudStable.connect(unauthorizedAddress).updateBridge(unauthorizedAddress.address))
      .to.be.revertedWith('Ownable: caller is not the owner');
  });


  it('Should deposit stable tokens and mint wrapped tokens', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address
    
    const amountToDeposit = ethers.parseEther('100');
    await mockStableCoin.mint(addr1.address, amountToDeposit);
    const initialStableBalance = await mockStableCoin.balanceOf(addr1.address);
    
    // Approve the GUDStable contract to spend stable tokens on behalf of addr1
    await mockStableCoin.connect(addr1).approve(gudStable.getAddress(), amountToDeposit);

    // Deposit stable tokens for addr1
    await gudStable.connect(addr1).depositFor(addr1.address, amountToDeposit);

    const finalStableBalance = await mockStableCoin.balanceOf(addr1.address);
    const wrappedBalance = await gudStable.balanceOf(addr1.address);

    // Check if the stable token balance decreased and wrapped balance increased
    expect(initialStableBalance).to.equal(amountToDeposit);
    expect(finalStableBalance).to.equal(0);
    expect(wrappedBalance).to.equal(amountToDeposit);
  });


  it('Should not allow bridge to mint on non-Gauss chain', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address
  
    // Try to mint on a non-Gauss chain
    await expect(gudStable.connect(addr1).mint(addr1.address, ethers.parseEther('50')))
      .to.be.revertedWith('Minting only supported on the Gauss Chain');
  });


  it('Should withdraw stable tokens and burn wrapped tokens', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address

    const amountToDeposit = ethers.parseEther('100');
    await mockStableCoin.mint(addr1.address, amountToDeposit);
    const initialStableBalance = await mockStableCoin.balanceOf(addr1.address);

    // Approve the GUDStable contract to spend stable tokens on behalf of addr1
    await mockStableCoin.connect(addr1).approve(gudStable.getAddress(), amountToDeposit);

    // Deposit stable tokens for addr1
    await gudStable.connect(addr1).depositFor(addr1.address, amountToDeposit);

    const wrappedBalance = await gudStable.balanceOf(addr1.address);
    expect(wrappedBalance).to.equal(amountToDeposit);

    const intermediateStableBalance = await mockStableCoin.balanceOf(addr1.address);

    // Withdraw stable tokens for addr1
    await gudStable.connect(addr1).withdrawTo(addr1.address, wrappedBalance);

    const finalStableBalance = await mockStableCoin.balanceOf(addr1.address);

    // Check if the stable token balance is restored after withdrawal
    expect(initialStableBalance).to.equal(amountToDeposit);
    expect(intermediateStableBalance).to.equal(0);
    expect(finalStableBalance).to.equal(amountToDeposit);
    expect(await gudStable.balanceOf(addr1.address)).to.equal(0);
  });


  it('Should not allow withdrawal if no tokens are deposited', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address

    // Try to withdraw when no tokens are deposited
    await expect(gudStable.connect(addr1).withdrawTo(addr1.address, ethers.parseEther('1')))
      .to.be.revertedWith('ERC20: burn amount exceeds balance');
  });


  it('Should not allow withdrawal of more wrapped tokens than deposited', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address

    const amountToDeposit = ethers.parseEther('100');
    await mockStableCoin.mint(addr1.address, amountToDeposit);
    const initialStableBalance = await mockStableCoin.balanceOf(addr1.address);

    // Approve the GUDStable contract to spend stable tokens on behalf of addr1
    await mockStableCoin.connect(addr1).approve(gudStable.getAddress(), amountToDeposit);

    // Deposit stable tokens for addr1
    await gudStable.connect(addr1).depositFor(addr1.address, amountToDeposit);

    const intermediateStableBalance = await mockStableCoin.balanceOf(addr1.address);
    const wrappedBalance = await gudStable.balanceOf(addr1.address);

    // Try to withdraw more wrapped tokens than deposited
    await expect(gudStable.connect(addr1).withdrawTo(addr1.address, ethers.parseEther('110')))
      .to.be.revertedWith('ERC20: burn amount exceeds balance');

    // Check if the stable token balance is not affected
    expect(initialStableBalance).to.equal(amountToDeposit);
    expect(wrappedBalance).to.equal(amountToDeposit);
    expect(await gudStable.balanceOf(addr1.address)).to.equal(amountToDeposit);
  });


  it('Should reject malicious withdrawal amounts', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address
    const amountToDeposit = ethers.parseEther('100');
    await mockStableCoin.mint(addr1.address, amountToDeposit);

    // Deposit stable tokens for addr1
    await mockStableCoin.connect(addr1).approve(gudStable.getAddress(), amountToDeposit);
    await gudStable.connect(addr1).depositFor(addr1.address, amountToDeposit);

    // Try to withdraw a negative amount
    await expect(gudStable.connect(addr1).withdrawTo(addr1.address, ethers.parseEther('-1')))
      .to.be.revertedWith('ERC20: burn amount exceeds balance');

    // Try to withdraw an excessive amount
    await expect(gudStable.connect(addr1).withdrawTo(addr1.address, ethers.parseEther('101')))
      .to.be.revertedWith('ERC20: burn amount exceeds balance');
  });


  it('Should recover accidentally sent native tokens', async function () {
    // Send some ETH to the GUDStable contract
    const ethToSend = ethers.parseEther('1');
    await owner.sendTransaction({
        to: gudStable.getAddress(),
        value: ethToSend,
    });

    const balanceAfterTransfer = await ethers.provider.getBalance(gudStable.getAddress());

    await gudStable.nativeRecover(owner.address);

    const finalBalance = await ethers.provider.getBalance(gudStable.getAddress());

    expect(balanceAfterTransfer).to.above(0);
    expect(finalBalance).to.equal(0);
  });



  it('Should recover stable tokens in an emergency', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address

    // Mint some stable tokens in the mock stable coin contract
    const amountToDeposit = ethers.parseEther('100');
    await mockStableCoin.mint(addr1.address, amountToDeposit);

    const initialBalance = await mockStableCoin.balanceOf(addr1.address);

    await gudStable.emergencyRecover(addr1.address);

    const finalBalance = await mockStableCoin.balanceOf(gudStable.getAddress());

    // Ensure addr1 received the stable tokens
    expect(initialBalance).to.above(0);
    expect(finalBalance).to.equal(0);
  });


  it('Should not allow emergency recovery on Gauss chain', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address
  
    // Try to perform emergency recovery on Gauss chain
    await expect(gudStable.emergencyRecover(addr1.address))
      .to.be.revertedWith('Recovering only supported on the \'Away\' Chain');
  });


  it('Should allow accidental recovery of wrapped tokens', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address

    await mockStableCoin.mint(gudStable.getAddress(), ethers.parseEther('50'));
    const initialBalance = await mockStableCoin.balanceOf(gudStable.getAddress());

    await gudStable.accidentalRecover(addr1.address);

    // Ensure the account received the wrapped tokens
    expect(initialBalance).to.equal(ethers.parseEther('50'));
    expect(await gudStable.balanceOf(addr1.address)).to.equal(ethers.parseEther('50'))
  });


  it('Should not allow accidental recovery from non Owner Wallet', async function () {
    // Try to perform accidental recovery on a non-Gauss chain
    await expect(gudStable.connect(addr1).accidentalRecover(addr1.address))
      .to.be.revertedWith('Ownable: caller is not the owner');
  });


  it('Should change ownership correctly', async function () {
    await gudStable.transferOwnership(addr1.address);
    expect(await gudStable.owner()).to.equal(addr1.address);
  });


  it('Should transfer ownership and ensure the new owner can update the bridge', async function () {
    const newOwner = addr2;
  
    // Transfer ownership to a new address
    await gudStable.transferOwnership(newOwner.address);
  
    // Ensure the new owner has ownership
    expect(await gudStable.owner()).to.equal(newOwner.address);
  
    // The new owner updates the bridge address
    const newBridgeAddress = addr1.address;
    await gudStable.connect(newOwner).updateBridge(newBridgeAddress);
  
    expect(await gudStable.gudBridge()).to.equal(newBridgeAddress);
  });


  it('Should emit events for mint and burn operations', async function () {
    await gudStable.init(addr1.address); // Use addr1 as the bridge address
    const amountToMint = ethers.parseEther('50');

    // Mint GUD tokens
    const mintTx = await gudStable.connect(addr1).mint(addr1.address, amountToMint);
    await mintTx.wait();

    expect(mintTx.events[0].event).to.equal('Transfer');
    expect(mintTx.events[0].args.from).to.equal('0x0000000000000000000000000000000000000000');
    expect(mintTx.events[0].args.to).to.equal(addr1.address);
    expect(mintTx.events[0].args.value).to.equal(amountToMint);

    // Burn GUD tokens
    const burnTx = await gudStable.connect(addr1).burn(amountToMint);
    await burnTx.wait();

    expect(burnTx.events[0].event).to.equal('Transfer');
    expect(burnTx.events[0].args.from).to.equal(addr1.address);
    expect(burnTx.events[0].args.to).to.equal('0x0000000000000000000000000000000000000000');
    expect(burnTx.events[0].args.value).to.equal(amountToMint);
  });
});