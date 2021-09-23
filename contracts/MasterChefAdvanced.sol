// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./MasterChefToken.sol";

contract MasterChefAdvanced is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. CUSTOM TOKENs to distribute per block.
        uint256 lastRewardBlock; // Last block number that CUSTOM TOKENs distribution occurs.
        uint256 accTokenPerShare; // Accumulated CUSTOM TOKENs per share, times 1e12. See below.
        uint16 depositFeeBP; // Deposit fee in basis points
    }

    // The CUSTOM TOKEN TOKEN!
    MasterChefToken public token;
    // Dev address.
    address public devaddr;
    uint256 public constant DEV_FEE_DIVIDER = 10;
    // CUSTOM TOKEN tokens created per block.
    uint256 public tokenPerBlock;
    // Bonus muliplier for early token makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when CUSTOM TOKEN mining starts.
    uint256 public startBlock;
    uint256 public depositedToken;

    uint256[] public rewardMultipliers = [100, 75, 56, 42, 40];
    // 12secs per block. - represents number of blocks in each index of multiplier
    uint256 public rewardTimePerMultiplierTier = 24 hours / 12;
    bool public masterChefCircuitBreak = false;

    mapping(address => mapping(uint256 => uint256)) public feeFactor;
    // address -> pool -> rate
    // if 0, means normal deposit fee.
    // if non 0, multiply the fee by this factor.

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event SetDevAddress(address indexed user, address indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 goosePerBlock);
    event UpdateStartBlock(uint256 indexed startBlock);

    constructor(
        MasterChefToken _token,
        address _devaddr,
        address _feeAddress,
        uint256 _tokenPerBlock,
        uint256 _startBlock
    ) public {
        token = _token;
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        tokenPerBlock = _tokenPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    function setFactor(
        address _a,
        uint256 _poolId,
        uint256 _bps
    ) external onlyOwner {
        require(_bps <= 10000, "max 100% factor");
        feeFactor[_a][_poolId] = _bps;
    }

    function setRewardTimePerMultiplierTier(uint256 _numBlocks, bool update) external onlyOwner {
        if (update) {
            massUpdatePools();
        }
        rewardTimePerMultiplierTier = _numBlocks;
    }

    function setRewardMultipliers(uint256[] memory _multipliers, bool update) external onlyOwner {
        if (update) {
            massUpdatePools();
        }
        rewardMultipliers = _multipliers;
    }

    function toggleCircuitBreaker(bool _b) external onlyOwner {
        masterChefCircuitBreak = _b;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) public onlyOwner nonDuplicated(_lpToken) {
        // require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        require(_depositFeeBP <= 2000, "max 20% fee");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accTokenPerShare: 0,
                depositFeeBP: _depositFeeBP
            })
        );
        // 100 = 1%
    }

    // Update the given pool's CUSTOM TOKEN allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        require(_depositFeeBP <= 5000, "max 50% fee");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // refer to new getMultiplier function at the bottom
    // function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
    //     return _to.sub(_from).mul(BONUS_MULTIPLIER);
    // }

    // View function to see pending CUSTOM TOKENs on frontend.
    function pendingToken(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (_pid == 0) {
            lpSupply = depositedToken;
        }
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (_pid == 0) {
            lpSupply = depositedToken;
        }
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        token.mint(devaddr, tokenReward.div(DEV_FEE_DIVIDER));
        token.mint(address(this), tokenReward);
        pool.accTokenPerShare = pool.accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // // Deposit LP tokens to MasterChef for CUSTOM TOKEN allocation.
    // function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
    //     PoolInfo storage pool = poolInfo[_pid];
    //     UserInfo storage user = userInfo[_pid][msg.sender];
    //     updatePool(_pid);
    //     if (user.amount > 0) {
    //         uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
    //         if (pending > 0) {
    //             safeTokenTransfer(msg.sender, pending);
    //         }
    //     }
    //     if (_amount > 0) {
    //         pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
    //         if (pool.depositFeeBP > 0) {
    //             uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000); // 100 = 1%
    //             pool.lpToken.safeTransfer(feeAddress, depositFee);
    //             user.amount = user.amount.add(_amount).sub(depositFee);
    //         } else {
    //             user.amount = user.amount.add(_amount);
    //         }
    //     }
    //     user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
    //     emit Deposit(msg.sender, _pid, _amount);
    // }

    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeTokenTransfer(msg.sender, pending);
            }
        }
        // prevent double hop for deposit fee
        uint256 intendedDepAmt = _amount;
        uint256 actualDepAmt = _amount;

        if (intendedDepAmt > 0) {
            if (pool.depositFeeBP > 0) {
                uint256 feeAmount = intendedDepAmt.mul(pool.depositFeeBP).div(10000); // 100 = 1%

                if (feeFactor[msg.sender][_pid] > 0) {
                    feeAmount = feeAmount.mul(feeFactor[msg.sender][_pid]).div(10000);
                }

                pool.lpToken.safeTransferFrom(address(msg.sender), feeAddress, feeAmount);
                intendedDepAmt = intendedDepAmt.sub(feeAmount);
            }

            uint256 balBefore = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), intendedDepAmt);
            actualDepAmt = pool.lpToken.balanceOf(address(this)).sub(balBefore);

            user.amount = user.amount.add(actualDepAmt);
            if (_pid == 0) {
                depositedToken = depositedToken.add(actualDepAmt);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, actualDepAmt);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeTokenTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            if (_pid == 0) {
                depositedToken = depositedToken.sub(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough CUSTOM TOKENs.
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = token.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > tokenBal) {
            transferSuccess = token.transfer(_to, tokenBal);
        } else {
            transferSuccess = token.transfer(_to, _amount);
        }
        require(transferSuccess, "safeTokenTransfer: transfer failed");
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
        emit SetDevAddress(msg.sender, _devaddr);
    }

    function setFeeAddress(address _feeAddress) public {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    //Pancake has to add hidden dummy pools inorder to alter the emission,
    // here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _tokenPerBlock) public onlyOwner {
        massUpdatePools();
        tokenPerBlock = _tokenPerBlock;
        emit UpdateEmissionRate(msg.sender, _tokenPerBlock);
    }

    // helpers

    function _getTierOfBlock(uint256 blockNum) internal view returns (uint256) {
        return (blockNum <= startBlock) ? 0 : blockNum.sub(startBlock).div(rewardTimePerMultiplierTier);
    }

    // for reward boosts
    function _getMultiplierByBlockNum(uint256 blockNum) internal view returns (uint256) {
        return _getMultiplierByTier(_getTierOfBlock(blockNum));
    }

    function _getMultiplierByTier(uint256 tier) internal view returns (uint256) {
        return
            (tier < rewardMultipliers.length)
                ? rewardMultipliers[tier]
                : rewardMultipliers[rewardMultipliers.length - 1];
    }

    function _getCurrentBlockEmission() internal view returns (uint256) {
        return _getMultiplierByBlockNum(block.number);
    }

    function _getMultiplierByFullTiers(uint256 startTier, uint256 endTier) internal view returns (uint256) {
        if (startTier >= endTier) {
            return 0;
        }
        // tiers that happen after the last defined tier in the rewardMultipliers array
        uint256 staticTiers = (endTier >= rewardMultipliers.length) ? (endTier.sub(rewardMultipliers.length)) : 0;
        uint256 staticMultipliers = staticTiers.mul(rewardMultipliers[rewardMultipliers.length - 1]);

        uint256 sum = 0;
        uint256 max = (endTier >= rewardMultipliers.length) ? rewardMultipliers.length : endTier;
        for (uint256 i = startTier; i < max; i++) {
            sum = sum.add(rewardMultipliers[i]);
        }
        return (sum.add(staticMultipliers)).mul(rewardTimePerMultiplierTier);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        // circuitbreak!
        if (masterChefCircuitBreak) {
            return _to.sub(_from);
        }

        if (_from >= _to) {
            return 0;
        }
        if (_to <= startBlock) {
            return 0;
        }
        if (_from < startBlock) {
            _from = startBlock;
        }

        uint256 startTier = _getTierOfBlock(_from);
        uint256 endTier = _getTierOfBlock(_to);

        if (startTier >= rewardMultipliers.length) {
            return _to.sub(_from).mul(rewardMultipliers[rewardMultipliers.length - 1]);
        } else if (startTier == endTier) {
            return _to.sub(_from).mul(_getMultiplierByTier(startTier));
        }

        // overcalculate first
        uint256 sum = _getMultiplierByFullTiers(startTier, endTier.add(1));

        // remove front
        // _from - startOfFirstTier
        uint256 startOfFirstTier = startBlock.add(startTier.mul(rewardTimePerMultiplierTier));
        sum = sum.sub((_from.sub(startOfFirstTier)).mul(_getMultiplierByTier(startTier)));

        // remove end
        // endOfLastTier - _to
        uint256 endOfLastTier = startBlock.add((endTier.add(1)).mul(rewardTimePerMultiplierTier));
        sum = sum.sub((endOfLastTier.sub(_to)).mul(_getMultiplierByTier(endTier)));

        return sum;
    }

    function updateStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(block.number < startBlock, "cannot change start block if farm has already started");
        require(block.number < _newStartBlock, "cannot set start block in the past");
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            pool.lastRewardBlock = _newStartBlock;
        }
        startBlock = _newStartBlock;

        emit UpdateStartBlock(startBlock);
    }
}
