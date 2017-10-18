pragma solidity ^0.4.11;

import '../token/MintableToken.sol';
import '../math/SafeMath.sol';
import '../ownership/Ownable.sol';

/**
 * @title AuctionSale
 * @dev AuctionSale is a base contract for managing a token sale based on the result of a previous auction.
 * Investors can make token purchases based on the result of an auction and AuctionSale will assign 
 * them tokens based on said previous auction. 
 * Funds collected are forwarded to a wallet as they arrive.
 *
 * Based on Crowdsale.sol (OpenZeppelin)
 */
contract AuctionSale is Ownable {
  using SafeMath for uint256;

  // The token being sold
  MintableToken public token;

  // address where funds are collected
  address public wallet;

  // amount of raised money in wei
  uint256 public weiRaised;

  // amounts to be paid from bidders based on finished auction
  mapping (address => uint256) private payFromAuctionAmounts;

  // amounts of tokens to generate for bidders based on finished auction
  mapping (address => uint256) private tokensMintAuctionAmounts;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  function AuctionSale(address _wallet) {
    require(_wallet != 0x0);

    token = createTokenContract();
    wallet = _wallet;
  }

  // creates the token to be sold.
  // override this method to have crowdsale of a specific mintable token.
  function createTokenContract() internal returns (MintableToken) {
    return new MintableToken();
  }


  // fallback function can be used to buy tokens
  function () payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != 0x0);
    require(validPurchase(beneficiary));

    uint256 weiAmount = msg.value;

    // token amount to be created
    uint256 tokens = tokensMintAuctionAmounts[beneficiary];

    // update state
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    // remove minted tokens
    tokensMintAuctionAmounts[beneficiary] -= tokens;

    forwardFunds();

    // remove payed amount
    payFromAuctionAmounts[beneficiary] -= weiAmount;
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }

  // @return true if the transaction can buy tokens
  function validPurchase(address beneficiary) internal constant returns (bool) {
    bool nonZeroPurchase = msg.value != 0;
    bool correctAmountWillBePaid = (payFromAuctionAmounts[beneficiary] - msg.value) == 0;
    bool bidderWillBeMintedTokens = tokensMintAuctionAmounts[beneficiary] > 0;
    return nonZeroPurchase && correctAmountWillBePaid && bidderWillBeMintedTokens;
  }

  // owner of the smart contract must set the amounts that each bidder must pay
  // based on the result of the auction
  function payableFromAuction (address[] bidders, uint256[] amounts) onlyOwner {
        for (uint i = 0; i < bidders.length; i++) {
            payFromAuctionAmounts[bidders[i]] = amounts[i];
        }
  }

  // owner of the smart contract must set the allowable tokens that each bidder
  // can mint based on the result of the auction
  function tokensAllowableMint (address[] bidders, uint256[] amounts) onlyOwner {
        for (uint i = 0; i < bidders.length; i++) {
            tokensMintAuctionAmounts[bidders[i]] = amounts[i];
        }
  }
}
