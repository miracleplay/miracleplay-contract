// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FundingContract is Ownable {
    IERC20 public fundingToken;
    address public escrowAddress;
    uint256 public fundingUnit;
    uint256 public fundingGoal;
    uint256 public startTime;
    uint256 public endTime;
    string public fundingContentIPFS;
    uint256 public fundingId;

    mapping(address => uint256) public contributions;
    address[] public contributors;

    event Funded(address contributor, uint256 amount);
    event FundingEnded(uint256 totalAmount);
    event FundingCancelled();

    constructor(
        uint256 _fundingId,
        string memory _fundingContentIPFS,
        address _fundingTokenAddress,
        address _escrowAddress,
        uint256 _fundingUnit,
        uint256 _fundingGoal,
        uint256 _startTime,
        uint256 _endTime
    ) {
        fundingId = _fundingId;
        fundingContentIPFS = _fundingContentIPFS;
        fundingToken = IERC20(_fundingTokenAddress);
        escrowAddress = _escrowAddress;
        fundingUnit = _fundingUnit;
        fundingGoal = _fundingGoal;
        startTime = _startTime;
        endTime = _endTime;
    }

    function fund(uint256 amount) public {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Funding not active");
        uint256 fundingAmount = amount * fundingUnit;
        fundingToken.transferFrom(msg.sender, address(this), fundingAmount);
        contributions[msg.sender] += fundingAmount;
        contributors.push(msg.sender);
        emit Funded(msg.sender, fundingAmount);
    }

    function endFunding() public onlyOwner {
        require(block.timestamp > endTime, "Funding not ended");
        uint256 totalAmount = fundingToken.balanceOf(address(this));
        fundingToken.transfer(escrowAddress, totalAmount);
        emit FundingEnded(totalAmount);
    }

    function cancelFunding() public onlyOwner {
        for (uint i = 0; i < contributors.length; i++) {
            fundingToken.transfer(contributors[i], contributions[contributors[i]]);
        }
        emit FundingCancelled();
    }

    function getFundingStatus() public view returns (uint256) {
        return fundingToken.balanceOf(address(this));
    }

    function getContributors() public view returns (address[] memory, uint256[] memory) {
        uint256[] memory amounts = new uint256[](contributors.length);
        for (uint i = 0; i < contributors.length; i++) {
            amounts[i] = contributions[contributors[i]];
        }
        return (contributors, amounts);
    }
}
