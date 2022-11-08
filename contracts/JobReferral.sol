// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./JobCore.sol"; 

contract JobReferral is JobCore { 
    constructor(address _aavePoolAddressRegistryAddress, address _aaveWethGatewayAddress, address _aWethGatewayAddress) JobCore(_aavePoolAddressRegistryAddress, _aaveWethGatewayAddress, _aWethGatewayAddress) {
    }
}