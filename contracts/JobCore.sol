// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

error JobCore__NotSupportedToken();

contract JobCore {
    enum Stage {
        SCREENING,
        FIRST_INTERVIEW,
        TECHNICAL_TEST,
        FINAL_INTERVIEW,
        HIRED,
        REJECTED
    }

    struct Bounty {
        IERC20 token;
        uint256 amount;
    }

    struct Job {
        bytes32 jobId;
        address employer;
        address[] applicants;
        Bounty bounty;
        bool status;
    }

    bytes32[] public JobIds;
    mapping(bytes32 => Job) public Jobs;
    mapping(address => mapping(bytes32 => Stage[2])) public Applicants;
    mapping(address => bytes32[]) public Employers;
    mapping(address => mapping(IERC20 => uint256)) public ERC20BountyBalances;
    
    address public readonly aavePoolAddress; //Lending Pool address for the Aave v3
    address public readonly aaveWethGatewayAddress; // //IWETHGateway interface in case we don't have an erc20 token from employer, we can still use ETH
    address public readonly aWethAddress; //Contract Address for the aWeth tokens generated after depositing ETH to keep track of the amount deposited in lending pool
    mapping(bytes32 => address) private readonly erc20ToAaveTokenAddresses; // map token.symbol with aERC20Token address => USDT,USDC,DAI,EURS

    constructor(address _aavePoolAddress, address _aWethAddress, address _aaveWethGatewayAddress, address _aaveUsdcAddress, address _aaveUsdtAddress, address _aaveEurAddress, address _aaveDaiAddress) {
        aavePoolAddress = _aavePoolAddress);
        aaveWethGatewayAddress = _aaveWethGatewayAddress;
        aWethAddress = _aWethAddress;
        erc20ToAaveTokenAddresses["USDC"] = _aaveUsdcAddress;
        erc20ToAaveTokenAddresses["USDT"] = _aaveUsdtAddress;
        erc20ToAaveTokenAddresses["EURS"] = _aaveEurAddress;
        erc20ToAaveTokenAddresses["DAI"] = _aaveDaiAddress;
    }

    function collectBounty(amount, address token) internal returns (bool) {
        if(address(token) == address(0)) {
            // Use WETHGateway to directly deposit eth
            IWETHGateway(aaveWethGatewayAddress).depositETH{value: amount}(aavePoolAddress, address(this), 0);
           return true;
        }
        string memory _symbol = ERC20(token).symbol();
        if(_symbol != "USDT" && _symbol != "EURS" && _symbol != "USDC" && _symbol != "DAI") {
            revert JobCore__NotSupportedToken();
        }
        address erc20ToAaveTokenAddress = erc20ToAaveTokenAddresses[_symbol];
        // 1. Approve Aave pool to access amount from this contract 
        IERC20(erc20ToAaveTokenAddress).approve(aavePoolAddress, amount);

        // 2. Supply amount to Aave pool
        IPool(aavePoolAddress).supply(erc20ToAaveTokenAddress, amount, 2, 0, address(this));
        return true;

    }    

    function withdrawBounty(amount, address token) internal returns (bool) {
        if(address(token) == address(0)) {
            //Withdraw lended funds via the Weth Gateway
            //It will convert back the WETH to ETH and send it to the contract
            //Ensure you set the relevant ERC20 allowance of aWETH, before calling
            IERC20(aWethAddress).approve(address(aaveWethGatewayAddress), amount);
            IWETHGateway(aaveWethGatewayAddress).withdrawETH(aavePoolAddress, amount, address(this));
           return true;
        }
        string memory _symbol = ERC20(token).symbol();
        if(_symbol != "USDT" && _symbol != "EURS" && _symbol != "USDC" && _symbol != "DAI") {
            revert JobCore__NotSupportedToken();
        }
        address erc20ToAaveTokenAddress = erc20ToAaveTokenAddresses[_symbol];
        // Withdraw the bounty to this address before 
        IPool(aavePoolAddress).withdraw(erc20ToAaveTokenAddress, amount, address(this));

        return true;
    }
