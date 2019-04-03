pragma solidity ^0.5.5;

import './IERC20.sol';
import './usingOraclize.sol';

/// @notice The open source bank and lending platform for ERC-20 tokens and ETH
/// @author Merunas Grincalaitis <merunasgrincalaitis@gmail.com>
contract Bank is usingOraclize {
    /*
        We want the following features
        - A function to add money to the bank in the form of ETH or ERC-20
        - A function to give loans to people in exchange for their preferred tokens
        - To use Oraclize for getting the price of the tokens added to the platform
        - A whitelisting function to allow the owner to add operators that can close open loans if the price drops below 40%
        - A monitoring function to check the price of the token at the time the loan was given compared to the current price
        - A function to pay holders based on their token holdings monthly and if their tokens are used for loans
        - A function to display the current balance of tokens inside the platform
    */
    // User address => all the tokens he holds
    mapping(address => address[]) public holdingAddresses;
    // User address => Token address => quantity of tokens currently holding
    mapping(address => mapping(address => uint256)) public holdingValue;
    // User address => amount of ETH currently holding here
    mapping(address => uint256) public holdingEth;
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner, 'This function can only be executed by the owner');
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /// @notice To add token or ETH funds to the bank, those funds may be used for loans and if so, the holder won't be able to extract those funds in exchange for a 5% total payment of their funds when the loan is closed
    function addFunds(bool _isEth, address _tokenAddress, uint256 _quantity) public payable {
        if(_isEth) {
            require(msg.value > 0, 'You must send more than zero ether');
            holdingEth[msg.sender] += msg.value;
        } else {
            require(!_isEth && _quantity > 0, 'You must send more than zero tokens');
            require(_tokenAddress != address(0), 'You must give a non-empty token address');
            uint256 allowance = IERC20(_tokenAddress).allowance(msg.sender, address(this));
            require(allowance >= _quantity, 'You must allow enough tokens before depositing funds');

            IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _quantity);

            // If the token has already been added to the portfolio of this user, don't add it again
            if(!checkExistingToken(_tokenAddress)) {
                holdingAddresses[msg.sender].push(_tokenAddress);
            }
            holdingValue[msg.sender][_tokenAddress] += _quantity;
        }

    }

    /// @notice To get a loan for a specific token or ETH, the user interface will help determine the quantities required to stake
    function loan(bool _isEthReceived, bool _isEthBorrowed, address _receivedToken, address _borrowedToken, uint256 _quantityReceived, uint256 _quantityBorrowed) public payable {
        
    }

    /// @notice To pay a given loan
    function payLoan(uint256 _loadId, bool _isEth, address _tokenAddress) public payable {

    }

    /// @notice To pay a holder that is participating in a loan after it's completed
    function payHolder() public {

    }

    /// @notice To add an operator Ethereum address or to remove one based on the _type value
    /// @param _type If it's an 'add' or 'remove' operation
    /// @param _user The address of the operator
    function modifyOperator(bytes32 _type, address _user) public onlyOwner {

    }

    /// @notice To compare the price of the token used for the loan so that we can detect drops in value for selling those tokens when needed
    function monitorLoan() public view returns(uint256 initialPrice, uint256 currentPrice, uint256 percentageChange) {

    }

    /// @notice To check which tokens are available in this bank so that the User Interface can check the balance and name of those tokens inside here
    /// @return address[] The addresses of the tokens holded inside this contract
    function getAvailableTokens() public view returns(address[] memory) {

    }

    /// @notice To check if a token is already added to the list of holdings for the sender
    /// @return bool If it's been already added or not
    function checkExistingToken(address _token) public view returns(bool) {
        for(uint256 i = 0; i < holdingAddresses.length; i++) {
            if(holdingAddresses[i] == _token) {
                return true;
            }
        }
        return false;
    }
}
