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
    event CreatedLoan(uint256 indexed id, address indexed token, uint256 indexed borrowedEth, address receiver);

    struct Loan {
        uint256 id;
        address receiver;
        bytes32 queryId;
        address stakedToken;
        uint256 stakedTokenAmount;
        int256 initialTokenPrice;
        uint256 borrowedEth;
        uint256 createdAt;
        uint256 expirationDate;
        bool isOpen;
        string state; // It can be 'pending', 'started', 'expired' or 'paid'
    }
    // User address => eth holding
    mapping(address => uint256) public holdingEth;
    // User address => amount of ETH currently lend for a particular user
    mapping(address => uint256) public lendEth;
    // Query id by oraclize => Loan
    mapping(bytes32 => Loan) public queryLoan;
    // Id => Loan
    mapping(uint256 => Loan) public loanById;
    // User address => loans by that user
    mapping(address => Loan[]) public userLoans;
    Loan[] public loans;
    Loan[] public closedLoans;
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
    /// @param _receivedToken The token that this contract will hold until the loan is payed
    /// @param _quantityToBorrow The quantity of ETH that you want to receive as the loan
    function loan(address _receivedToken, uint256 _quantityToBorrow) public payable {
        require(_quantityToBorrow > 0, 'You must borrow more than zero ETH');
        require(address(this).balance >= _quantityToBorrow, 'There are not enough ETH funds to lend you right now in this contract');
        require(msg.value >= 10 finney, 'You must pay at least 0.01 ETH to run this function so that it can read the current token price');

        string memory symbol = IERC20(_receivedToken).symbol();
        // Request the price in ETH of the token to receive the loan
        bytes32 queryId = oraclize_query(oraclize_query("URL", strConcat("json(https://api.bittrex.com/api/v1.1/public/getticker?market=ETH-", symbol, ").result.Bid"));)
        Loan memory l = Loan(lastId, msg.sender, queryId, _receivedToken, 0, _quantityToBorrow, now, 0, false, 'pending');
        queryLoan[queryId] = l;
        loanById[lastId] = l;
        lastId++;
    }

    /// @notice The function that gets called by oraclize to get the price of the symbol to stake for the loan
    /// @param _queryId The unique query id generated when the oraclize event started
    /// @param _result The received token price with decimals as a string
    /// @param _proof The unique proof to confirm that this function has been called by a valid smart contract
    function __callback(
       bytes32 _queryId,
       string memory _result,
       bytes memory _proof
    ) public {
       require(msg.sender == oraclize_cbAddress(), 'The callback function can only be executed by oraclize');

       Loan memory l = queryLoan[_queryId];
       int256 tokenPrice = parseInt(_result);
       uint256 amountToStake = l.stakedTokenAmount * tokenPrice * 0.5; // Multiply it by 0.5 to divide it by 2 so that the user sends double the quantity to borrow worth of tokens
       require(tokenPrice > 0, 'The token price must be larger than absolute zero');
       require(amountToStake >= l.borrowedEth, 'The quantity of tokens to stake must be larger than or equal twice the amount of ETH to borrow');

       IERC20(l.stakedToken).transferFrom(l.receiver, address(this), l.stakedTokenAmount);
       l.receiver.transfer(l.borrowedEth);
       l.initialTokenPrice = tokenPrice;
       l.expirationDate = now + 6 months;
       l.isOpen = true;
       l.state = 'started';
       loanById[l.id] = l;
       queryLoan[_queryId] = l;
       userLoans[l.receiver].push(l);
       loans.push(l);

       emit CreatedLoan(l.id, l.stakedToken, l.borrowedEth, l.receiver);
    }

    /// @notice To pay a given loan
    /// @param _loanId The loan id to pay
    function payLoan(uint256 _loanId) public payable {
        Loan memory l = loanById[_loanId];
        uint256 priceWithFivePercentFee = l.borrowedEth + (l.borrowedEth * 0.05);
        require(l.isOpen, 'The loan must be open to be payable');
        require(msg.value >= priceWithFivePercentFee, 'You must pay the ETH borrowed by the loan plus the five percent fee not less');
        // If he paid more than he borrowed, return him the difference without the fee tho
        if(msg.value > priceWithFivePercentFee) {
            l.receiver.transfer(msg.value - priceWithFivePercentFee);
        }
        // Send him his tokens back
        IERC20(l.stakedToken).transfer(l.stakedTokenAmount);

        l.isOpen = false;
        l.state = 'paid';
        queryLoan[l.queryId] = l;
        loanById[l.id] = l;
        closedLoans.push(l);

        // Update the loan from the array of user loans with the paid status
        for(uint256 i = 0; i < userLoans[l.receiver].length; i++) {
            if(userLoans[l.receiver][i].id == l.id) {
                userLoans[l.receiver][i] = l;
            }
        }
    }

    /// @notice To pay a holder that is participating in a loan after it's completed
    function payHolder() public {

    }

    /// @notice To extract the funds that a user may be holding in the bank
    function extractFunds() public {
        msg.sender.transfer(holdingEth[msg.sender]);
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
}
