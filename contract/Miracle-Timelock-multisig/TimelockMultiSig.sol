// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract TimelockMultiSig is AccessControl, ContractMetadata {
    address public deployer;
    bytes32 public constant MULTISIG_ADMIN_ROLE = keccak256("MULTISIG_ADMIN_ROLE");
    bytes32 public constant SUBMIT_ROLE = keccak256("SUBMIT_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    uint256 public required;
    TimelockController public timelock;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    Transaction[] public transactions;

    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);
    event ScheduledTransactionExecuted(address indexed to, uint256 value, bytes data);

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required, address payable _timelock, string memory _contractURI) {
        require(_owners.length > 0, "There must be at least one owner");
        require(_required > 0 && _required <= _owners.length, "Invalid number of required confirmations");
        require(_timelock != address(0), "invalid timelock address");

        _setRoleAdmin(MULTISIG_ADMIN_ROLE, MULTISIG_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, MULTISIG_ADMIN_ROLE);
        _setRoleAdmin(SUBMIT_ROLE, MULTISIG_ADMIN_ROLE);

        _grantRole(MULTISIG_ADMIN_ROLE, address(this));

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");

            _grantRole(SUBMIT_ROLE, owner);
        }

        required = _required;
        timelock = TimelockController(_timelock);
        _grantRole(EXECUTOR_ROLE, _timelock);
        deployer = msg.sender;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data)
        public
        onlyRole(SUBMIT_ROLE)
    {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyRole(SUBMIT_ROLE)
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex, uint256 salt)
        public
        onlyRole(SUBMIT_ROLE)
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= required,
            "cannot execute tx"
        );

        bytes memory data = abi.encodeWithSignature(
            "executeScheduledTransaction(address,uint256,bytes)",
            transaction.to,
            transaction.value,
            transaction.data
        );

        timelock.schedule(
            address(this),
            0,
            data,
            bytes32(0),
            bytes32(salt),
            timelock.getMinDelay()
        );

        transaction.executed = true;
        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function getSalt(uint256 salt) public pure returns (bytes32)
    {
        return bytes32(salt);
    }
    

    function updateRequired(uint256 _required)
        public
        onlyRole(MULTISIG_ADMIN_ROLE)
    {
        required = _required;
    }

    function executeScheduledTransaction(address _to, uint256 _value, bytes memory _data)
        public
        onlyRole(EXECUTOR_ROLE)
    {
        (bool success, ) = _to.call{value: _value}(_data);
        require(success, "tx failed");
        emit ScheduledTransactionExecuted(_to, _value, _data);
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations)
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
