# WesternShootout Smart Contract

## Deployment
**Contract Address (Polygon AMOY):** `0x4B61a504f67789d24Fff761b9650C97F8292c448`

## Overview
WesternShootout is a smart contract that enables 1vs1 wagered gameplay with automated prize distribution and player statistics tracking. The contract manages game sessions, player matchmaking, and secure prize distribution while maintaining a complete history of games and player statistics on-chain.

## Key Features
- 🎮 Automated game session management
- 💰 Secure wager handling and prize distribution
- 📊 On-chain player statistics tracking
- 🏆 Fair winner declaration system
- 🔄 Automatic new game creation
- ⚡ Owner-controlled game management

## Contract Architecture

### Game States
- **Waiting**: New game waiting for players to join
- **Ready**: Two players have joined, game is in progress
- **Completed**: Game has ended with a winner declared

### Core Components

#### 1. Game Structure
Each game contains:
- Unique game ID
- Player addresses (player1 & player2)
- Winner address
- Wager amount
- Fee amount
- Current state
- Timestamp

#### 2. Player Statistics
Tracks for each player:
- Total wins
- Total losses
- Games played

## Main Functions

### For Players
- `joinGame()`: Join the current active game by sending the required wager
  - Must send exact wager amount
  - First player becomes player1
  - Second player becomes player2
  - Game state changes to Ready when full

### For Contract Owner
- `declareWinner(address winner)`: Declare the game winner and distribute prizes
  - Validates winner is a participant
  - Calculates and distributes fees
  - Updates player statistics
  - Creates new game automatically
- `cancelGame()`: Cancel an incomplete game
  - Only works in Waiting state
  - Refunds joined players
  - Creates new game automatically

## Events
The contract emits the following events:
- `GameCreated`: When a new game starts
- `PlayerJoined`: When a player joins a game
- `WinnerDeclared`: When a winner is declared

## Integration Guide
### With Game Clients
1. Monitor `GameCreated` events for new games
2. Call `joinGame()` when player wants to participate
3. Track `PlayerJoined` events to update game status
4. Listen for `WinnerDeclared` events to update UI and player balances

### Player Statistics
Query `playerStats` mapping with player's address to get:
- Win count
- Loss count
- Total games played

## Security Features
- Secure fund handling
- State validation checks
- Owner-only sensitive operations
- Protected winner declaration
- Automated fee calculation and distribution