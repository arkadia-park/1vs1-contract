// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WesternShootout {
    address public owner;
    uint256 public feePercentage;
    uint256 public nextGameId = 1;
    uint256 public defaultWager;
    uint256 public gameTimeout; // Timeout duration in seconds
    uint256 public disputeWindow; // Time window for disputes in seconds
    
    // Mapping of arbiters for efficient lookup
    mapping(address => bool) public isArbiter;
    address[] public arbiterList; // List for enumeration
    
    // Track active games
    uint256[] public activeGameIds;
    mapping(uint256 => uint256) private activeGameIndex; // gameId => index in activeGameIds
    
    // On-chain player statistics
    struct PlayerStats {
        uint128 wins; // Using smaller uint types to pack variables
        uint128 losses;
        uint128 gamesPlayed;
        uint128 timeouts;
        uint128 disputes;
    }
    mapping(address => PlayerStats) public playerStats;
    
    // Game state enum
    enum GameState { Waiting, Ready, Completed, TimedOut, Disputed }
    
    // Dispute resolution voting
    struct DisputeVote {
        address arbiter;
        address votedWinner;
        string reason;
    }
    
    // Structure to store a game record
    struct Game {
        uint256 id;
        address player1;
        address player2;
        address winner;
        uint256 wager;
        uint256 fee; // fee charged for the game
        GameState state;
        uint256 timestamp; // time when the game was created
        uint256 readyTimestamp; // time when game became ready
        address disputeInitiator; // who initiated the dispute
        uint256 disputeTimestamp; // when the dispute was initiated
        DisputeVote[] votes; // arbiter votes
        mapping(address => bool) hasVoted; // track which arbiters have voted
        uint256 player1Votes; // count of votes for player1
        uint256 player2Votes; // count of votes for player2
    }
    
    // Mapping from game id to game details
    mapping(uint256 => Game) public games;
    
    // Track games a player is participating in
    mapping(address => uint256[]) public playerGames;
    
    // Events for logging
    event GameCreated(uint256 indexed gameId, uint256 wager);
    event PlayerJoined(uint256 indexed gameId, address indexed player);
    event WinnerDeclared(uint256 indexed gameId, address indexed winner, uint256 payout, uint256 fee);
    event GameTimedOut(uint256 indexed gameId);
    event DisputeInitiated(uint256 indexed gameId, address indexed initiator);
    event DisputeVoteCast(uint256 indexed gameId, address indexed arbiter, address votedWinner);
    event DisputeResolved(uint256 indexed gameId, address indexed winner);
    event ArbiterAdded(address indexed arbiter);
    event ArbiterRemoved(address indexed arbiter);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    modifier onlyArbiter() {
        require(isArbiter[msg.sender], "Not an authorized arbiter");
        _;
    }
    
    // Ensures that the game with given id is in the expected state.
    modifier gameInState(uint256 gameId, GameState expected) {
        require(games[gameId].state == expected, "Invalid game state");
        _;
    }
    
    // The default wager and fee settings are defined at deployment.
    constructor(uint256 _defaultWager, uint256 _feePercentage, uint256 _gameTimeout, uint256 _disputeWindow) {
        owner = msg.sender;
        feePercentage = _feePercentage;
        defaultWager = _defaultWager;
        gameTimeout = _gameTimeout;
        disputeWindow = _disputeWindow;
        
        // Add owner as the first arbiter
        isArbiter[owner] = true;
        arbiterList.push(owner);
        
        // Create the first game
        createGame(defaultWager);
    }
    
    // Internal function to add a game to active games list
    function _addToActiveGames(uint256 gameId) internal {
        activeGameIds.push(gameId);
        activeGameIndex[gameId] = activeGameIds.length - 1;
    }
    
    // Internal function to remove a game from active games list
    function _removeFromActiveGames(uint256 gameId) internal {
        uint256 index = activeGameIndex[gameId];
        uint256 lastIndex = activeGameIds.length - 1;
        
        if (index != lastIndex) {
            uint256 lastGameId = activeGameIds[lastIndex];
            activeGameIds[index] = lastGameId;
            activeGameIndex[lastGameId] = index;
        }
        
        activeGameIds.pop();
        delete activeGameIndex[gameId];
    }
    
    // Internal function to add a game to a player's list
    function _addToPlayerGames(address player, uint256 gameId) internal {
        playerGames[player].push(gameId);
    }
    
    // Creates a new game with specified wager
    function createGame(uint256 wagerAmount) public {
        require(wagerAmount > 0, "Wager must be greater than zero");
        
        uint256 gameId = nextGameId++;
        Game storage newGame = games[gameId];
        
        newGame.id = gameId;
        newGame.player1 = address(0);
        newGame.player2 = address(0);
        newGame.winner = address(0);
        newGame.wager = wagerAmount;
        newGame.fee = 0;
        newGame.state = GameState.Waiting;
        newGame.timestamp = block.timestamp;
        newGame.readyTimestamp = 0;
        newGame.disputeInitiator = address(0);
        newGame.disputeTimestamp = 0;
        newGame.player1Votes = 0;
        newGame.player2Votes = 0;
        
        // Add to active games
        _addToActiveGames(gameId);
        
        emit GameCreated(gameId, wagerAmount);
    }
    
    // Create multiple games at once (batch creation)
    function createGames(uint256 count, uint256 wagerAmount) external onlyOwner {
        require(count > 0 && count <= 10, "Invalid count");
        require(wagerAmount > 0, "Wager must be greater than zero");
        
        for (uint256 i = 0; i < count; i++) {
            createGame(wagerAmount);
        }
    }
    
    // Allows the owner to update the default wager for future games
    function setDefaultWager(uint256 newDefaultWager) external onlyOwner {
        require(newDefaultWager > 0, "Default wager must be greater than zero");
        defaultWager = newDefaultWager;
    }
    
    // Allows the owner to update the game timeout duration
    function setGameTimeout(uint256 newTimeout) external onlyOwner {
        require(newTimeout > 0, "Timeout must be greater than zero");
        gameTimeout = newTimeout;
    }
    
    // Allows the owner to update the dispute window duration
    function setDisputeWindow(uint256 newWindow) external onlyOwner {
        require(newWindow > 0, "Dispute window must be greater than zero");
        disputeWindow = newWindow;
    }
    
    // Add an arbiter
    function addArbiter(address arbiter) external onlyOwner {
        require(arbiter != address(0), "Invalid arbiter address");
        require(!isArbiter[arbiter], "Address is already an arbiter");
        
        isArbiter[arbiter] = true;
        arbiterList.push(arbiter);
        emit ArbiterAdded(arbiter);
    }
    
    // Remove an arbiter
    function removeArbiter(address arbiter) external onlyOwner {
        require(arbiter != owner, "Cannot remove owner from arbiters");
        require(isArbiter[arbiter], "Address is not an arbiter");
        
        // Find and remove from the list
        uint256 length = arbiterList.length;
        for (uint i = 0; i < length; i++) {
            if (arbiterList[i] == arbiter) {
                // Replace with the last element and then remove the last element
                arbiterList[i] = arbiterList[length - 1];
                arbiterList.pop();
                break;
            }
        }
        
        // Remove from the mapping
        isArbiter[arbiter] = false;
        emit ArbiterRemoved(arbiter);
    }
    
    // Get the number of arbiters
    function getArbiterCount() external view returns (uint256) {
        return arbiterList.length;
    }
    
    // Get arbiters by page (for UI pagination)
    function getArbiters(uint256 offset, uint256 limit) external view returns (address[] memory) {
        uint256 length = arbiterList.length;
        
        if (offset >= length) {
            return new address[](0);
        }
        
        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }
        
        uint256 resultLength = end - offset;
        address[] memory result = new address[](resultLength);
        
        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = arbiterList[offset + i];
        }
        
        return result;
    }
    
    // Get active games count
    function getActiveGamesCount() external view returns (uint256) {
        return activeGameIds.length;
    }
    
    // Get active games by page
    function getActiveGames(uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        uint256 length = activeGameIds.length;
        
        if (offset >= length) {
            return new uint256[](0);
        }
        
        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }
        
        uint256 resultLength = end - offset;
        uint256[] memory result = new uint256[](resultLength);
        
        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = activeGameIds[offset + i];
        }
        
        return result;
    }
    
    // Get a player's games
    function getPlayerGames(address player) external view returns (uint256[] memory) {
        return playerGames[player];
    }
    
    // Allows a player to join a specific game.
    function joinGame(uint256 gameId) external payable gameInState(gameId, GameState.Waiting) {
        Game storage game = games[gameId];
        require(msg.value == game.wager, "Deposit must equal wager");
        require(msg.sender != address(0), "Invalid address");
        
        // Check if game is full in a gas-efficient way
        bool isPlayer1Empty = game.player1 == address(0);
        bool isPlayer2Empty = game.player2 == address(0);
        require(isPlayer1Empty || isPlayer2Empty, "Game is full");
        
        // Add game to player's list
        _addToPlayerGames(msg.sender, gameId);
        
        if (isPlayer1Empty) {
            game.player1 = msg.sender;
        } else {
            game.player2 = msg.sender;
            game.state = GameState.Ready;
            game.readyTimestamp = block.timestamp;
        }
        
        emit PlayerJoined(gameId, msg.sender);
    }
    
    // Find an available game to join with the specified wager
    function findAndJoinGame() external payable {
        uint256 wager = msg.value;
        require(wager > 0, "Must send a wager amount");
        
        // Try to find a matching game
        uint256 gameToJoin = 0;
        uint256 i = 0;
        uint256 length = activeGameIds.length;
        
        while (i < length) {
            uint256 gameId = activeGameIds[i];
            Game storage game = games[gameId];
            
            if (game.state == GameState.Waiting && 
                game.wager == wager && 
                game.player1 != address(0) && 
                game.player2 == address(0)) {
                gameToJoin = gameId;
                break;
            }
            i++;
        }
        
        // If no matching game found, create a new one
        if (gameToJoin == 0) {
            uint256 newGameId = nextGameId;
            nextGameId = nextGameId + 1;
            
            Game storage newGame = games[newGameId];
            
            newGame.id = newGameId;
            newGame.player1 = msg.sender;
            newGame.player2 = address(0);
            newGame.winner = address(0);
            newGame.wager = wager;
            newGame.fee = 0;
            newGame.state = GameState.Waiting;
            newGame.timestamp = block.timestamp;
            newGame.readyTimestamp = 0;
            newGame.disputeInitiator = address(0);
            newGame.disputeTimestamp = 0;
            newGame.player1Votes = 0;
            newGame.player2Votes = 0;
            
            // Add to active games
            _addToActiveGames(newGameId);
            
            // Add game to player's list
            _addToPlayerGames(msg.sender, newGameId);
            
            emit GameCreated(newGameId, wager);
            emit PlayerJoined(newGameId, msg.sender);
        } else {
            // Join the existing game
            Game storage game = games[gameToJoin];
            game.player2 = msg.sender;
            game.state = GameState.Ready;
            game.readyTimestamp = block.timestamp;
            
            // Add game to player's list
            _addToPlayerGames(msg.sender, gameToJoin);
            
            emit PlayerJoined(gameToJoin, msg.sender);
        }
    }
    
    // Declares the winner for a specific game.
    function declareWinner(uint256 gameId, address winner) external onlyOwner gameInState(gameId, GameState.Ready) {
        Game storage game = games[gameId];
        require(winner == game.player1 || winner == game.player2, "Invalid winner");
        
        // Check if the game has timed out
        if (block.timestamp > game.readyTimestamp + gameTimeout) {
            revert("Game has timed out, use resolveTimedOutGame instead");
        }
        
        // Set the winner and complete the game.
        game.winner = winner;
        game.state = GameState.Completed;
        
        // Calculate fees and payouts
        uint256 totalPot = game.wager * 2; // Both players' wagers
        uint256 fee = (totalPot * feePercentage) / 100;
        uint256 payout = totalPot - fee;
        game.fee = fee;
        
        // Identify the losing player.
        address loser = (winner == game.player1) ? game.player2 : game.player1;
        
        // Update on-chain player statistics.
        _updatePlayerStats(winner, true);
        _updatePlayerStats(loser, false);
        
        // Remove from active games
        _removeFromActiveGames(gameId);
        
        emit WinnerDeclared(gameId, winner, payout, fee);
        
        // Transfer funds following secure patterns.
        payable(owner).transfer(fee);
        payable(winner).transfer(payout);
    }
    
    // Helper function to update player stats (gas optimization)
    function _updatePlayerStats(address player, bool isWinner) internal {
        PlayerStats storage stats = playerStats[player];
        stats.gamesPlayed++;
        
        if (isWinner) {
            stats.wins++;
        } else {
            stats.losses++;
        }
    }
    
    // Initiate a dispute for a completed game
    function initiateDispute(uint256 gameId) external gameInState(gameId, GameState.Completed) {
        Game storage game = games[gameId];
        
        // Only players in the game can initiate disputes
        require(msg.sender == game.player1 || msg.sender == game.player2, "Only game participants can dispute");
        
        // Ensure we're within the dispute window
        require(block.timestamp <= game.timestamp + disputeWindow, "Dispute window has closed");
        
        // Change game state to disputed
        game.state = GameState.Disputed;
        game.disputeInitiator = msg.sender;
        game.disputeTimestamp = block.timestamp;
        
        // Update player statistics
        playerStats[msg.sender].disputes++;
        
        // Add back to active games if it was removed
        if (activeGameIndex[gameId] == 0 && (activeGameIds.length == 0 || activeGameIds[0] != gameId)) {
            _addToActiveGames(gameId);
        }
        
        emit DisputeInitiated(gameId, msg.sender);
    }
    
    // Arbiters vote on disputed game
    function voteOnDispute(uint256 gameId, address votedWinner, string calldata reason) external onlyArbiter {
        Game storage game = games[gameId];
        require(game.state == GameState.Disputed, "Game is not disputed");
        require(votedWinner == game.player1 || votedWinner == game.player2, "Invalid winner vote");
        require(!game.hasVoted[msg.sender], "Arbiter has already voted");
        
        // Record the vote
        game.votes.push(DisputeVote({
            arbiter: msg.sender,
            votedWinner: votedWinner,
            reason: reason
        }));
        
        game.hasVoted[msg.sender] = true;
        
        // Update vote counts
        if (votedWinner == game.player1) {
            game.player1Votes++;
        } else {
            game.player2Votes++;
        }
        
        emit DisputeVoteCast(gameId, msg.sender, votedWinner);
        
        // Check if we have enough votes to resolve the dispute
        uint256 totalVotes = game.player1Votes + game.player2Votes;
        if (totalVotes > arbiterList.length / 2) {
            _resolveDispute(gameId);
        }
    }
    
    // Internal function to resolve a dispute based on arbiter votes
    function _resolveDispute(uint256 gameId) internal {
        Game storage game = games[gameId];
        
        // Determine the winner based on majority vote
        address winner;
        if (game.player1Votes > game.player2Votes) {
            winner = game.player1;
        } else if (game.player2Votes > game.player1Votes) {
            winner = game.player2;
        } else {
            // In case of a tie, the original winner stands
            winner = game.winner;
        }
        
        // If the winner changed, update statistics
        if (winner != game.winner) {
            address oldWinner = game.winner;
            address oldLoser = (oldWinner == game.player1) ? game.player2 : game.player1;
            
            // Revert the previous statistics update
            playerStats[oldWinner].wins--;
            playerStats[oldLoser].losses--;
            
            // Update with new winner
            playerStats[winner].wins++;
            address newLoser = (winner == game.player1) ? game.player2 : game.player1;
            playerStats[newLoser].losses++;
            
            // Update the game winner
            game.winner = winner;
        }
        
        // Calculate payout
        uint256 totalPot = game.wager * 2;
        uint256 fee = game.fee; // Use the original fee
        uint256 payout = totalPot - fee;
        
        // Mark as resolved
        game.state = GameState.Completed;
        
        // Remove from active games
        _removeFromActiveGames(gameId);
        
        emit DisputeResolved(gameId, winner);
        
        // Transfer funds to the winner (if different from original)
        if (winner != game.winner) {
            payable(winner).transfer(payout);
        }
    }
    
    // Resolves a game that has timed out
    function resolveTimedOutGame(uint256 gameId) external onlyOwner gameInState(gameId, GameState.Ready) {
        Game storage game = games[gameId];
        
        // Ensure the game has actually timed out
        require(block.timestamp > game.readyTimestamp + gameTimeout, "Game has not timed out yet");
        
        // Mark the game as timed out
        game.state = GameState.TimedOut;
        
        // Refund both players (minus a small fee for timeout handling)
        uint256 refundAmount = game.wager * 95 / 100; // 5% fee for timeout
        uint256 feeAmount = game.wager * 5 / 100;
        
        // Update player statistics
        playerStats[game.player1].timeouts++;
        playerStats[game.player1].gamesPlayed++;
        playerStats[game.player2].timeouts++;
        playerStats[game.player2].gamesPlayed++;
        
        // Remove from active games
        _removeFromActiveGames(gameId);
        
        // Transfer refunds
        payable(game.player1).transfer(refundAmount);
        payable(game.player2).transfer(refundAmount);
        payable(owner).transfer(feeAmount * 2); // Fee from both players
        
        emit GameTimedOut(gameId);
    }
    
    // Allows the owner to cancel a game if it's still waiting (i.e., not full).
    // This refunds any players who have joined.
    function cancelGame(uint256 gameId) external onlyOwner gameInState(gameId, GameState.Waiting) {
        Game storage game = games[gameId];
        if (game.player1 != address(0)) {
            payable(game.player1).transfer(game.wager);
        }
        
        // Mark as completed
        game.state = GameState.Completed;
        
        // Remove from active games
        _removeFromActiveGames(gameId);
    }
    
    // Check if a game has timed out
    function isGameTimedOut(uint256 gameId) external view returns (bool) {
        Game storage game = games[gameId];
        if (game.state != GameState.Ready) {
            return false;
        }
        return block.timestamp > game.readyTimestamp + gameTimeout;
    }
    
    // Get time remaining before timeout (in seconds)
    function getTimeRemaining(uint256 gameId) external view returns (uint256) {
        Game storage game = games[gameId];
        if (game.state != GameState.Ready) {
            return 0;
        }
        
        uint256 deadline = game.readyTimestamp + gameTimeout;
        if (block.timestamp >= deadline) {
            return 0;
        }
        
        return deadline - block.timestamp;
    }
    
    // Get dispute information
    function getDisputeInfo(uint256 gameId) external view returns (
        address initiator,
        uint256 timestamp,
        uint256 player1Votes,
        uint256 player2Votes,
        uint256 totalVotes
    ) {
        Game storage game = games[gameId];
        require(game.state == GameState.Disputed || 
                (game.state == GameState.Completed && game.disputeTimestamp > 0), 
                "Game was not disputed");
        
        return (
            game.disputeInitiator,
            game.disputeTimestamp,
            game.player1Votes,
            game.player2Votes,
            game.votes.length
        );
    }
    
    // Get vote details
    function getVoteDetails(uint256 gameId, uint256 voteIndex) external view returns (
        address arbiter,
        address votedWinner,
        string memory reason
    ) {
        Game storage game = games[gameId];
        require(voteIndex < game.votes.length, "Invalid vote index");
        
        DisputeVote storage vote = game.votes[voteIndex];
        return (vote.arbiter, vote.votedWinner, vote.reason);
    }
    
    // Get game details
    function getGameDetails(uint256 gameId) external view returns (
        uint256 id,
        address player1,
        address player2,
        address winner,
        uint256 wager,
        GameState state,
        uint256 timestamp,
        uint256 readyTimestamp
    ) {
        Game storage game = games[gameId];
        return (
            game.id,
            game.player1,
            game.player2,
            game.winner,
            game.wager,
            game.state,
            game.timestamp,
            game.readyTimestamp
        );
    }
    
    // Find games with a specific wager amount that are waiting for players
    function findAvailableGames(uint256 wagerAmount, uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](limit);
        uint256 count = 0;
        
        for (uint256 i = 0; i < activeGameIds.length && count < limit; i++) {
            uint256 gameId = activeGameIds[i];
            Game storage game = games[gameId];
            
            if (game.state == GameState.Waiting && 
                game.wager == wagerAmount && 
                game.player1 != address(0) && 
                game.player2 == address(0)) {
                result[count++] = gameId;
            }
        }
        
        // Resize the array to the actual count
        uint256[] memory trimmedResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            trimmedResult[i] = result[i];
        }
        
        return trimmedResult;
    }
    
    // Check for timed out games and return their IDs
    function getTimedOutGames(uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](limit);
        uint256 count = 0;
        
        for (uint256 i = 0; i < activeGameIds.length && count < limit; i++) {
            uint256 gameId = activeGameIds[i];
            Game storage game = games[gameId];
            
            if (game.state == GameState.Ready && 
                block.timestamp > game.readyTimestamp + gameTimeout) {
                result[count++] = gameId;
            }
        }
        
        // Resize the array to the actual count
        uint256[] memory trimmedResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            trimmedResult[i] = result[i];
        }
        
        return trimmedResult;
    }
}
