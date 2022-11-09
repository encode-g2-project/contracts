// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

error Web3Jobs__NotSupportedToken();

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

contract Web3Jobs {
    event BountyClaimed(
        bytes32 indexed jobId,
        address indexed applicant,
        uint256 indexed amount,
        bool isEther
    );

    event JobPublished(
        bytes32 indexed jobId,
        address indexed employer,
        uint256 indexed bountyAmount
    );
    event JobUnpublished(bytes32 indexed jobId, address indexed employer);

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

    function publishJob(
        bytes32 jobId,
        uint256 bountyAmount,
        IERC20 token
    ) external payable {
        uint256 amount;

        if (msg.value != 0) {
            require(
                bountyAmount == 0 && token == IERC20(address(0)),
                "Only a single currency can be used for bounty"
            );
            amount = msg.value;
        } else {
            require(
                bountyAmount != 0 && token != IERC20(address(0)),
                "Wrong amount or token provided for bounty"
            );

            amount = bountyAmount;
            require(
                token.transferFrom(msg.sender, address(this), bountyAmount),
                "Failed to send ERC20 bounty to contract for custody"
            );
            ERC20BountyBalances[msg.sender][token] += bountyAmount;
        }

        JobIds.push(jobId);
        JobIdsLength += 1;

        address[] memory applicants;
        Bounty memory bounty = Bounty(token, amount);
        Jobs[jobId] = Job(jobId, msg.sender, applicants, bounty, true);

        Employers[msg.sender].push(jobId);
        EmployersLength += 1;
        // Supply bounty amount on AAVE
        collectBounty(address(bounty.token), bounty.amount);

        emit JobPublished(jobId, msg.sender, amount);
    }

    function unpublishJob(bytes32 jobId) external {
        require(
            Jobs[jobId].employer == msg.sender,
            "Offer doesn't exist or you're not the employer"
        );

        Bounty memory bounty = Jobs[jobId].bounty;

        if (bounty.token == IERC20(address(0))) {
            (bool sent, ) = msg.sender.call{value: bounty.amount}("");
            require(sent, "Failed to send Ether bounty to employer");
        } else {
            ERC20BountyBalances[msg.sender][bounty.token] -= bounty.amount;
            require(
                (bounty.token).transfer(msg.sender, bounty.amount),
                "Failed to send ERC20 bounty to employer"
            );
        }

        JobIdsLength -= 1;

        delete Jobs[jobId];
        emit JobUnpublished(jobId, msg.sender);
    }

    function newApplication(bytes32 jobId) public {
        require(
            !applicantExists(jobId) && Jobs[jobId].status,
            "You have already made an application or application is not open yet"
        );
        Jobs[jobId].applicants.push(msg.sender);

        Stage[2] memory stage;
        stage[0] = Stage.SCREENING;
        Applicants[msg.sender][jobId] = stage;
        MyApplications[msg.sender].push(jobId);
        MyApplicationsLength += 1;
    }

    function getMyApplicants(bytes32 jobId)
        external
        view
        returns (address[] memory)
    {
        return Jobs[jobId].applicants;
    }

    function changeApplicationStatus(
        address applicant,
        bytes32 jobId,
        uint8 status
    ) external {
        require(
            Jobs[jobId].employer == msg.sender,
            "Offer doesn't exist or you're not the employer"
        );
        (Applicants[applicant][jobId])[1] = (Applicants[applicant][jobId])[0];
        (Applicants[applicant][jobId])[0] = Stage(status);
        if (status == 4) {
            Hired[jobId] += 1;
        }
    }

    function closeJobOffer(bytes32 jobId) external {
        require(
            Jobs[jobId].employer == msg.sender,
            "Offer doesn't exist or you're not the employer"
        );
        Jobs[jobId].status = false;
    }

    function getAaveBalance() external view returns (uint256) {
        return IERC20(aWethTokenAddress).balanceOf(address(this));
    }

    function claimBounty(bytes32 jobId) external {
        require(
            (Applicants[msg.sender][jobId])[0] == Stage.REJECTED &&
                (Applicants[msg.sender][jobId])[1] == Stage.FINAL_INTERVIEW &&
                !Jobs[jobId].status,
            "Not eligible for claiming bounty"
        );
        require(!AlreadyClaimed[msg.sender][jobId], "You've already claimed");

        bool isEther;
        Bounty memory bounty = Jobs[jobId].bounty;

        uint256 numberOfEligible = getEligibles(jobId);
        uint256 bountySlice = bounty.amount / numberOfEligible;

        // Withdraw bountySlice from aave to pay back on msg.sender
        withdrawBounty(address(bounty.token), bountySlice);
        if (bounty.token == IERC20(address(0))) {
            (bool success, ) = msg.sender.call{value: bountySlice}("");
            require(success, "Failed to send Ether bounty slice to applicant");
            isEther = true;
        } else {
            address employer = Jobs[jobId].employer;
            ERC20BountyBalances[employer][bounty.token] -= bountySlice;
            require(
                (bounty.token).transfer(msg.sender, bountySlice),
                "Failed to send ERC20 bounty slice to applicant"
            );
        }

        AlreadyClaimed[msg.sender][jobId] = true;
        emit BountyClaimed(jobId, msg.sender, bountySlice, isEther);
    }

    function applicantExists(bytes32 jobId) internal view returns (bool) {
        address[] memory applicants = Jobs[jobId].applicants;
        for (uint256 i; i < applicants.length; i++) {
            if (applicants[i] == msg.sender) return true;
        }
        return false;
    }

    function getEligibles(bytes32 jobId) internal view returns (uint256) {
        address[] memory applicants = (Jobs[jobId].applicants);

        uint256 eligibles;
        for (uint256 i; i < applicants.length; i++) {
            if (
                (Applicants[applicants[i]][jobId])[0] == Stage.REJECTED &&
                (Applicants[applicants[i]][jobId])[1] == Stage.FINAL_INTERVIEW
            ) eligibles += 1;
        }

        return eligibles;
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
            revert Web3Jobs__NotSupportedToken();
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
            revert Web3Jobs__NotSupportedToken();
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
