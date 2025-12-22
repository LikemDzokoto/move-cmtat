# Move CMTAT - Capital Markets Technology Association Token Standard

> A Move implementation of Switzerland's Capital Markets Technology Association token standard for IOTA/Sui

**⚠️ This project has not undergone an audit and is provided as-is without any warranties.**

## Overview

[CMTAT](https://cmta.ch/standards/cmta-token-cmtat) is a framework for the tokenization of securities and other financial instruments in compliance with local regulations. This project implements CMTAT in Move, enabling financial institutions to adopt the standard on Move-based blockchains like IOTA and Sui.

This implementation is based on the [Cairo CMTAT version](https://github.com/0xsereel/cairo-cmtat) and the original [Solidity CMTAT](https://github.com/CMTA/CMTAT).

## Features

✅ **CMTAT Framework Implementation**  
✅ **Four Module Variants** - Light, Allowlist, Debt, and Standard implementations  
✅ **ERC20-Compatible** with regulatory extensions  
✅ **Role-Based Access Control** with role getter functions  
✅ **Batch Operations** for efficient multi-address operations  
✅ **Transfer Validation** (ERC-1404 compatible)  
✅ **Move Resource Model** for security and composability  

## Quick Start

### Prerequisites

- Move CLI installed
- IOTA/Sui wallet configured

### Build & Test

```bash
# Build all contracts
sui move build

# Run tests
sui move test

# Run specific test
sui move test --filter test_name
```

### Deploy

```bash
# Deploy using script
./scripts/deploy.sh
```

## Module Overview

### 🔹 Light CMTAT

**Minimal feature set for basic CMTAT compliance**

**Features:**
- Basic ERC20 functionality
- Minting (mint, batch_mint)
- Burning (burn, burn_from, batch_burn, forced_burn, burn_and_mint)
- Pause/Unpause/Deactivate
- Address freezing (set_address_frozen, batch_set_address_frozen)
- Information management (terms, information, token_id)
- Batch balance queries
- 4 Role constants (DEFAULT_ADMIN, MINTER, PAUSER, ENFORCER)

**Use Cases:** Standard token deployments, simple compliance requirements

---

### 🔹 Allowlist CMTAT

**All Light features plus allowlist functionality**

**Additional Features:**
- Allowlist control (enable_allowlist, set_address_allowlist, batch_set_address_allowlist)
- Partial token freezing (freeze_partial_tokens, unfreeze_partial_tokens)
- Active balance queries (get_active_balance_of)
- Engine management (snapshot_engine, document_engine)
- 9 Role constants (includes ERC20ENFORCER, SNAPSHOOTER, DOCUMENT, EXTRA_INFORMATION)

**Use Cases:** Regulated tokens with whitelist requirements, KYC/AML compliance

---

### 🔹 Debt CMTAT

**Specialized for debt securities**

**Debt-Specific Features:**
- Debt information management (debt, set_debt)
- Credit events tracking (credit_events, set_credit_events)
- Debt engine integration (debt_engine, set_debt_engine)
- Default flagging (flag_default)
- All Allowlist features (except allowlist-specific)
- 10 Role constants (includes DEBT_ROLE)

**Use Cases:** Corporate bonds, structured debt products, fixed income securities

---

### 🔹 Standard CMTAT

**Full feature set with transfer validation**

**Advanced Features:**
- Transfer validation (restriction_code, message_for_transfer_restriction)
- ERC-1404 compliance
- All core CMTAT features
- 9 Role constants

**Use Cases:** Advanced compliance, institutional securities with transfer validation

---

## Feature Comparison Matrix

| Feature | Light | Allowlist | Debt | Standard |
|---------|-------|-----------|------|----------|
| **Basic ERC20** | ✅ | ✅ | ✅ | ✅ |
| **Minting** | ✅ | ✅ | ✅ | ✅ |
| **Burning** | ✅ | ✅ | ✅ | ✅ |
| **Forced Burn** | ✅ | ❌ | ❌ | ❌ |
| **Pause/Unpause** | ✅ | ✅ | ✅ | ✅ |
| **Deactivation** | ✅ | ✅ | ✅ | ✅ |
| **Address Freezing** | ✅ | ✅ | ✅ | ✅ |
| **Partial Token Freezing** | ❌ | ✅ | ✅ | ✅ |
| **Batch Operations** | ✅ | ✅ | ✅ | ✅ |
| **Information Management** | ✅ | ✅ | ✅ | ✅ |
| **Allowlist** | ❌ | ✅ | ❌ | ❌ |
| **Debt Management** | ❌ | ❌ | ✅ | ❌ |
| **Transfer Validation** | ❌ | ❌ | ❌ | ✅ |
| **Engine Integration** | ❌ | ✅ | ✅ | ✅ |
| **Role Count** | 4 | 9 | 10 | 9 |

---

## Architecture

```
move-cmtat/
├── Move.toml
├── README.md
├── sources/
│   ├── contracts/
│   │   ├── light_cmtat.move       # Minimal CMTAT (4 roles)
│   │   ├── allowlist_cmtat.move   # With allowlist (9 roles)
│   │   ├── debt_cmtat.move        # For debt securities (10 roles)
│   │   └── standard_cmtat.move    # Full feature set (9 roles)
│   ├── engines/
│   │   ├── rule_engine.move       # Transfer restrictions
│   │   └── snapshot_engine.move   # Balance snapshots
│   ├── components/
│   │   ├── base.move              # Base ERC20 functionality
│   │   ├── pause.move             # Pause/Unpause logic
│   │   ├── freeze.move            # Address freezing
│   │   ├── allowlist.move         # Allowlist management
│   │   ├── debt.move              # Debt functionality
│   │   └── validation.move        # Transfer validation
│   └── interfaces/
│       └── icmtat.move            # Interface definitions
├── tests/
│   ├── light_cmtat_tests.move
│   ├── allowlist_cmtat_tests.move
│   ├── debt_cmtat_tests.move
│   └── standard_cmtat_tests.move
└── scripts/
    └── deploy.sh                   # Deployment automation
```

---

## Security Features

### Role-Based Access Control

- **DEFAULT_ADMIN_ROLE**: Master administrator, can grant/revoke all roles
- **MINTER_ROLE**: Can create new tokens
- **BURNER_ROLE**: Can destroy tokens
- **PAUSER_ROLE**: Can pause/unpause contract
- **ENFORCER_ROLE**: Can freeze/unfreeze addresses
- **ERC20ENFORCER_ROLE**: Can freeze partial tokens
- **SNAPSHOOTER_ROLE**: Can create snapshots
- **DOCUMENT_ROLE**: Can manage documents
- **EXTRA_INFORMATION_ROLE**: Can update token metadata
- **DEBT_ROLE**: Can manage debt parameters

### Transfer Restrictions

All modules implement transfer restrictions:
- Pause state check
- Sender/recipient freeze check
- Active balance validation (for partial freezing)
- Custom validation (via transfer validation in Standard)

---

## License

Mozilla Public License 2.0 (MPL-2.0)

---

## Links

- **CMTAT**: https://www.cmtat.org
- **Cairo CMTAT**: https://github.com/0xsereel/cairo-cmtat
- **CMTAT Solidity**: https://github.com/CMTA/CMTAT
- **IOTA**: https://www.iota.org
- **Sui Move**: https://docs.sui.io

---

**Built for compliant securities on Move-based blockchains**

*Version 0.1.0 - Initial Implementation*
