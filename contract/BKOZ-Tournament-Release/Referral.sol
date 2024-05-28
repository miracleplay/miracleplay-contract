// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ReferralSystem {
    // 기본 주소 (default address)
    address public defaultReferrer;

    // Mapping from user address to referrer address
    mapping(address => address) private _referrals;

    // Event to log new referrals
    event ReferralSet(address indexed user, address indexed referrer);
    event DefaultReferrerChanged(address indexed oldReferrer, address indexed newReferrer);

    constructor(address _defaultReferrer) {
        require(_defaultReferrer != address(0), "Default referrer cannot be the zero address");
        defaultReferrer = _defaultReferrer;
    }

    // Function to set a referrer for the caller
    function setReferrer(address referrer) external {
        require(referrer != address(0), "Referrer cannot be the zero address");
        require(referrer != msg.sender, "You cannot refer yourself");
        require(_referrals[msg.sender] == address(0), "Referrer already set");

        // Set the referrer
        _referrals[msg.sender] = referrer;

        // Emit the referral set event
        emit ReferralSet(msg.sender, referrer);
    }

    // Function to get the referrer of a user
    function getReferrer(address user) public view returns (address) {
        address referrer = _referrals[user];
        if (referrer == address(0)) {
            return defaultReferrer;
        }
        return referrer;
    }

    // Function to change the default referrer
    function setDefaultReferrer(address _newDefaultReferrer) external {
        require(_newDefaultReferrer != address(0), "Default referrer cannot be the zero address");
        address oldReferrer = defaultReferrer;
        defaultReferrer = _newDefaultReferrer;
        emit DefaultReferrerChanged(oldReferrer, _newDefaultReferrer);
    }
}
