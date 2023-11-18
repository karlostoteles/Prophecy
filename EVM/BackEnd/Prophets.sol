//SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/** 
 * @title Prophets
 * @dev Implements TBD
 * Prophets
 */
contract Prophets {
    using Counters for Counters.Counter;
    Counters.Counter private poolIds;
    address constant DUMMY_ADDRESS = 0x8090E825C6FEED75A2aB5bbBF098f01083B98090;

    enum Status {
        ONGOING,
        CLOSED
    }
    
    struct BettingPool {
        uint poolId;
        string teamA;
        string teamB;
        uint totalBetA; //Total betting amount towards teamA
        uint totalBetB; //Total betting amount towards teamB
        uint totalBettingAmount;
        uint winningTeam;
        address safeId; //Safe ID for Account Abstraction
        uint timeOfCreation;
        mapping(address => uint) amountPerPlayer; //Address to amount
        mapping(address => uint) teamPerPlayer; //The team that the player has bet for
        mapping(address => bool) playerClaimedWinnings; //True if the player has claimed their winnings
        Status status;
    }

    mapping(uint => BettingPool) public bettingPoolMap;
    uint[] public _bettingPools;

    /** 
     * @dev Create a betting pool.
    */
    function createBettingPool(string memory _teamA, string memory _teamB, uint initialAmount, uint teamId) public payable returns(uint){
        
        require(initialAmount == msg.value, "Amount not matching");

        poolIds.increment();
        uint id = poolIds.current();

        BettingPool storage bettingPool = bettingPoolMap[id];
        bettingPool.poolId = id;
        bettingPool.teamA = _teamA;
        bettingPool.teamB = _teamB;
        bettingPool.totalBettingAmount = initialAmount;


        if(teamId == 1) {
            bettingPool.totalBetA += initialAmount;
            bettingPool.teamPerPlayer[msg.sender] = 1;
        }
        else if(teamId == 2) {
            bettingPool.totalBetB += initialAmount;
            bettingPool.teamPerPlayer[msg.sender] = 2;
        }

        bettingPool.amountPerPlayer[msg.sender] = initialAmount;
        bettingPool.status = Status.ONGOING;

        _bettingPools.push(id);

        return id;
    }
    
    /** 
    * @dev Place a bet in an ongoing betting pool.
    */
    function bet(uint _poolId, uint teamId) public payable {

        BettingPool storage bettingPool = bettingPoolMap[_poolId];

        require(bettingPool.status == Status.ONGOING, "You can not bet on this game.");
        require(bettingPool.amountPerPlayer[msg.sender] == 0, "This player has already bet");
        require(bettingPool.teamPerPlayer[msg.sender] == 0, "This player has already bet");

        bettingPool.totalBettingAmount += msg.value;
        
        if(teamId == 1) {
            bettingPool.totalBetA += msg.value;
            bettingPool.teamPerPlayer[msg.sender] = 1;
        }
        else if(teamId == 2) {
            bettingPool.totalBetB += msg.value;
            bettingPool.teamPerPlayer[msg.sender] = 2;
        }

        bettingPool.amountPerPlayer[msg.sender] = msg.value;

    }

    function closeBettingPool(uint _poolId, uint winningTeam) public {
        BettingPool storage bettingPool = bettingPoolMap[_poolId];
        require(bettingPool.status == Status.ONGOING, "You can not close this game.");

        bettingPool.winningTeam = winningTeam;
        bettingPool.status = Status.CLOSED;

    }

    function checkAmountToWithdraw(uint _poolId) public view returns(uint) {

        BettingPool storage bettingPool = bettingPoolMap[_poolId];
        require(bettingPool.status == Status.CLOSED, "The betting is ongoing");
        require(bettingPool.teamPerPlayer[msg.sender] != 0, "This player has not bet");
        require(bettingPool.teamPerPlayer[msg.sender] == bettingPool.winningTeam, "Player bet on the losing team");

        uint winnings;

        if(bettingPool.winningTeam == 1) {
            winnings = (bettingPool.amountPerPlayer[msg.sender]*bettingPool.totalBettingAmount)/bettingPool.totalBetA;
        }
        else if(bettingPool.winningTeam == 2) {
            winnings = (bettingPool.amountPerPlayer[msg.sender]*bettingPool.totalBettingAmount)/bettingPool.totalBetB;
        }

        return winnings;

    }

    function withdrawWinnings(uint _poolId) public {
        BettingPool storage bettingPool = bettingPoolMap[_poolId];
        require(bettingPool.status == Status.CLOSED, "The betting is ongoing");
        require(bettingPool.teamPerPlayer[msg.sender] != 0, "This player has not bet");
        require(bettingPool.teamPerPlayer[msg.sender] == bettingPool.winningTeam, "Player bet on the losing team");
        require(bettingPool.playerClaimedWinnings[msg.sender] == false, "Player has already claimed winnings");
        uint winnings;

        if(bettingPool.winningTeam == 1) {
            winnings = (bettingPool.amountPerPlayer[msg.sender]*bettingPool.totalBettingAmount)/bettingPool.totalBetA;
        }
        else if(bettingPool.winningTeam == 2) {
            winnings = (bettingPool.amountPerPlayer[msg.sender]*bettingPool.totalBettingAmount)/bettingPool.totalBetB;
        }

        bettingPool.playerClaimedWinnings[msg.sender] == true;
        payable(msg.sender).transfer(winnings);
    }

    //TBD: Function to distribute the winnings

    /*** --------------READ FUNCTIONS--------------------------------- ***/

    /**
     * @dev Get the amount bet by the msg.sender for a particular pool
     * @param _poolId : Pool ID
     */
    function getBetAmountPerPoolPerUser(uint _poolId) public view
    returns(uint amount){
        return bettingPoolMap[_poolId].amountPerPlayer[msg.sender];
    }

    /**
     * @dev Get the betting team for the msg.sender for a particular pool
     * @param _poolId : Pool ID
     */
    function getBetTeamPerPoolPerUser(uint _poolId) public view
    returns(uint teamId){
        return bettingPoolMap[_poolId].teamPerPlayer[msg.sender];
    }

    /** 
     * @dev Returns total betting amount until now.
     * @return amount : total bet amount so far 
    */ 
    function getTotalBettingAmountPerPool(uint _poolId) public view
            returns (uint amount)
    {
        return bettingPoolMap[_poolId].totalBettingAmount;
    }

     /** 
     * @dev Returns total betting amount per team.
     * @return amount : total bet amount per team
    */ 
    function getBettingAmountPerTeamPerPool(uint _poolId, uint _teamId) public view
            returns (uint amount)
    {   
        if(_teamId == 1) {
            return bettingPoolMap[_poolId].totalBetA;
        }
        else if(_teamId == 2) {
            return bettingPoolMap[_poolId].totalBetB;
        }
        
    }


}
