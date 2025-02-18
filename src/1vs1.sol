// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WesternShootout {
    address public owner;
    uint256 public feePercentage;
    uint256 public currentGameId;

    // On-chain player statistics
    struct PlayerStats {
        uint wins;
        uint losses;
        uint gamesPlayed;
    }
    mapping(address => PlayerStats) public playerStats;
    
    // Game state enum
    enum GameState { Waiting, Ready, Completed }
    
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
    }
    
    // Mapping from game id to game details
    mapping(uint256 => Game) public games;
    
    // Events for logging
    event GameCreated(uint256 indexed gameId, uint256 wager);
    event PlayerJoined(uint256 indexed gameId, address player);
    event WinnerDeclared(uint256 indexed gameId, address winner, uint256 payout, uint256 fee);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    // Ensures that the game with given id is in the expected state.
    modifier gameInState(uint256 gameId, GameState expected) {
        require(games[gameId].state == expected, "Invalid game state");
        _;
    }
    
    // The wager and fee settings are defined at deployment.
    constructor(uint256 _wager, uint256 _feePercentage) {
        owner = msg.sender;
        feePercentage = _feePercentage;
        currentGameId = 1;
        // Initialize the first game
        games[currentGameId] = Game({
            id: currentGameId,
            player1: address(0),
            player2: address(0),
            winner: address(0),
            wager: _wager,
            fee: 0,
            state: GameState.Waiting,
            timestamp: block.timestamp
        });
        emit GameCreated(currentGameId, _wager);
    }
    
    // Allows a player to join the current active game.
    function joinGame() external payable gameInState(currentGameId, GameState.Waiting) {
        Game storage game = games[currentGameId];
        require(msg.value == game.wager, "Deposit must equal wager");
        require(msg.sender != address(0), "Invalid address");
        require(game.player1 == address(0) || game.player2 == address(0), "Game is full");
        
        if (game.player1 == address(0)) {
            game.player1 = msg.sender;
        } else {
            game.player2 = msg.sender;
            game.state = GameState.Ready; // Game is ready when two players have joined.
        }
        emit PlayerJoined(currentGameId, msg.sender);
    }
    
    // Declares the winner for the current active game.
    function declareWinner(address winner) external onlyOwner gameInState(currentGameId, GameState.Ready) {
        Game storage game = games[currentGameId];
        require(winner == game.player1 || winner == game.player2, "Invalid winner");
        
        // Set the winner and complete the game.
        game.winner = winner;
        game.state = GameState.Completed;
        uint256 totalPot = address(this).balance;
        uint256 fee = (totalPot * feePercentage) / 100;
        uint256 payout = totalPot - fee;
        game.fee = fee;
        
        // Identify the losing player.
        address loser = (winner == game.player1) ? game.player2 : game.player1;
        
        // Update on-chain player statistics.
        playerStats[winner].wins++;
        playerStats[winner].gamesPlayed++;
        playerStats[loser].losses++;
        playerStats[loser].gamesPlayed++;
        
        emit WinnerDeclared(currentGameId, winner, payout, fee);
        
        // Transfer funds following secure patterns.
        payable(owner).transfer(fee);
        payable(winner).transfer(payout);
        
        // Start a new game by incrementing the game id.
        currentGameId++;
        games[currentGameId] = Game({
            id: currentGameId,
            player1: address(0),
            player2: address(0),
            winner: address(0),
            wager: game.wager, // Keeping the same wager amount; could be modified per game if desired.
            fee: 0,
            state: GameState.Waiting,
            timestamp: block.timestamp
        });
        emit GameCreated(currentGameId, game.wager);
    }
    
    // Allows the owner to cancel the current game if it's still waiting (i.e., not full).
    // This refunds any players who have joined.
    function cancelGame() external onlyOwner gameInState(currentGameId, GameState.Waiting) {
        Game storage game = games[currentGameId];
        if (game.player1 != address(0)) {
            payable(game.player1).transfer(game.wager);
        }
        if (game.player2 != address(0)) {
            payable(game.player2).transfer(game.wager);
        }
        game.state = GameState.Completed;
        
        // Start a new game.
        currentGameId++;
        games[currentGameId] = Game({
            id: currentGameId,
            player1: address(0),
            player2: address(0),
            winner: address(0),
            wager: game.wager,
            fee: 0,
            state: GameState.Waiting,
            timestamp: block.timestamp
        });
        emit GameCreated(currentGameId, game.wager);
    }
}
