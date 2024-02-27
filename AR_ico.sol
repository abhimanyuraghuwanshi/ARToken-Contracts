// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
        _;
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

contract AR_ICO is Pausable, Ownable, ReentrancyGuard {
    address token1;
    address token2;
    uint256 public totalStakes;
    uint256 public constant lockupPeriod = 1* 365 days; // Change the lockup period as needed
    mapping(address => StakeInfo) public stakes;
    bool icoEnded = false;
    
    IERC20 contract1 = IERC20(token1);
    IERC20 contract2 = IERC20(token2);

    mapping(address => uint256) public purchase;

    event TransferAnyBSC20Token(address indexed sender,address indexed recipient,uint256 tokens);
    event tokenPurchased(address buyer, address sender, uint256 amount);
    event tokenPrebooked(address buyer, uint256 amount);
    event tokenClaimed(address claimedBy, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _token1, address _token2) Ownable(msg.sender) {
        token1 = _token1;
        token2 = _token2;
    }

    struct StakeInfo {
        uint256 amount;
        uint256 lockupTime;
    }

    modifier checkLockUp{
        require(block.timestamp >= stakes[msg.sender].lockupTime + lockupPeriod, "Lockup period not over");
        _;
    }

    modifier icoEnd{
        require(icoEnded, "ICO period over");
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function endICO() public onlyOwner {
        icoEnded = true;
    }

    function prebookToken(uint256 _amount) public nonReentrant icoEnd returns (bool) {
        require(msg.sender != address(0), "BEP20: approve to the zero address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= contract2.allowance(msg.sender, address(this)),"Insufficient allowance" );

        bool success = contract2.transferFrom( msg.sender,address(this), _amount );
        require(success, "BEP20 transfer failed");
        purchase[msg.sender] = purchase[msg.sender] + _amount;

        emit tokenPrebooked(msg.sender, _amount);
        return success;
    }

    function claimToken(uint256 _amount) public whenNotPaused returns (bool) {
        require(msg.sender != address(0), "BEP20: approve to the zero address");
        require(_amount > 0, "Amount must be greater than 0");
        require(purchase[msg.sender] >= _amount, "Insuffient funds to claim");
        require(_amount <= contract1.balanceOf(address(this)),"Insufficient funds in contract");

        purchase[msg.sender] = purchase[msg.sender] - _amount;
        bool success = contract1.transfer(msg.sender, _amount);
        require(success, "BEP20 transfer failed");

        emit tokenClaimed(msg.sender, _amount);
        return success;
    }

    function buyToken(uint256 _amount) public whenNotPaused nonReentrant returns (bool){
        require(msg.sender != address(0), "BEP20: approve to the zero address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= contract2.allowance(msg.sender, address(this)), "Insufficient allowance" );
        require(_amount <= contract1.balanceOf(address(this)),"Insufficient funds in contract");

        bool success = contract2.transferFrom(msg.sender,address(this),_amount);
        require(success, "BEP20 transfer failed");
        bool success2 = contract1.transfer(msg.sender, _amount);
        require(success2, "BEP20 transfer failed");

        emit tokenPurchased(msg.sender, address(this), _amount);
        return success2;
    }

    function stake(uint256 _amount) external whenNotPaused {
        require(msg.sender != address(0), "BEP20: approve to the zero address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= contract2.allowance(msg.sender, address(this)),"Insufficient allowance");

        require(contract1.transferFrom(msg.sender, address(this), _amount),"Stake failed");
        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].lockupTime = block.timestamp;
        totalStakes += _amount;

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external whenNotPaused checkLockUp {
        require(_amount > 0, "Amount must be greater than 0");
        require(stakes[msg.sender].amount >= _amount, "Insufficient balance");
        require(_amount <= contract1.balanceOf(address(this)),"Insufficient funds in contract");
        
        stakes[msg.sender].amount -= _amount;
        totalStakes -= _amount;
        require(contract1.transfer(msg.sender, _amount), "Withdrawal failed");
        
        emit Withdrawn(msg.sender, _amount);
    }

    function withdrawAll() external whenNotPaused checkLockUp {
        uint256 amount = stakes[msg.sender].amount;
        require(amount > 0, "No stakes to withdraw");
        require(amount <= contract1.balanceOf(address(this)),"Insufficient funds in contract");
        
        stakes[msg.sender].amount = 0;
        totalStakes -= amount;
        
        require(contract1.transfer(msg.sender, amount), "Withdrawal failed");
        
        emit Withdrawn(msg.sender, amount);
    }

    /* 
     @dev function to transfer any BEP20 token
     @param tokenAddress token contract address
     @param tokens amount of tokens
     @return success boolean status
    */
    function transferAnyBSC20Token(
        address tokenAddress,
        address wallet,
        uint256 tokens
    ) public onlyOwner returns (bool success) {
        success = IERC20(tokenAddress).transfer(wallet, tokens);
        require(success, "BEP20 transfer failed");
        emit TransferAnyBSC20Token(address(this), wallet, tokens);
    }
}
