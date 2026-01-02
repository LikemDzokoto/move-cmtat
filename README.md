# Move CMTAT - Capital Markets Technology Association Token Standard

> A native IOTA Move implementation of Switzerland's Capital Markets Technology Association token standard

**⚠️ This project has not undergone an audit and is provided as-is without any warranties.**

---

## Overview

[CMTAT](https://cmta.ch/standards/cmta-token-cmtat) is a framework for the tokenization of securities and other financial instruments in compliance with local regulations. This project implements CMTAT natively in IOTA Move, enabling financial institutions to adopt the standard with architecture optimized for IOTA's object model.

**Key Differentiator:** This implementation builds CMTAT's regulatory features **on top of** IOTA's native `Coin<T>` architecture, rather than reimplementing token functionality from scratch. This approach leverages IOTA's VM-enforced security, object model, and parallel execution capabilities while adding CMTAT compliance features as modular extensions.

---

## Why IOTA Move for CMTAT

### Regulatory Compliance at the Protocol Level

IOTA Move's type system and object model enable compliance enforcement that would be impossible or expensive on EVM:

- **Type-safe compliance rules** enforced by the compiler, not just runtime checks
- **Capability-based access control** ensures only authorized parties can perform regulated operations
- **Object ownership model** mirrors real-world securities ownership - if you possess the object, you own the asset
- **Separate compliance state objects** cannot be bypassed or manipulated by contract logic

### Security by Design

- **Capability objects** (AdminCap, MintCap, etc.) prevent privilege escalation - authorization is tied to physical possession
- **Resource ownership model** eliminates reentrancy attacks on token operations
- **Native type system** prevents integer overflow/underflow
- **VM-enforced supply integrity** through `TreasuryCap` - cannot be manipulated by contract code

### Performance Advantages

- **Parallel execution** enabled by separate shared objects - multiple users can read token metadata simultaneously
- **No balanceOf() overhead** - balances are stored in user-owned `Coin<CMTAT>` objects, not contract mappings
- **Native token operations** optimized by the VM (mint, burn, split, join)
- **Batch operations** are more efficient due to object model

### Future-Proof Architecture

- **Composable components** - compliance features are separate objects that can be mixed and matched
- **Easy to extend** - new compliance rules can be added without modifying core token logic
- **Native upgrade patterns** - components can be upgraded independently
- **Interoperable** - works seamlessly with other IOTA Move contracts

---

## IOTA Native Architecture

### Object Model Fundamentals

Everything in IOTA Move is an object with capabilities. This fundamental difference from EVM's account model enables superior security and composability for securities.

#### Ownership = Possession
- If you possess a `Coin<CMTAT>`, you own those tokens
- If you possess a `MintCap`, you can mint tokens
- If you possess a `AdminCap`, you can administrate the token
- **No need for "isApproved" or "allowance" mappings** - possession is permission

#### Shared Objects for Global State

Global state (token info, compliance rules) is stored in shared objects accessible by all:

```move
// Token metadata and supply control
public struct LightCMTAT has key {
    id: UID,
    token_info: TokenInfo,
    treasury_cap: TreasuryCap<CMTAT>,
}

// Compliance state
public struct ComplianceState has key {
    id: UID,
    pause_state: PauseState,
    freeze_state: FreezeState,
    allowlist_state: AllowlistState,  // optional
}
```

This enables **parallel execution** - multiple users can read token metadata simultaneously without blocking each other.

### Native Token Patterns

#### 1. Coin<T> for Balances

Instead of `mapping(address => uint256)`, each user owns `Coin<CMTAT>` objects:

```move
// User's wallet contains:
Coin<CMTAT> { value: 1000 }  // 1000 tokens

// Transfer is native and optimized:
transfer::public_transfer(coins, recipient_address);
```

**Benefits:**
- Users can split/join coins natively
- Native operations optimized by VM
- No contract storage overhead for balances
- Explicit ownership model
- Prevents balance manipulation

#### 2. TreasuryCap<T> for Supply Control

Mint/burn authority is a `TreasuryCap<CMTAT>` object enforced by the VM:

```move
public struct LightCMTAT has key {
    id: UID,
    treasury_cap: TreasuryCap<CMTAT>,  // VM-enforced supply control
}

// Minting is protected:
public fun mint(
    mint_cap: &MintCap,
    treasury_cap: &mut TreasuryCap<CMTAT>,
    amount: u64,
    ctx: &mut TxContext
): Coin<CMTAT> {
    coin::mint(treasury_cap, amount, ctx)
}
```

**Benefits:**
- VM-enforced total supply - cannot be manipulated
- Cryptographically secure supply control
- Single point of authority
- Capability can be transferred between admins

#### 3. Capability-Based Access Control

Instead of role mappings, we use capability objects:

```move
// Capability types (owned by authorized addresses)
public struct AdminCap has key, store { id: UID }
public struct MintCap has key, store { id: UID }
public struct PauseCap has key, store { id: UID }
public struct FreezeCap has key, store { id: UID }

// Capability-protected function
public entry fun mint(
    mint_cap: &MintCap,  // ← Must possess this object
    token: &mut LightCMTAT,
    compliance_state: &ComplianceState,
    to: address,
    amount: u64,
    ctx: &mut TxContext
) {
    // Only MintCap holder can call this - no role mapping lookup needed
    pause::require_not_paused(&compliance_state.pause_state);
    let coins = base::mint(&mut token.treasury_cap, amount, ctx);
    transfer::public_transfer(coins, to);
}
```

**Key Concept:** Physical possession of the capability object is authorization. You can transfer capabilities between addresses just like you transfer tokens:

```move
// Transfer MintCap to new admin:
transfer::public_transfer(mint_cap, new_admin_address);
```

### Component Architecture

Each compliance feature is a separate component with its own state object:

```
┌─────────────────────────────────────────────────────────┐
│                     User Wallet                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Coin<CMTAT>  │  │  AdminCap    │  │  MintCap     │   │
│  │ (balance)    │  │ (admin)      │  │ (minter)     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
                        │
                        │ transfers with compliance checks
                        ▼
┌─────────────────────────────────────────────────────────┐
│              Shared Objects (Global State)              │
│  ┌──────────────────┐  ┌──────────────────────────┐     │
│  │   LightCMTAT     │  │    ComplianceState      │     │
│  │ - TokenInfo      │  │ - PauseState             │     │
│  │ - TreasuryCap    │  │ - FreezeState            │     │
│  └──────────────────┘  │ - AllowlistState (opt)   │     │
│                        └──────────────────────────┘     │
│  ┌─────────────────────────────────────────────────┐   │
│  │              RuleEngine (optional)              │   │
│  │ - Transfer validation logic                     │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Benefits:**
- Each component is testable in isolation
- Easy to compose features (Light → Allowlist → Debt → Standard)
- Clear separation of concerns
- Parallel-friendly
- Upgradable components without redeploying entire contract

---

## Key Differences from EVM

If you're coming from Solidity/EVM development, here are the fundamental paradigm shifts:

### Comparison Table

| Concept | EVM (Solidity) | IOTA Move (This Implementation) | Why It Matters |
|---------|----------------|--------------------------------|----------------|
| **Balances** | `mapping(address => uint256)` in contract storage | `Coin<CMTAT>` objects owned by users | Ownership is explicit; native coin operations; no storage overhead |
| **Supply Control** | Internal `uint256 totalSupply` variable | `TreasuryCap<CMTAT>` VM object | VM-enforced; cryptographically secure; cannot be manipulated |
| **Access Control** | Role mappings + modifiers (e.g., `mapping(address => bool)`) | Capability objects (AdminCap, MintCap, etc.) | Physical possession = permission; transferable; no mapping lookups |
| **State Storage** | Single contract storage | Multiple shared objects | Enables parallel execution; modular; upgradable |
| **Querying Balances** | `balanceOf(address)` on-chain function | Wallet/indexer query (off-chain) | Reduces gas; scales better; native to the system |
| **Token Transfers** | Contract function call (`transfer(to, amount)`) | Native object transfer (`transfer::public_transfer`) | Cheaper; built-in validation; optimized by VM |
| **Compliance Rules** | Inline `require()` checks in functions | Separate validation engine (RuleEngine) | Reusable; composable; testable; auditable |
| **Mint/Burn** | Contract updates balance & supply | `coin::mint()` / `coin::burn()` via TreasuryCap | VM-enforced; atomic; type-safe |

### Detailed Pattern Comparisons

#### 1. Balance Storage

**❌ EVM Pattern (Not Used Here):**
```solidity
// Storing balances in contract mapping
mapping(address => uint256) public balances;

function balanceOf(address account) public view returns (uint256) {
    return balances[account];
}

function transfer(address to, uint256 amount) public {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;
    balances[to] += amount;
}
```

**✅ IOTA Native Pattern (Used Here):**
```move
// Balances are Coin<CMTAT> objects in user wallets
// No balanceOf function - query wallet or use indexer

// Transfer coins natively:
public entry fun transfer(
    compliance_state: &ComplianceState,
    coins: Coin<CMTAT>,
    to: address,
    ctx: &TxContext
) {
    // Validate first
    let restriction = rule_engine::validate_transfer(
        &compliance_state.pause_state,
        &compliance_state.freeze_state,
        tx_context::sender(ctx),
        to,
        coin::value(&coins),
        coin::value(&coins)
    );
    rule_engine::require_valid_transfer(restriction);

    // Native transfer
    transfer::public_transfer(coins, to);
}
```

**Why IOTA Native?**
- Balances are owned by users, not the contract
- Coin operations (split, join) are native to the VM
- No on-chain storage overhead for balances
- Reduces gas significantly
- Explicit ownership model

#### 2. Access Control

**❌ EVM Pattern (Not Used Here):**
```solidity
// Role-based access control with mappings
mapping(address => bool) public isMinter;
mapping(address => bool) public isAdmin;

modifier onlyMinter() {
    require(isMinter[msg.sender], "Not authorized");
    _;
}

modifier onlyAdmin() {
    require(isAdmin[msg.sender], "Not authorized");
    _;
}

function mint(address to, uint256 amount) public onlyMinter {
    balances[to] += amount;
    totalSupply += amount;
}
```

**✅ IOTA Native Pattern (Used Here):**
```move
// Capability objects instead of role mappings
public struct MintCap has key, store { id: UID }
public struct AdminCap has key, store { id: UID }

public entry fun mint(
    mint_cap: &MintCap,  // Must possess this object
    token: &mut LightCMTAT,
    compliance_state: &ComplianceState,
    to: address,
    amount: u64,
    ctx: &mut TxContext
) {
    // Only MintCap holder can call this - no role mapping lookup
    pause::require_not_paused(&compliance_state.pause_state);
    let coins = base::mint(&mut token.treasury_cap, amount, ctx);
    transfer::public_transfer(coins, to);
}

// Transfer capability to new admin:
public entry fun transfer_mint_capability(
    mint_cap: MintCap,
    to: address,
    ctx: &mut TxContext
) {
    transfer::public_transfer(mint_cap, to);
}
```

**Why IOTA Native?**
- No mapping lookups (faster execution)
- Capabilities can be transferred like tokens
- Physical possession = authorization (harder to bypass)
- Type-safe by the Move compiler
- Clear ownership model

#### 3. State Organization

**❌ EVM Pattern (Not Used Here):**
```solidity
// Everything in one contract
contract CMTAT {
    mapping(address => uint256) balances;
    uint256 totalSupply;
    bool paused;
    mapping(address => bool) frozenAddresses;
    mapping(address => uint256) frozenTokens;
    // ... all state here
}
```

**✅ IOTA Native Pattern (Used Here):**
```move
// Separate shared objects for modularity

// Token state
public struct LightCMTAT has key {
    id: UID,
    token_info: TokenInfo,
    treasury_cap: TreasuryCap<CMTAT>,
}

// Compliance state
public struct ComplianceState has key {
    id: UID,
    pause_state: PauseState,
    freeze_state: FreezeState,
    allowlist_state: AllowlistState,
}

// Rule engine
public struct RuleEngine has key {
    id: UID,
    custom_rules: Table<u8, vector<u8>>,
}

// Shared separately:
transfer::share_object(token);        // Anyone can read
transfer::share_object(compliance);   // Anyone can read
transfer::share_object(rule_engine);  // Anyone can read
```

**Why IOTA Native?**
- Enables parallel execution (read operations can run concurrently)
- Modular - can upgrade components independently
- Clear separation of concerns
- Better for composability
- Reduces gas for read operations

#### 4. Supply Management

**❌ EVM Pattern (Not Used Here):**
```solidity
// Manual supply tracking (vulnerable to manipulation)
uint256 public totalSupply;

function mint(address to, uint256 amount) public onlyMinter {
    totalSupply += amount;  // Manual update - error-prone
    balances[to] += amount;
}
```

**✅ IOTA Native Pattern (Used Here):**
```move
// VM-enforced supply via TreasuryCap
public struct LightCMTAT has key {
    id: UID,
    treasury_cap: TreasuryCap<CMTAT>,  // VM tracks supply
}

// Get total supply:
public fun total_supply(token: &LightCMTAT): u64 {
    base::total_supply(&token.treasury_cap)
}

// Minting:
public fun mint(
    treasury_cap: &mut TreasuryCap<CMTAT>,
    amount: u64,
    ctx: &mut TxContext
): Coin<CMTAT> {
    coin::mint(treasury_cap, amount, ctx)  // VM enforces
}
```

**Why IOTA Native?**
- Total supply is enforced by the VM, not contract code
- Cannot be manipulated even by admin
- Atomic operations guaranteed
- Cryptographically secure

---

## Features

- ✅ **CMTAT Framework Implementation** with IOTA-native architecture
- ✅ **Four Module Variants** - Light, Allowlist, Debt, and Standard implementations
- ✅ **Built on Coin<T>** - Leverages IOTA's native token standard
- ✅ **Capability-Based Access Control** - AdminCap, MintCap, BurnCap, etc.
- ✅ **Modular Components** - Pause, Freeze, Allowlist, Validation as separate objects
- ✅ **Batch Operations** for efficient multi-address operations
- ✅ **Transfer Validation** (ERC-1404 compatible) via RuleEngine
- ✅ **VM-Enforced Security** - TreasuryCap, Coin<T> ownership model

---

## Quick Start

### Prerequisites

- Move CLI installed (`iota move build`)
- IOTA wallet configured
- Basic understanding of IOTA Move object model

### Build & Test

```bash
# Build all contracts
iota move build

# Run tests
iota move test

# Run specific test
iota move test --filter test_name
```

### Deploy

```bash
# Deploy using script
./scripts/deploy.sh

# Verify deployed objects
iota client object <LightCMTAT-object-id>
iota client object <ComplianceState-object-id>
```

---

## Module Overview

### 🔹 Light CMTAT

**Minimal feature set for basic CMTAT compliance with IOTA native patterns**

**IOTA Native Features:**
- `Coin<CMTAT>` for user balances
- `TreasuryCap<CMTAT>` for VM-enforced supply control
- Capability objects: `AdminCap`, `MintCap`, `PauseCap`, `FreezeCap`
- Shared objects: `LightCMTAT`, `ComplianceState`

**Features:**
- Basic ERC20 functionality via `Coin<CMTAT>`
- Minting/burning (via TreasuryCap)
- Pause/Unpause/Deactivate (via PauseState object)
- Address freezing (via FreezeState object)
- Information management (terms, information, token_id)
- Batch balance queries
- 4 Capability types (AdminCap, MintCap, PauseCap, FreezeCap)

**Use Cases:** Standard token deployments, simple compliance requirements

---

### 🔹 Allowlist CMTAT

**All Light features plus allowlist functionality**

**IOTA Native Features:**
- All Light CMTAT features
- Extended Capability set: AllowlistCap, PartialFreezeCap, SnapshotCap, DocumentCap, ExtraInfoCap
- Enhanced ComplianceState with AllowlistState

**Additional Features:**
- Allowlist control (enable_allowlist, set_address_allowlist)
- Partial token freezing (freeze_partial_tokens, unfreeze_partial_tokens)
- Active balance queries (get_active_balance_of)
- Engine management (snapshot_engine, document_engine)
- 9 Capability types

**Use Cases:** Regulated tokens with whitelist requirements, KYC/AML compliance

---

### 🔹 Debt CMTAT

**Specialized for debt securities with IOTA native architecture**

**IOTA Native Features:**
- All Allowlist CMTAT features
- DebtState object for debt-specific tracking
- DebtCap for debt management permissions

**Debt-Specific Features:**
- Debt information management (debt, set_debt)
- Credit events tracking (credit_events, set_credit_events)
- Debt engine integration (debt_engine, set_debt_engine)
- Default flagging (flag_default)
- 10 Capability types (includes DebtCap)

**Use Cases:** Corporate bonds, structured debt products, fixed income securities

---

### 🔹 Standard CMTAT

**Full feature set with transfer validation**

**IOTA Native Features:**
- All native features from other variants
- RuleEngine object for transfer validation logic
- ValidationCap for validation management

**Advanced Features:**
- Transfer validation (restriction_code, message_for_transfer_restriction)
- ERC-1404 compliance via RuleEngine
- All core CMTAT features
- 9 Capability types

**Use Cases:** Advanced compliance, institutional securities with transfer validation

---

## Feature Comparison Matrix

| Feature | Light | Allowlist | Debt | Standard |
|---------|-------|-----------|------|----------|
| **Native Coin<CMTAT>** | ✅ | ✅ | ✅ | ✅ |
| **TreasuryCap Control** | ✅ | ✅ | ✅ | ✅ |
| **Capability Objects** | ✅ | ✅ | ✅ | ✅ |
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
| **Capability Count** | 4 | 9 | 10 | 9 |

---

## Architecture

```
move-cmtat/
├── Move.toml
├── README.md
├── sources/
│   ├── contracts/
│   │   ├── light_cmtat.move       # Minimal CMTAT (4 capabilities)
│   │   ├── allowlist_cmtat.move   # With allowlist (9 capabilities)
│   │   ├── debt_cmtat.move        # For debt securities (10 capabilities)
│   │   └── standard_cmtat.move    # Full feature set (9 capabilities)
│   ├── engines/
│   │   ├── rule_engine.move       # Transfer restrictions (ERC-1404)
│   │   └── snapshot_engine.move   # Balance snapshots
│   ├── components/
│   │   ├── base.move              # Base Coin<CMTAT> + TreasuryCap
│   │   ├── pause.move             # PauseState object
│   │   ├── freeze.move            # FreezeState object
│   │   ├── allowlist.move         # AllowlistState object
│   │   ├── debt.move              # DebtState object
│   │   └── validation.move        # Validation logic
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

## Access Control Model

### Capability-Based Security

This implementation uses IOTA Move's capability-based access control instead of EVM-style role mappings.

**Key Capabilities:**

| Capability | Purpose | Transferable |
|-----------|---------|--------------|
| `AdminCap` | Master administrator, can transfer other capabilities | ✅ Yes |
| `MintCap` | Can mint new tokens | ✅ Yes |
| `PauseCap` | Can pause/unpause contract | ✅ Yes |
| `FreezeCap` | Can freeze/unfreeze addresses | ✅ Yes |
| `AllowlistCap` | Can manage allowlist | ✅ Yes |
| `SnapshotCap` | Can create snapshots | ✅ Yes |
| `DocumentCap` | Can manage documents | ✅ Yes |
| `ExtraInfoCap` | Can update token metadata | ✅ Yes |
| `DebtCap` | Can manage debt parameters | ✅ Yes |

**How Capability Security Works:**

```move
// To call a protected function, you must possess the capability object:
public entry fun mint(
    mint_cap: &MintCap,  // ← Must own this object
    token: &mut LightCMTAT,
    compliance_state: &ComplianceState,
    to: address,
    amount: u64,
    ctx: &mut TxContext
) {
    // Function body...
}

// Transfer capability to another address:
public entry fun transfer_capability(
    capability: AdminCap,
    to: address,
    ctx: &mut TxContext
) {
    transfer::public_transfer(capability, to);
}
```

**Benefits:**
- No role mapping lookups required
- Capabilities can be transferred like tokens
- Physical possession = authorization
- Type-safe by compiler
- Clear ownership model

---

## Transfer Restrictions

All modules implement transfer restrictions via the RuleEngine component:

- Pause state check (`PauseState`)
- Sender/recipient freeze check (`FreezeState`)
- Active balance validation (for partial freezing)
- Allowlist validation (via `AllowlistState`)
- Custom validation (via transfer validation in Standard)

**Restriction Codes (ERC-1404 Compatible):**
- `0`: No restriction
- `1`: Address frozen
- `2`: Insufficient active balance
- `3`: Not allowlisted
- `4`: Paused
- `5`: Custom restriction

---

## Compliance Features

### Pause Mechanism
- Circuit breaker for emergency stops
- Permanent deactivation option
- PauseState object shared across components

### Freezing
- Full address freezing (cannot receive or send)
- Partial token freezing (freeze specific amounts)
- Frozen amounts tracked in FreezeState
- Active balance calculation support

### Allowlist
- Enable/disable allowlist requirement
- Per-address allowlist status
- Integration with partial freezing
- KYC/AML compliance support

### Transfer Validation
- Centralized RuleEngine for validation logic
- ERC-1404 compatible restriction codes
- Detailed error messages for each restriction
- Custom validation rules support

### Debt Management
- Debt information tracking
- Credit events management
- Debt engine integration
- Default flagging

---

## License

Mozilla Public License 2.0 (MPL-2.0)

---

## Links

- **CMTAT**: https://www.cmtat.org
- **Cairo CMTAT**: https://github.com/0xsereel/cairo-cmtat
- **CMTAT Solidity**: https://github.com/CMTA/CMTAT
- **IOTA**: https://www.iota.org
- **IOTA Move Documentation**: https://docs.iota.org

---

**Built with IOTA Move native architecture for compliant securities**

*Version 0.1.0 - Native IOTA Implementation*
