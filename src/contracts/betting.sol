//SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;
                        
import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";


/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract Betting is ERC1155Supply, Ownable {
    
    enum State {
        INIT, OPEN, LOCKED, ENDED
    }
    
    //mapping(address => mapping(uint256 => uint256)) private _xxxxxxx;
    struct BettingEvent {
        State status;
        uint256 finalResult;
        mapping(uint256 => bool) resultsIds;
        uint256[] resultsIdsKeys;
    }
    mapping(uint256 => BettingEvent) public bettingEvents;
    uint256[] public bettingEventsKeys;

    // fee or "rake" : 100 == 1%
    uint256 public fee = 100;


    constructor(string memory uri_, uint256[] memory eventIds_, uint256[][] memory resultIds_) ERC1155(uri_) {
        addResultIds(eventIds_, resultIds_);
        for (uint i = 0; i < eventIds_.length; i++) {
            bettingEvents[eventIds_[i]].status = State.OPEN;
        }
    }

    function addResultIds(uint256[] memory eventIds_, uint256[][] memory resultIds_) public onlyOwner() {
        for (uint i = 0; i < eventIds_.length; i++) {
            for (uint j = 0; j < resultIds_.length; j++) {
                bettingEvents[eventIds_[i]].resultsIds[resultIds_[j][i]] = true;
                bettingEvents[eventIds_[i]].resultsIdsKeys.push(resultIds_[j][i]);
            }
        }
    }


    function bet(uint256 eventId_, uint256 resultId_) public payable returns (bool) {
        require(bettingEvents[eventId_].status == State.OPEN, "Betting: Event not open");
        // TODO require a minimum bet amount

        require(bettingEvents[eventId_].resultsIds[resultId_], "Betting: This result does not exist!");
        _mint(msg.sender, resultId_, msg.value, "");

        return true;
    }
    
    function batchBet(uint256 eventId_, uint256[] memory resultIds_, uint256[] memory amounts) public payable returns (bool) {
        require(bettingEvents[eventId_].status == State.OPEN, "Betting: Event not open");
        // TODO require a minimum total bet amounts

        uint amountsTotal = 0;
        for (uint i = 0; i < amounts.length; i++) {
            amountsTotal += amounts[i];
        }
        require(msg.value >= amountsTotal, "Betting: Insufficient value to cover bets");

        for (uint i = 0; i < bettingEvents[eventId_].resultsIdsKeys.length; i++) {
            require(bettingEvents[eventId_].resultsIds[resultIds_[i]], "Betting: This result does not exist!");
        }
        _mintBatch(msg.sender, resultIds_, amounts, "");
    
        return true;
    }

    function batchEventBet(uint256[] memory eventIds_, uint256[][] memory resultIds_, uint256[][] memory amounts) public payable returns (bool){
        for (uint i = 0; i < eventIds_.length; i++){
            batchBet(eventIds_[i], resultIds_[i], amounts[i]);
        }
        
        return true;
    }
    function lock(uint256 eventIds_) external {
        bettingEvents[eventIds_].status = State.LOCKED;
    }

    // Store the event result
    function store(uint256 eventId_, uint256 resultId_) public returns (bool) {
        // TODO Require accessControl
        require(exists(resultId_), "Betting: This result does not exist!");

        bettingEvents[eventId_].finalResult = resultId_;
        bettingEvents[eventId_].status = State.ENDED;

        return true;
    }

    function totalBetsOnEvent(uint256 eventId_) public view returns (uint256) {
        uint _totalBetsOnEvent = 0;
        for (uint i = 0; i < bettingEvents[eventId_].resultsIdsKeys.length; i++) {
            _totalBetsOnEvent += totalSupply(bettingEvents[eventId_].resultsIdsKeys[i]);
        }

        return _totalBetsOnEvent;
    }

    /// @notice Compute potential winnings
    /// @dev Compute potential or final winnings
    /// @param resultId_ result id
    /// @return the potential or final winnings of msg.sender for a result id
    function computeWinnings(uint256 eventId_, uint256 resultId_) public view returns (uint256) {
        require(totalSupply(resultId_) != 0, "Betting: no bets on event");

        uint256 winnings = balanceOf(msg.sender, resultId_) * totalBetsOnEvent(eventId_) / totalSupply(resultId_);
        winnings *= (10000 - fee)/10000;

        return winnings;
    }
    
    // claim / cash out single Id
    function cashOut(uint256 eventId_, uint256 resultId_) public returns (bool) {
        require(balanceOf(msg.sender, resultId_) > 0, "Betting: You didn't bet on this");
        require(bettingEvents[eventId_].status == State.ENDED, "Betting: Event not over");
        require(resultId_ == bettingEvents[eventId_].finalResult, "Betting: No winnings");

        uint winnings = computeWinnings(eventId_, resultId_);

        payable(msg.sender).transfer(winnings);

        return true;
    }

    // TODO
    // cash out multiple ids / all results for msg.sender
    function batchCashOut(uint256 eventIds_, uint256[] memory resultIds_) public returns (bool) {
        for (uint i = 0; i < resultIds_.length; i++){
            cashOut(eventIds_, resultIds_[i]);
        }

        return true;
    }
    function batchEventCashOut(uint256[] memory eventIds_, uint256[][] memory resultIds_) public returns (bool) {
        for (uint i = 0; i < eventIds_.length; i++){
            batchCashOut(eventIds_[i], resultIds_[i]);
        }
        
        return true;
    }
    // withdraw : not production code !
    function withdraw(uint256 value_) public onlyOwner() {
        // transfer the fees value TODO
        payable(msg.sender).transfer(value_);
    }

}