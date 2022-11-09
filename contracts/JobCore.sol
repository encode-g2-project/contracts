// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

error JobCore__NotSupportedToken();

interface IWETHGateway {
    function depositETH(
        address lendingPool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable;

    function withdrawETH(
        address lendingPool,
        uint256 amount,
        address onBehalfOf
    ) external;
}

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
    uint256 public JobIdsLength;
    mapping(bytes32 => Job) public Jobs;
    mapping(bytes32 => uint256) public Hired;
    mapping(address => mapping(bytes32 => Stage[2])) public Applicants;
    mapping(address => mapping(bytes32 => bool)) public AlreadyClaimed;
    mapping(address => bytes32[]) public MyApplications;
    uint256 public MyApplicationsLength;
    mapping(address => bytes32[]) public Employers;
    uint256 public EmployersLength;
    mapping(address => mapping(IERC20 => uint256)) public ERC20BountyBalances;

    function getMyJobs(address employer)
        external
        view
        returns (bytes32[] memory)
    {
        return Employers[employer];
    }

    function getMyApplications(address applicant)
        external
        view
        returns (bytes32[] memory)
    {
        return MyApplications[applicant];
    }

    function canClaimBounty(address applicant, bytes32 jobId)
        external
        view
        returns (bool)
    {
        return
            (Applicants[applicant][jobId])[0] == Stage.REJECTED &&
            (Applicants[applicant][jobId])[1] == Stage.FINAL_INTERVIEW &&
            !Jobs[jobId].status &&
            !AlreadyClaimed[applicant][jobId];
    }

    address public immutable aavePoolAddress; //Lending Pool address for the Aave v3
    IPoolAddressesProvider private immutableAavePoolAddressRegistry;
    address public immutable aaveWethGatewayAddress; // //IWETHGateway interface in case we don't have an erc20 token from employer, we can still use ETH
    address public immutable aWethTokenAddress; //Contract Address for the aWeth tokens generated after depositing ETH to keep track of the amount deposited in lending pool

    constructor(
        address _aavePoolAddressRegistryAddress,
        address _aaveWethGatewayAddress,
        address _aWethTokenAddress
    ) {
        aavePoolAddress = IPoolAddressesProvider(
            _aavePoolAddressRegistryAddress
        ).getPool();
        aaveWethGatewayAddress = _aaveWethGatewayAddress;
        aWethTokenAddress = _aWethTokenAddress;
    }

    function collectBounty(address token, uint256 amount)
        internal
        returns (bool)
    {
        if (token == address(0)) {
            // Use WETHGateway to directly deposit eth
            IWETHGateway(aaveWethGatewayAddress).depositETH{value: amount}(
                aavePoolAddress,
                address(this),
                0
            );
            return true;
        }
        string memory _symbol = ERC20(token).symbol();
        if (
            !isEqualStrings(_symbol, "USDT") &&
            !isEqualStrings(_symbol, "EURS") &&
            !isEqualStrings(_symbol, "USDC") &&
            !isEqualStrings(_symbol, "DAI")
        ) {
            revert JobCore__NotSupportedToken();
        }
        // 1. Approve Aave pool to access amount from this contract
        IERC20(token).approve(aavePoolAddress, amount);

        // 2. Supply amount to Aave pool
        IPool(aavePoolAddress).supply(token, amount, address(this), 0);
        return true;
    }

    function withdrawBounty(address token, uint256 amount)
        internal
        returns (bool)
    {
        if (token == address(0)) {
            //Withdraw lended funds via the Weth Gateway
            //It will convert back the WETH to ETH and send it to the contract
            //Ensure you set the relevant ERC20 allowance of aWETH, before calling
            IERC20(aWethTokenAddress).approve(
                address(aaveWethGatewayAddress),
                amount
            );
            IWETHGateway(aaveWethGatewayAddress).withdrawETH(
                aavePoolAddress,
                amount,
                address(this)
            );
            return true;
        }
        string memory _symbol = ERC20(token).symbol();
        if (
            !isEqualStrings(_symbol, "USDT") &&
            !isEqualStrings(_symbol, "EURS") &&
            !isEqualStrings(_symbol, "USDC") &&
            !isEqualStrings(_symbol, "DAI")
        ) {
            revert JobCore__NotSupportedToken();
        }
        // Withdraw the bounty to this address before
        IPool(aavePoolAddress).withdraw(token, amount, address(this));

        return true;
    }

    function isEqualStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
