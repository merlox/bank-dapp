pragma solidity ^0.5.5;

import './IERC20.sol';
import './usingOraclize.sol';

/// @notice The open source bank and lending platform for ERC-20 tokens and ETH
/// @author Merunas Grincalaitis <merunasgrincalaitis@gmail.com>
contract Bank is usingOraclize {
    /*
        We want the following features
        - A function to add money to the bank in the form of ERC-20 the bank will only give loans in ETH
        - A function to give ETH loans to people in exchange for their preferred tokens
        - To use Oraclize for getting the price of the tokens added to the platform
        - A whitelisting function to allow the owner to add operators that can close open loans if the price drops below 40%
        - A monitoring function to check the price of the token at the time the loan was given compared to the current price
        - A function to pay holders based on their token holdings monthly and if their tokens are used for loans
        - A function to display the current balance of tokens inside the platform
    */
    struct Loan {
        uint256 id;
        bytes32 queryId;
        address tokenTo
    }
    // User address => all the tokens he holds
    mapping(address => address[]) public holdingAddresses;
    // User address => Token address => quantity of tokens currently holding
    mapping(address => mapping(address => uint256)) public holdingValue;
    // User address => amount of ETH currently lend for a particular user
    mapping(address => uint256) public lendEth;
    // Query id by oraclize => loan requested in ETH
    mapping(bytes32 => uint256) public queryLoans;
    address public owner;
    uint256 public lastId;

    modifier onlyOwner {
        require(msg.sender == owner, 'This function can only be executed by the owner');
        _;
    }

    constructor() public {
        owner = msg.sender;
        oraclize_setProof(proofType_Ledger);
    }

    /// @notice To add ETH funds to the bank, those funds may be used for loans and if so, the holder won't be able to extract those funds in exchange for a 5% total payment of their funds when the loan is closed
    function addFunds() public payable {
        require(msg.value > 0, 'You must send more than zero ether');
        holdingEth[msg.sender] += msg.value;
    }

    /// @notice To get a loan for ETH in exchange for the any compatible token note that you need to send a small quantity of ETH to process this transaction at least 0.01 ETH so that the oracle can pay for the cost of requesting the token value
    function loan(address _receivedToken, uint256 _quantityToBorrow) public payable {
        require(_quantityToBorrow > 0, 'You must borrow more than zero ETH');
        // First we check that there's enough balance of ETH to lend him
        require(address(this).balance >= _quantityToBorrow, 'There are not enough ETH funds to lend you right now in this contract');
        // If there is, then we check that the user sent enough tokens to stake which in this case must be 50% of the value of the first token, how do we know that? We check ETH prices of the token and then we
        string memory symbol = IERC20(_receivedToken).symbol();
        // Request the price in ETH of the token to receive
        bytes32 queryId = oraclize_query(oraclize_query("URL", strConcat("json(https://api.bittrex.com/api/v1.1/public/getticker?market=ETH-", symbol, ").result.Bid"));)
        queryLoans[queryId] = _quantityToBorrow;
    }

    /// @notice The function that gets called by oraclize to get the price of the symbol to stake for the loan
    function __callback(
       bytes32 _queryId,
       string memory _result,
       bytes memory _proof
    ) public {
       require(msg.sender == oraclize_cbAddress(), 'The callback function can only be executed by oraclize');




       emit GeneratedRandom(_queryId, numberOfParticipants[_queryId], parseInt(_result));
       hydroLottery.endLottery(_queryId, parseInt(_result));
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
