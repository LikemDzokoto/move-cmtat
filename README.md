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
// Token registry with metadata
public struct CMTATRegistry has key {
    id: UID,
    terms: String,
    information: String,
    token_id: String,
    document_uri: String,
    deactivated: bool,
}

// TreasuryCap<T> for supply control (owned by admin)
// DenyCapV1<T> for DenyList management (owned by admin)
// Native DenyList shared object for freeze/pause compliance
```

**Note:** Compliance (pause/freeze) is now enforced via IOTA's native `DenyList` system object, not custom state. Contract-specific state (like `AllowlistState` or `DebtState`) is stored in separate `ComplianceState` objects only where needed.

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
public struct EnforcerCap has key, store { id: UID }  // For freeze operations

// Capability-protected function with native DenyList compliance
public entry fun mint_and_transfer(
    _mint_cap: &MintCap,  // ← Must possess this object
    treasury_cap: &mut TreasuryCap<STANDARD_CMTAT>,
    registry: &CMTATRegistry,
    deny_list: &DenyList,
    to: address,
    amount: u64,
    ctx: &mut TxContext
) {
    // Only MintCap holder can call this - no role mapping lookup needed
    assert!(!registry.deactivated, EModuleDeactivated);
    assert!(!is_paused(deny_list, ctx), EModulePaused);
    assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);
    let coins = coin::mint(treasury_cap, amount, ctx);
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
│  │  CMTATRegistry   │  │    Native DenyList       │     │
│  │ - terms          │  │  (System-level object)   │     │
│  │ - document_uri   │  │ - Global pause state     │     │
│  │ - deactivated    │  │ - Per-address freeze     │     │
│  └──────────────────┘  └──────────────────────────┘     │
│  ┌─────────────────────────────────────────────────┐   │
│  │   ComplianceState (contract-specific, optional) │   │
│  │ - AllowlistState (allowlist_cmtat only)         │   │
│  │ - DebtState (debt_cmtat only)                   │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Benefits:**
- Each component is testable in isolation
- Easy to compose features (Light → Allowlist → Debt → Standard)
- Clear separation of concerns
- Parallel-friendly
- Upgradable components without redeploying entire contract

### Native DenyList Compliance

This implementation uses IOTA's **native DenyList** system for pause and freeze compliance, rather than custom state objects. This provides VM-level enforcement of compliance rules.

#### How It Works

```move
// Pause: Uses global pause on the native DenyList
public entry fun pause(
    _pause_cap: &PauseCap,
    deny_list: &mut DenyList,
    deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
    registry: &CMTATRegistry,
    ctx: &mut TxContext
) {
    assert!(!registry.deactivated, EModuleDeactivated);
    coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);
}

// Freeze: Uses per-address deny on the native DenyList
public entry fun set_address_frozen(
    _enforcer_cap: &EnforcerCap,
    deny_list: &mut DenyList,
    deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
    account: address,
    frozen: bool,
    ctx: &mut TxContext
) {
    if (frozen) {
        coin::deny_list_v1_add(deny_list, deny_cap, account, ctx);
    } else {
        coin::deny_list_v1_remove(deny_list, deny_cap, account, ctx);
    }
}

// Check compliance status
public fun is_paused(deny_list: &DenyList, ctx: &TxContext): bool {
    coin::deny_list_v1_is_global_pause_enabled_current_epoch<STANDARD_CMTAT>(deny_list, ctx)
}

public fun is_frozen(deny_list: &DenyList, account: address, ctx: &TxContext): bool {
    coin::deny_list_v1_contains_current_epoch<STANDARD_CMTAT>(deny_list, account, ctx)
}
```

#### Key Capabilities

| Capability | Purpose |
|-----------|---------|
| `DenyCapV1<T>` | System capability for DenyList operations (pause/freeze) |
| `PauseCap` | Business capability to authorize pause operations |
| `EnforcerCap` | Business capability to authorize freeze operations |

#### Epoch-Scoped Behavior

DenyList changes are **epoch-scoped** - they take effect in the current epoch for new transactions. This provides:
- Atomic compliance enforcement
- Predictable state transitions
- No race conditions between compliance checks and transfers

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

// Transfer coins with native DenyList compliance:
public entry fun transfer(
    registry: &CMTATRegistry,
    deny_list: &DenyList,
    coins: Coin<STANDARD_CMTAT>,
    to: address,
    ctx: &TxContext
) {
    let from = tx_context::sender(ctx);

    // Validate via native DenyList
    assert!(!registry.deactivated, EModuleDeactivated);
    assert!(!is_paused(deny_list, ctx), EModulePaused);
    assert!(!is_frozen(deny_list, from, ctx), EAddressFrozen);
    assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);

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

public entry fun mint_and_transfer(
    _mint_cap: &MintCap,  // Must possess this object
    treasury_cap: &mut TreasuryCap<STANDARD_CMTAT>,
    registry: &CMTATRegistry,
    deny_list: &DenyList,
    to: address,
    amount: u64,
    ctx: &mut TxContext
) {
    // Only MintCap holder can call this - no role mapping lookup
    assert!(!registry.deactivated, EModuleDeactivated);
    assert!(!is_paused(deny_list, ctx), EModulePaused);
    assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);
    let coins = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coins, to);
}

// Transfer capability to new admin:
public entry fun transfer_mint_capability(
    mint_cap: MintCap,
    to: address,
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

// Token registry (shared)
public struct CMTATRegistry has key {
    id: UID,
    terms: String,
    information: String,
    token_id: String,
    document_uri: String,
    deactivated: bool,
}

// Native DenyList (system shared object)
// - Handles pause/freeze compliance at VM level
// - Accessed via coin::deny_list_v1_* functions

// Contract-specific state (optional, shared)
public struct ComplianceState has key {
    id: UID,
    allowlist_state: AllowlistState,  // allowlist_cmtat only
    // OR debt_state: DebtState,      // debt_cmtat only
}

// Shared separately:
transfer::share_object(registry);           // Anyone can read
transfer::share_object(compliance_state);   // Anyone can read (if needed)
// DenyList is a system object - always available
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
- `Coin<LIGHT_CMTAT>` for user balances
- `TreasuryCap<LIGHT_CMTAT>` for VM-enforced supply control
- `DenyCapV1<LIGHT_CMTAT>` for native DenyList compliance
- Capability objects: `AdminCap`, `MinterCap`, `PauserCap`, `EnforcerCap`
- Shared objects: `CMTATRegistry`, `LightCMTATState`

**Features:**
- Basic ERC20 functionality via `Coin<T>`
- Minting/burning (via TreasuryCap)
- Pause/Unpause/Deactivate (via native DenyList)
- Address freezing (via native DenyList)
- Information management (terms, information, token_id, document_uri)
- 4 Capability types

**Use Cases:** Standard token deployments, simple compliance requirements

---

### 🔹 Allowlist CMTAT

**All Light features plus allowlist functionality**

**IOTA Native Features:**
- All Light CMTAT native features
- `DenyCapV1<ALLOWLIST_CMTAT>` for native DenyList compliance
- `ComplianceState` with `AllowlistState` for allowlist management
- Extended Capability set: `AllowlistCap`

**Additional Features:**
- Allowlist control (enable_allowlist, set_address_allowlist)
- Transfer validation against allowlist
- Snapshot engine for balance tracking
- 7 Capability types (AdminCap, MintCap, BurnCap, PauseCap, EnforcerCap, SnapshotCap, AllowlistCap)

**Use Cases:** Regulated tokens with whitelist requirements, KYC/AML compliance

---

### 🔹 Debt CMTAT

**Specialized for debt securities with IOTA native architecture**

**IOTA Native Features:**
- All Light CMTAT native features
- `DenyCapV1<DEBT_CMTAT>` for native DenyList compliance
- `ComplianceState` with `DebtState` for debt-specific tracking
- `DebtCap` for debt management permissions

**Debt-Specific Features:**
- Debt information management (debt, set_debt)
- Credit events tracking (credit_events, set_credit_events)
- Debt engine integration (debt_engine, set_debt_engine)
- Default flagging (flag_default)
- Snapshot engine for balance tracking
- 7 Capability types (AdminCap, MintCap, BurnCap, PauseCap, EnforcerCap, SnapshotCap, DebtCap)

**Use Cases:** Corporate bonds, structured debt products, fixed income securities

---

### 🔹 Standard CMTAT

**Full feature set with native DenyList compliance**

**IOTA Native Features:**
- `Coin<STANDARD_CMTAT>` for user balances
- `TreasuryCap<STANDARD_CMTAT>` for VM-enforced supply control
- `DenyCapV1<STANDARD_CMTAT>` for native DenyList compliance
- Capability objects: `AdminCap`, `MintCap`, `BurnCap`, `PauseCap`, `EnforcerCap`, `SnapshotCap`
- Shared objects: `CMTATRegistry`, `StandardCMTATState`

**Features:**
- All core CMTAT compliance features
- Native DenyList for pause/freeze enforcement
- Snapshot engine for balance tracking
- Batch freeze operations
- 6 Capability types

**Use Cases:** Standard compliant securities, institutional tokens

---

## Feature Comparison Matrix

| Feature | Light | Allowlist | Debt | Standard |
|---------|-------|-----------|------|----------|
| **Native Coin<T>** | ✅ | ✅ | ✅ | ✅ |
| **TreasuryCap Control** | ✅ | ✅ | ✅ | ✅ |
| **Native DenyList Compliance** | ✅ | ✅ | ✅ | ✅ |
| **Capability Objects** | ✅ | ✅ | ✅ | ✅ |
| **Minting** | ✅ | ✅ | ✅ | ✅ |
| **Burning** | ✅ | ✅ | ✅ | ✅ |
| **Forced Burn** | ✅ | ❌ | ❌ | ❌ |
| **Pause/Unpause (DenyList)** | ✅ | ✅ | ✅ | ✅ |
| **Deactivation** | ✅ | ✅ | ✅ | ✅ |
| **Address Freezing (DenyList)** | ✅ | ✅ | ✅ | ✅ |
| **Batch Operations** | ✅ | ✅ | ✅ | ✅ |
| **Information Management** | ✅ | ✅ | ✅ | ✅ |
| **Allowlist** | ❌ | ✅ | ❌ | ❌ |
| **Debt Management** | ❌ | ❌ | ✅ | ❌ |
| **Snapshot Engine** | ✅ | ✅ | ✅ | ✅ |
| **Capability Count** | 4 | 7 | 7 | 6 |

---

## Architecture

```
move-cmtat/
├── Move.toml
├── README.md
├── sources/
│   ├── contracts/
│   │   ├── light_cmtat.move       # Minimal CMTAT (4 capabilities)
│   │   ├── allowlist_cmtat.move   # With allowlist (7 capabilities)
│   │   ├── debt_cmtat.move        # For debt securities (7 capabilities)
│   │   └── standard_cmtat.move    # Standard feature set (6 capabilities)
│   ├── engines/
│   │   ├── rule_engine.move       # Allowlist validation
│   │   └── snapshot_engine.move   # Balance snapshots
│   ├── components/
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

**Note:** Pause and freeze functionality is now handled by IOTA's native `DenyList` system object, not custom component modules.

---

## Access Control Model

### Capability-Based Security

This implementation uses IOTA Move's capability-based access control instead of EVM-style role mappings.

**Key Capabilities:**

| Capability | Purpose | Transferable |
|-----------|---------|--------------|
| `AdminCap` | Master administrator, can transfer other capabilities | ✅ Yes |
| `MintCap` | Can mint new tokens | ✅ Yes |
| `BurnCap` | Can burn tokens | ✅ Yes |
| `PauseCap` | Can pause/unpause contract via DenyList | ✅ Yes |
| `EnforcerCap` | Can freeze/unfreeze addresses via DenyList | ✅ Yes |
| `SnapshotCap` | Can create snapshots | ✅ Yes |
| `AllowlistCap` | Can manage allowlist (allowlist_cmtat only) | ✅ Yes |
| `DebtCap` | Can manage debt parameters (debt_cmtat only) | ✅ Yes |
| `DenyCapV1<T>` | System capability for DenyList operations | ✅ Yes |

**How Capability Security Works:**

```move
// To call a protected function, you must possess the capability object:
public entry fun mint_and_transfer(
    _mint_cap: &MintCap,  // ← Must own this object
    treasury_cap: &mut TreasuryCap<STANDARD_CMTAT>,
    registry: &CMTATRegistry,
    deny_list: &DenyList,
    to: address,
    amount: u64,
    ctx: &mut TxContext
) {
    // Only MintCap holder can call this
    assert!(!is_paused(deny_list, ctx), EModulePaused);
    let coins = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coins, to);
}

// Transfer capability to another address:
public entry fun transfer_capability(
    capability: AdminCap,
    to: address,
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

All modules implement transfer restrictions via native DenyList and contract-specific validation:

- **Pause state check** (via native DenyList `coin::deny_list_v1_is_global_pause_enabled_current_epoch`)
- **Sender/recipient freeze check** (via native DenyList `coin::deny_list_v1_contains_current_epoch`)
- **Deactivation check** (via `CMTATRegistry.deactivated` flag)
- **Allowlist validation** (via `AllowlistState` in allowlist_cmtat only)

**Error Codes:**
- `EModuleDeactivated (0)`: Contract has been permanently deactivated
- `EAddressFrozen (1)`: Sender or recipient is frozen
- `EModulePaused (2)`: Contract is paused
- `ENotAllowlisted (3)`: Address not on allowlist (allowlist_cmtat only)

---

## Compliance Features

### Pause Mechanism (Native DenyList)
- Circuit breaker for emergency stops via `coin::deny_list_v1_enable_global_pause`
- Permanent deactivation option via `CMTATRegistry.deactivated`
- Epoch-scoped enforcement - changes take effect immediately for current epoch

### Freezing (Native DenyList)
- Full address freezing via `coin::deny_list_v1_add` (cannot receive or send)
- Batch freeze operations supported
- Epoch-scoped enforcement
- No partial token freezing - full address freeze only

### Allowlist (allowlist_cmtat only)
- Enable/disable allowlist requirement
- Per-address allowlist status
- Transfers require receiver to be allowlisted when enabled
- KYC/AML compliance support

### Debt Management (debt_cmtat only)
- Debt information tracking
- Credit events management
- Debt engine integration
- Default flagging

### Snapshot Engine
- Balance snapshot creation at specific timestamps
- Total supply tracking
- Available across all contract variants

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
