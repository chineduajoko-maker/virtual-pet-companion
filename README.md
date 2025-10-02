# Virtual Pet Companion

A gamified blockchain application where users take care of AI pets that adapt to their lifestyle habits. Built on the Stacks blockchain using Clarity smart contracts.

## Overview

Virtual Pet Companion revolutionizes digital pet care by creating an interactive, blockchain-based ecosystem where virtual pets respond and adapt to their owners' real-world lifestyle choices. The platform encourages healthy habits through gamified interactions and rewards users for maintaining consistent care routines.

## Key Features

### 🐾 Adaptive AI Pets
- Virtual pets with unique personalities and behaviors
- Dynamic mood and health states based on user interactions
- Evolution and growth system tied to care consistency
- Personalized pet responses to owner's lifestyle patterns

### 🏆 Gamified Health Rewards
- Token rewards for healthy lifestyle choices
- Achievement system for consistent pet care
- Multiplier bonuses for extended care streaks
- Integration with fitness and wellness activities

### 🔗 Blockchain Integration
- Immutable pet ownership and breeding records
- Transparent reward distribution system
- Secure pet trading and marketplace functionality
- Decentralized achievement verification

## Smart Contracts Architecture

### Pet Behavior Engine (`pet-behavior-engine.clar`)
The core contract that manages pet states, interactions, and behavioral responses:

- **Pet State Management**: Health, happiness, hunger, and energy levels
- **Interaction System**: Feeding, playing, training, and resting mechanics
- **Behavior Simulation**: Mood changes based on care patterns
- **Evolution Tracking**: Pet growth and development milestones
- **Care History**: Immutable record of all pet interactions

### Reward System (`reward-system.clar`)
Handles the gamification and incentive mechanisms:

- **Token Distribution**: Automatic rewards for pet care activities
- **Achievement Tracking**: Milestone-based reward system
- **Streak Multipliers**: Bonus rewards for consistent care
- **Health Integration**: Rewards tied to healthy lifestyle choices
- **Leaderboard System**: Community ranking and competitions

## Technical Specifications

### Blockchain Technology
- **Platform**: Stacks Blockchain
- **Smart Contract Language**: Clarity
- **Token Standard**: SIP-010 (Fungible Token Standard)
- **NFT Standard**: SIP-009 (Non-Fungible Token Standard)

### Data Structures
- Pet attributes stored as maps with composite keys
- User profiles with care statistics and achievement records
- Reward pools with automatic distribution mechanisms
- Time-locked features for preventing exploitation

### Security Features
- Input validation for all user interactions
- Access controls for pet ownership verification
- Rate limiting for reward claiming
- Anti-gaming mechanisms for streak calculations

## Installation & Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - Smart contract development tool
- [Node.js](https://nodejs.org/) (v16 or higher)
- [Git](https://git-scm.com/)

### Setup Instructions
```bash
# Clone the repository
git clone https://github.com/chineduajoko-maker/virtual-pet-companion.git
cd virtual-pet-companion

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
clarinet test
```

## Usage Examples

### Creating a New Pet
```clarity
;; Create a new virtual pet
(contract-call? .pet-behavior-engine create-pet u"Buddy" u"Dog")
```

### Feeding Your Pet
```clarity
;; Feed your pet to increase happiness
(contract-call? .pet-behavior-engine feed-pet u1)
```

### Claiming Rewards
```clarity
;; Claim daily care rewards
(contract-call? .reward-system claim-daily-reward)
```

## Roadmap

### Phase 1: Core Functionality ✅
- Basic pet creation and interaction system
- Simple reward mechanism
- Health and happiness tracking

### Phase 2: Enhanced Features (Q1 2025)
- Pet breeding and genetics system
- Advanced AI behavior patterns
- Social features and pet interactions

### Phase 3: Ecosystem Expansion (Q2 2025)
- Mobile app integration
- Real-world fitness tracker connectivity
- Marketplace for pet accessories and items

### Phase 4: Community Features (Q3 2025)
- Guild system and team competitions
- User-generated content tools
- Advanced analytics and insights

## Contributing

We welcome contributions from the community! Please read our contributing guidelines and submit pull requests for any improvements.

### Development Workflow
1. Fork the repository
2. Create a feature branch
3. Write comprehensive tests
4. Ensure all contracts pass `clarinet check`
5. Submit a pull request with detailed description

## Testing

The project includes comprehensive test suites for all smart contracts:

```bash
# Run all tests
clarinet test

# Run specific contract tests
clarinet test tests/pet-behavior-engine_test.ts
clarinet test tests/reward-system_test.ts
```

## Security Considerations

- All user inputs are validated before processing
- Pet ownership is verified for all interactions
- Reward calculations include anti-manipulation safeguards
- Time-based operations use block height for consistency

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, please join our [Discord community](https://discord.gg/virtual-pet-companion) or create an issue on GitHub.

## Acknowledgments

- Built with [Clarinet](https://github.com/hirosystems/clarinet)
- Powered by [Stacks Blockchain](https://stacks.co)
- Inspired by the Tamagotchi and modern fitness gamification concepts

---

*Happy pet caring! 🐾*