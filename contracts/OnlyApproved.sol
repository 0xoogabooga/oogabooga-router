// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

abstract contract OnlyApproved {
    error NotApprovedAddress(address caller);

    mapping(address => bool) private approved;

    modifier onlyApproved() {
        if (!approved[msg.sender]) {
            revert NotApprovedAddress(msg.sender);
        }
        _;
    }

    function _addApprovedAddress(address _address) internal {
        approved[_address] = true;
    }

    function _removeApprovedAddress(address _address) internal {
        approved[_address] = false;
    }

    function isApproved(address _address) external view returns (bool) {
        return approved[_address];
    }
}
