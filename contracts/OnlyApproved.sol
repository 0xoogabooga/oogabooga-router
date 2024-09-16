// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

abstract contract OnlyApproved {
    error NotApprovedAddress(address caller);

    mapping(address => bool) private approvedAddresses;

    modifier onlyApproved() {
        if (!approvedAddresses[msg.sender]) {
            revert NotApprovedAddress(msg.sender);
        }
        _;
    }

    function _addApprovedAddress(address _address) internal {
        approvedAddresses[_address] = true;
    }

    function _removeApprovedAddress(address _address) internal {
        approvedAddresses[_address] = false;
    }

    function isApproved(address _address) external view returns (bool) {
        return approvedAddresses[_address];
    }
}
