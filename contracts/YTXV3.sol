pragma solidity =0.6.2;

import '@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

contract YTXV3 is Initializable, OwnableUpgradeSafe, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    mapping (address => bool) public isFrozen;
    uint256 public transferFee;
    address public treasury;

    event Fee(address sender, uint256 amount);
    
    function initialize() public initializer {
        _totalSupply = 60000 * 1e18; // 60k tokens
        _name = 'YTX';
        _symbol = 'YTX';
        _decimals = 18;
        _balances[msg.sender] = _totalSupply;
        transferFee = 1e16; // 1% out of 100% which is 1e16 out of 1e18
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function name() public view returns (string memory) {
        return _name;
    }
    
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(!isFrozen[msg.sender], 'Your transfers are frozen');
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function burn(address _account, uint256 _amount) public onlyOwner returns (bool) {
        _burn(_account, _amount);
        return true;
    }

    function extractETHIfStuck() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function extractTokenIfStuck(address _token, uint256 _amount) public onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }
    
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        // YTX
        (uint256 fee, uint256 remaining) = calculateFee(amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        // Remaining transfer
        _balances[recipient] = _balances[recipient].add(remaining);
        // Fee transfer
        _balances[treasury] = _balances[treasury].add(fee);

        emit Transfer(sender, recipient, remaining);
        emit Fee(sender, fee);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    function freezeTokens(address _of) public onlyOwner {
        isFrozen[_of] = true;
    }
    
    function unFreezeTokens(address _of) public onlyOwner {
        isFrozen[_of] = false;
    }

    function changeFee(uint256 _fee) public onlyOwner {
        transferFee = _fee;
    }

    function calculateFee(uint256 _amount) internal view returns(uint256 fee, uint256 remaining) {
        fee = _amount.mul(transferFee).div(1e18);
        remaining = _amount.sub(fee);
    }
}