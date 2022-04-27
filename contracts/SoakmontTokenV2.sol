// SPDX-License-Identifier: NOLICENSE
pragma solidity ^0.8.7;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
    }
}


abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


interface IFactory{
        function createPair(address tokenA, address tokenB) external returns (address pair);
}


interface IRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) external;
}


contract SoakmontTokenV2 is Context, IERC20, Ownable {

    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _admins;
    mapping (address => uint256) private _balances;
    
    bool public swapEnabled;
    bool private swapping;

    IRouter public router;
    address public pair;

    uint8 private constant DECIMALS = 18;
    
    uint256 private _totalSupply;
    uint256 private _maxSupply;
    uint256 public swapTokensAtAmount = 100000000 * 10**DECIMALS;

    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public devAddress;

    string private constant NAME = "Soakmont";
    string private constant SYMBOL = "SOAKV2";


    uint8 private constant MAX_TAXES = 10;
    struct Taxes {
      uint256 dev;
      uint256 liquidity;
    }
    Taxes public taxes = Taxes(3,2);

    struct TotFeesPaidStruct{
        uint256 dev;
        uint256 liquidity;
    }
    TotFeesPaidStruct public totFeesPaid;

    struct valuesFromGetValues{
      uint256 rAmount;
      uint256 rTransferAmount;
      uint256 rDev;
      uint256 rLiquidity;
      uint256 tTransferAmount;
      uint256 tDev;
      uint256 tLiquidity;
    }

    address _bridge;

    event FeesChanged();
    event DevAddressChanged(address newDevAddress);
    event RouterChanged(address newRouterAddress, address newPairAddress);
    event SwapEnabledChanged(bool swapEnabled);
    event SwapTokenAtAmountChanged(uint256 swapTokensAtAmount);
    event BridgeChanged(address newBridge);

    modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }

    modifier onlyBridge(){
        require(_bridge != address(0), "Bridge contract not specified.");
        require(_msgSender() == _bridge, "Sender is not bridge contract.");
        _;
    }

    modifier onlyAdmin {
        require (_msgSender() == owner() || _admins[_msgSender()] == true, "!permission");
        _;
    }

    constructor (address routerAddress, address devWallet, uint256 initialSupply) {
        devAddress = devWallet;
        _totalSupply = initialSupply;
        _maxSupply = initialSupply;
        IRouter _router = IRouter(routerAddress);
        address _pair = IFactory(_router.factory())
            .createPair(address(this), _router.WETH());

        router = _router;
        pair = _pair;

        emit Transfer(address(0), owner(), initialSupply);
    }

    function name() external pure returns (string memory) {
        return NAME;
    }

    function symbol() external pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    receive() external payable{}

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function updatedevWallet(address newWallet) external onlyOwner{
        require(devAddress != newWallet ,'Wallet already set');
        devAddress = newWallet;
        emit DevAddressChanged(devAddress);
    }

    function updateSwapTokensAtAmount(uint256 amount) external onlyOwner{
        swapTokensAtAmount = amount * 10 ** DECIMALS;
        emit SwapTokenAtAmountChanged(swapTokensAtAmount);
    }

    function updateSwapEnabled(bool _enabled) external onlyOwner{
        swapEnabled = _enabled;
        emit SwapEnabledChanged(_enabled);
    }
    
    function updateRouterAndPair(address newRouter, address newPair) external onlyOwner{
        router = IRouter(newRouter);
        pair = newPair;
        emit RouterChanged(newRouter, newPair);
    }

    function bridge() external view returns (address) {
        return _bridge;
    }

    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "Bridge cannot be AddressZero.");
        _bridge = newBridge;
        emit BridgeChanged(newBridge);
    }

    function mintToBridge(uint256 amount) external onlyBridge {
        require(totalSupply() <= _maxSupply, "Cannot mint more than max supply");
        emit Transfer(address(0), _bridge, amount);
    }

    function rescueBNB(uint256 weiAmount) external onlyOwner{
        require(address(this).balance >= weiAmount, "insufficient BNB balance");
        payable(msg.sender).transfer(weiAmount);
    }
    
    function rescueAnyERC20Tokens(address _tokenAddr, address _to, uint _amount) external onlyOwner {
        IERC20(_tokenAddr).transfer(_to, _amount);
    }

    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function isExcludedFromFee(address account) external view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function setAdmins(address account, bool flag) external onlyOwner {
        _admins[account] = flag;
    }

    function setTaxes(uint256 _dev, uint256 _liquidity) external onlyOwner {
        require((_dev + _liquidity) < MAX_TAXES, "Total taxes cannot be higher than 10%");
        taxes.dev = _dev;
        taxes.liquidity = _liquidity;
        emit FeesChanged();
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        bool canSwap = balanceOf(address(this)) >= swapTokensAtAmount;
        if(!swapping && swapEnabled && canSwap && sender != pair && !_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient]){
            swapAndLiquify(swapTokensAtAmount);
        }

        uint256 _devTax = amount*taxes.dev/100;
        uint256 _liquidityTax = amount*taxes.liquidity/100;
        uint256 _totalTax = _devTax + _liquidityTax;
        uint256 _transferAmount = amount-_totalTax;

        _balances[sender] = senderBalance - amount;
        _balances[recipient] += _transferAmount;
        _balances[address(this)] += _totalTax;
        
        emit Transfer(sender, recipient, _transferAmount);
        emit Transfer(sender, address(this), _totalTax);
    }

    function swapAndLiquify(uint256 tokens) private lockTheSwap{
        uint256 denominator = (taxes.liquidity + taxes.dev ) * 2;
        uint256 tokensToAddLiquidityWith = tokens * taxes.liquidity / denominator;
        uint256 toSwap = tokens - tokensToAddLiquidityWith;

        uint256 initialBalance = address(this).balance;

        swapTokensForBNB(toSwap);

        uint256 deltaBalance = address(this).balance - initialBalance;
        uint256 unitBalance = deltaBalance / (denominator - taxes.liquidity);
        uint256 bnbToAddLiquidityWith = unitBalance * taxes.liquidity;

        if(bnbToAddLiquidityWith > 0){
            addLiquidity(tokensToAddLiquidityWith, bnbToAddLiquidityWith);
        }

        uint256 devAmt = unitBalance * 2 * taxes.dev;
        if(devAmt > 0){
            payable(devAddress).transfer(devAmt);
        }

    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(router), tokenAmount);

        router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}