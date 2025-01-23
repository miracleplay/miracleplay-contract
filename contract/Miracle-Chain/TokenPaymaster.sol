// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";


contract TokenPaymaster is IPaymaster, PermissionsEnumerable, Multicall {
    IEntryPoint public immutable entryPoint;
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public userGasLimits;
    
    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external virtual override returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Sender not EntryPoint");
        require(userGasLimits[userOp.sender] >= maxCost, "Gas limit exceeded");
        
        return (abi.encode(userOp.sender), 0);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external override {
        require(msg.sender == address(entryPoint), "Sender not EntryPoint");
        
        address sender = abi.decode(context, (address));
        userGasLimits[sender] -= actualGasCost;
    }

    function addSupportedToken(address token) external onlyRole(FACTORY_ROLE) {
        supportedTokens[token] = true;
    }

    function setUserGasLimit(address user, uint256 limit) external onlyRole(FACTORY_ROLE) {
        userGasLimits[user] = limit;
    }

    function deposit() public payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    function withdrawTo(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        entryPoint.withdrawTo(to, amount);
    }

    function getDeposit() public view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    function existsUserGasLimit(address user) external view returns (bool) {
        return userGasLimits[user] > 0;
    }
}
