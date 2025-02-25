# 🤠 WesternShootout Smart Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Network: Polygon Amoy](https://img.shields.io/badge/Network-Polygon%20Amoy-8247E5)](https://amoy.polygon.technology/)

## 📜 Overview

WesternShootout is a feature-rich smart contract that enables 1vs1 wagered gameplay with automated prize distribution, dispute resolution, and comprehensive player statistics tracking. The contract manages multiple concurrent game sessions, player matchmaking, and secure prize distribution while maintaining a complete history of games and player statistics on-chain.

**Contract Address (Polygon AMOY):** `0x17B6f309E57F684F643C4C3F8A91C6a8219C53f0`

## ✨ Key Features

- 🎮 **Multi-game Support**: Run multiple concurrent games simultaneously
- 💰 **Customizable Wagers**: Each game can have its own wager amount
- ⏱️ **Timeout Mechanism**: Fair handling of abandoned or stalled games
- ⚖️ **Dispute Resolution**: Contest results with arbiter voting system
- 🚀 **Gas Optimized**: Efficient data structures and operations
- 📊 **On-chain Statistics**: Comprehensive player performance tracking
- 🔍 **Game Discovery**: Find games matching specific criteria
- 🔄 **Automatic Matchmaking**: Join existing games or create new ones

## 🏗️ Contract Architecture

### Game States
- **Waiting**: New game waiting for players to join
- **Ready**: Two players have joined, game is in progress
- **Completed**: Game has ended with a winner declared
- **TimedOut**: Game was abandoned and resolved via timeout
- **Disputed**: Game outcome is being contested by a player

### Core Components

#### 1. Game Structure
Each game contains:
- Unique game ID
- Player addresses (player1 & player2)
- Winner address
- Wager amount
- Fee amount
- Current state
- Timestamps (creation, ready state, dispute)
- Dispute information and votes

#### 2. Player Statistics
Tracks for each player:
- Total wins
- Total losses
- Games played
- Timeouts
- Disputes initiated

#### 3. Arbiter System
For dispute resolution:
- List of approved arbiters
- Voting mechanism
- Dispute tracking
- Resolution based on majority vote

## 🎯 Main Functions

### For Players

#### Game Participation
- `joinGame(uint256 gameId)`: Join a specific game by ID
- `findAndJoinGame()`: Automatically find or create a game matching your wager

#### Game Information
- `getPlayerGames(address player)`: Get all games a player is participating in
- `getGameDetails(uint256 gameId)`: Get complete information about a game
- `findAvailableGames(uint256 wagerAmount, uint256 limit)`: Find games with specific wager

#### Dispute Handling
- `initiateDispute(uint256 gameId)`: Contest the outcome of a completed game
- `getDisputeInfo(uint256 gameId)`: Get information about a dispute

### For Game Operators

#### Game Management
- `createGame(uint256 wagerAmount)`: Create a new game with specified wager
- `createGames(uint256 count, uint256 wagerAmount)`: Create multiple games at once
- `declareWinner(uint256 gameId, address winner)`: Declare the winner of a game
- `cancelGame(uint256 gameId)`: Cancel an incomplete game and refund players

#### Configuration
- `setDefaultWager(uint256 newDefaultWager)`: Set the default wager amount
- `setGameTimeout(uint256 newTimeout)`: Set the timeout duration
- `setDisputeWindow(uint256 newWindow)`: Set the dispute window duration

#### Timeout Handling
- `resolveTimedOutGame(uint256 gameId)`: Resolve a game that has timed out
- `getTimedOutGames(uint256 limit)`: Get a list of games that have timed out
- `isGameTimedOut(uint256 gameId)`: Check if a specific game has timed out

### For Arbiters

#### Dispute Resolution
- `voteOnDispute(uint256 gameId, address votedWinner, string calldata reason)`: Vote on a disputed game
- `getVoteDetails(uint256 gameId, uint256 voteIndex)`: Get details of a specific vote

#### Arbiter Management
- `addArbiter(address arbiter)`: Add a new arbiter (owner only)
- `removeArbiter(address arbiter)`: Remove an arbiter (owner only)
- `getArbiters(uint256 offset, uint256 limit)`: Get the list of arbiters

## 📡 Events

The contract emits the following events:
- `GameCreated`: When a new game is created
- `PlayerJoined`: When a player joins a game
- `WinnerDeclared`: When a winner is declared
- `GameTimedOut`: When a game times out
- `DisputeInitiated`: When a player initiates a dispute
- `DisputeVoteCast`: When an arbiter votes on a dispute
- `DisputeResolved`: When a dispute is resolved
- `ArbiterAdded`: When a new arbiter is added
- `ArbiterRemoved`: When an arbiter is removed

## 🔧 Integration Guide

### Basic Integration

1. **Connect to the Contract**
```javascript
// Using ethers.js
const contractAddress = "0x17B6f309E57F684F643C4C3F8A91C6a8219C53f0";
const westernShootout = new ethers.Contract(contractAddress, WesternShootoutABI, provider);
```

2. **Create or Join a Game**
```javascript
// Create a new game with 0.01 POL wager
const tx = await westernShootout.createGame(ethers.utils.parseEther("0.01"));
await tx.wait();

// Or find and join a game with 0.01 POL wager
const tx = await westernShootout.findAndJoinGame({
  value: ethers.utils.parseEther("0.01")
});
await tx.wait();
```

3. **Monitor Game Events**
```javascript
// Listen for PlayerJoined events
westernShootout.on("PlayerJoined", (gameId, player) => {
  console.log(`Player ${player} joined game ${gameId}`);
});

// Listen for WinnerDeclared events
westernShootout.on("WinnerDeclared", (gameId, winner, payout, fee) => {
  console.log(`Game ${gameId} won by ${winner} with payout ${payout}`);
});
```

4. **Declare Winner**
```javascript
// Only callable by contract owner
const tx = await westernShootout.declareWinner(gameId, winnerAddress);
await tx.wait();
```

### Advanced Integration

1. **Handle Timeouts**
```javascript
// Check if a game has timed out
const isTimedOut = await westernShootout.isGameTimedOut(gameId);

// Get time remaining before timeout
const timeRemaining = await westernShootout.getTimeRemaining(gameId);

// Resolve a timed out game (owner only)
if (isTimedOut) {
  const tx = await westernShootout.resolveTimedOutGame(gameId);
  await tx.wait();
}
```

2. **Dispute Resolution**
```javascript
// Initiate a dispute (must be a player in the game)
const tx = await westernShootout.initiateDispute(gameId);
await tx.wait();

// Vote on a dispute (must be an arbiter)
const tx = await westernShootout.voteOnDispute(gameId, playerAddress, "Evidence shows this player won");
await tx.wait();

// Get dispute information
const disputeInfo = await westernShootout.getDisputeInfo(gameId);
```

3. **Query Player Statistics**
```javascript
const playerStats = await westernShootout.playerStats(playerAddress);
console.log(`Wins: ${playerStats.wins}`);
console.log(`Losses: ${playerStats.losses}`);
console.log(`Games Played: ${playerStats.gamesPlayed}`);
console.log(`Timeouts: ${playerStats.timeouts}`);
console.log(`Disputes: ${playerStats.disputes}`);
```

## 🎮 Unreal Engine 5 Integration

WesternShootout is designed to integrate seamlessly with Unreal Engine 5 games using ThirdWeb Engine.

### Setup with ThirdWeb Engine

1. **Initialize ThirdWeb Engine**
```cpp
// In your game initialization
void AMyGameMode::InitializeBlockchain()
{
    // Initialize ThirdWeb with Polygon Amoy network
    ThirdWebSubsystem = GEngine->GetEngineSubsystem<UThirdWebSubsystem>();
    ThirdWebSubsystem->Initialize(EChain::PolygonAmoy);
    
    // Connect to WesternShootout contract
    ContractAddress = TEXT("0x17B6f309E57F684F643C4C3F8A91C6a8219C53f0");
    ThirdWebSubsystem->ConnectToContract(ContractAddress, WesternShootoutABI);
}
```

2. **Create Blueprint Functions**
```cpp
// Create a game with wager
UFUNCTION(BlueprintCallable, Category = "Blockchain")
void CreateGame(float WagerAmount)
{
    FString FunctionName = TEXT("createGame");
    TArray<FString> Params;
    Params.Add(FString::Printf(TEXT("%f"), WagerAmount * 1e18)); // Convert to wei
    
    ThirdWebSubsystem->CallContractFunction(ContractAddress, FunctionName, Params, true);
}

// Join a game
UFUNCTION(BlueprintCallable, Category = "Blockchain")
void JoinGame(int32 GameId, float WagerAmount)
{
    FString FunctionName = TEXT("joinGame");
    TArray<FString> Params;
    Params.Add(FString::Printf(TEXT("%d"), GameId));
    
    ThirdWebSubsystem->CallContractFunction(
        ContractAddress, 
        FunctionName, 
        Params, 
        true, 
        WagerAmount * 1e18 // Value in wei
    );
}
```

3. **Listen for Events**
```cpp
// Set up event listeners
void AMyGameMode::SetupEventListeners()
{
    ThirdWebSubsystem->ListenForContractEvent(
        ContractAddress,
        TEXT("PlayerJoined"),
        FOnContractEventReceived::CreateUObject(this, &AMyGameMode::OnPlayerJoined)
    );
    
    ThirdWebSubsystem->ListenForContractEvent(
        ContractAddress,
        TEXT("WinnerDeclared"),
        FOnContractEventReceived::CreateUObject(this, &AMyGameMode::OnWinnerDeclared)
    );
}

// Event handler
void AMyGameMode::OnPlayerJoined(const FString& EventData)
{
    // Parse event data and update game state
    // ...
    
    // Update UI
    if (GameLobbyWidget)
    {
        GameLobbyWidget->UpdatePlayerList();
    }
}
```

### Game Implementation Examples

#### Example: Western Duel Game

1. **Game Flow**
```
Player enters lobby → Connects wallet → Creates/joins game → 
Waits for opponent → Plays duel → Winner determined → 
Result submitted to blockchain → Prizes distributed
```

2. **Timeout Handling**
```
Game starts → Timer begins counting down → 
If player disconnects → Warning displayed → 
If timeout occurs → resolveTimedOutGame called → 
Players receive partial refunds
```

3. **Dispute Resolution**
```
Game ends → Result declared → Losing player can dispute → 
Dispute evidence collected → Arbiters vote → 
Majority decision enforced → Winner receives prize
```

## 🔐 Security Features

- ✅ Secure fund handling with proper balance checks
- ✅ State validation to prevent invalid operations
- ✅ Owner-only sensitive operations
- ✅ Protected winner declaration
- ✅ Automated fee calculation and distribution
- ✅ Timeout protection against abandoned games
- ✅ Dispute resolution for contested outcomes
- ✅ Gas-optimized operations

## 🧪 Testing on Polygon Amoy

To interact with the contract on Polygon Amoy testnet:

1. **Get Test POL**
   - Visit the [Polygon Amoy Faucet](https://amoy.polygon.technology/faucet)
   - Request test POL for your wallet

2. **Connect to Amoy Network**
   - Network Name: Polygon Amoy
   - RPC URL: https://rpc-amoy.polygon.technology/
   - Chain ID: 80002
   - Currency Symbol: POL
   - Block Explorer: https://amoy.polygonscan.com/

3. **Test Transactions**
   - Start with small wager amounts
   - Monitor transaction status on the explorer
   - Check game state after each operation

## 📚 Development Resources

- [Contract Source Code](https://github.com/arkadia-park/1vs1-contract)
- [API Documentation](https://github.com/arkadia-park/1vs1-contract/docs)
- [ThirdWeb Engine Documentation](https://docs.thirdweb.com/engine)
- [Unreal Engine Integration Examples](https://github.com/arkadia-park/1vs1-contract/examples)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact

For questions or support, please open an issue on this repository or contact us at:
- Twitter: [@Arkadia_Park](https://x.com/Arkadia_Park)
- Discord: [Join our server](https://discord.com/arkadia-park)

---

Built with ❤️ by the Arkadia Park team