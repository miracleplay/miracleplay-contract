// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//       

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TokenWithdraw {
    address public admin;
    address public tokenAddress;
    uint256 public tokenAmount;
    address public depositor;

    mapping (address => uint256) public withdrawPercentages;
    mapping (address => uint256) public withdrawAmounts;

    constructor(address _tokenAddress, uint256 _tokenAmount, address _depositor, uint256 _initialDepositAmount) {
        admin = msg.sender;
        tokenAddress = _tokenAddress;
        tokenAmount = _tokenAmount;
        depositor = _depositor;
        deposit(_initialDepositAmount);
    }

    function updateWithdrawals(address[] memory _withdrawAddresses, uint256[] memory _percentages) public {
        require(msg.sender == admin, "Only the admin can update withdrawals.");
        require(_withdrawAddresses.length == _percentages.length, "Arrays must be the same length.");
        uint256 totalPercentage;
        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            withdrawPercentages[_withdrawAddresses[i]] = _percentages[i];
            totalPercentage += _percentages[i];
        }
        require(totalPercentage == 100, "Total percentage must equal 100.");
    }

    function deposit(uint256 _amount) public {
        require(msg.sender == depositor, "Only the depositor can deposit tokens.");
        require(tokenAmount + _amount <= IERC20(tokenAddress).balanceOf(depositor), "Insufficient balance.");

        IERC20 token = IERC20(tokenAddress);
        require(token.allowance(depositor, address(this)) >= _amount, "Allowance is not sufficient.");
        require(token.transferFrom(depositor, address(this), _amount), "Transfer failed.");

        tokenAmount += _amount;
    }

    function withdraw() public {
        require(withdrawPercentages[msg.sender] > 0, "You are not authorized to withdraw tokens.");
        require(withdrawAmounts[msg.sender] < tokenAmount, "All tokens have been withdrawn.");

        IERC20 token = IERC20(tokenAddress);
        uint256 withdrawAmount = token.balanceOf(address(this)) * withdrawPercentages[msg.sender] / 100;
        require(token.allowance(depositor, address(this)) >= withdrawAmount, "Allowance is not sufficient.");
        require(token.transferFrom(depositor, msg.sender, withdrawAmount), "Transfer failed.");

        withdrawAmounts[msg.sender] += withdrawAmount;
    }
}
