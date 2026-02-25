# Move CMTAT - IOTA Native Security Token Standard

> A native IOTA Move implementation of Switzerland's Capital Markets Technology Association token standard

**⚠️ WORK IN PROGRESS - ~80% CMTAT Compliant**

This project implements the CMTAT security token standard natively in IOTA Move, leveraging IOTA's object model and native token architecture for superior security and compliance capabilities.

---

## Overview

[CMTAT](https://cmta.ch/standards/cmta-token-cmtat) is a framework for the tokenization of securities and financial instruments in compliance with local regulations. This implementation takes a fundamentally different approach from EVM-based implementations by building CMTAT compliance features **on top of** IOTA's native `Coin<T>` architecture rather than reimplementing token functionality from scratch.

### Key Architectural Principle

Instead of managing balances in contract storage (EVM pattern), this implementation uses IOTA's native `Coin<TOKEN>` objects where users physically possess their token balances. CMTAT compliance features (freeze, pause, validation) are implemented as modular extensions that enforce restrictions on these native transfers.

**Benefits:**
- VM-enforced supply integrity via `TreasuryCap<T>`
- Parallel execution enabled by separate shared objects
- Capability-based access control (physical possession = authorization)
- Native DenyList integration for regulatory compliance
- Type-safe compliance rules enforced by the compiler

---

## Current Implementation Status

### ✅ Production-Ready Components

**Core Token Infrastructure:**
- Native IOTA `Coin<T>` integration for user balances
- `TreasuryCap<T>` for cryptographically secure supply management
- Capability-based access control (AdminCap, MintCap, BurnCap, PauseCap, EnforcerCap)
- Native DenyList integration for pause/freeze enforcement
- Batch operations for administrative efficiency

**Compliance Engines (Implemented & Tested):**

| Engine | Status | Description |
|--------|--------|-------------|
| **RuleEngine v2** | ✅ Ready | Hierarchical rule validation with VIP support, conditional transfers, approval workflows |
| **Snapshot Engine** | ✅ Integrated | Balance snapshots with timestamp tracking |
| **Interest Engine** | ✅ Ready | Coupon schedules, interest calculations, payment tracking |
| **Debt Engine** | ✅ Ready | Multi-token debt instrument management |
| **Bond Validation** | ✅ Ready | Day count conventions, accrued interest, coupon calculations |

**State Components:**
- **Allowlist** - Whitelist management with enable/disable
- **Document Registry** - CMTAT compliant document management (comprehensive implementation)
- **Debt** - Basic debt structure with credit events tracking

### ⚠️ Integration Work Required

The following components are fully implemented and tested and are now integrated into the token contracts:

- **RuleEngine v2** - ✅ Fully integrated into standard_cmtat, allowlist_cmtat, and debt_cmtat
- **Document Registry** - Component exists but not yet integrated into contract state
- **Debt Module** - Basic structure complete, needs enhancement with full instrument fields

### 🔴 Critical Features In Development

**Regulatory Compliance Requirements:**

1. **Forced Transfer System** - Court order enforcement, regulatory seizures, legally required for securities
2. **Partial Token Freezing** - Granular balance freezing for collateral, lending, margin requirements
3. **Document Registry Integration** - Connect document component to contract state for legal document linking
4. **RuleEngine Integration** - Wire rule validation into transfer functions for complex compliance

These features are required for full CMTAT compliance and production securities deployment.

---

## Architecture

### Native IOTA Patterns

**1. Object-Based Balance Model**

```move
// Users own Coin<TOKEN> objects (not contract mappings)
Coin<STANDARD_CMTAT> { value: 1000 }

// Transfers are native VM operations
transfer::public_transfer(coins, recipient);
```

Unlike EVM where balances are stored in contract storage (`mapping(address => uint256)`), IOTA Move uses native coin objects that users physically possess. This eliminates reentrancy attacks, provides explicit ownership, and enables native coin operations (split, join).

**2. Capability-Based Security**

```move
// Authorization via capability objects (not role mappings)
public struct MintCap has key, store { id: UID }

public entry fun mint(
    _mint_cap: &MintCap,  // Must possess this object
    treasury_cap: &mut TreasuryCap<TOKEN>,
    amount: u64,
    ctx: &mut TxContext
): Coin<TOKEN> {
    coin::mint(treasury_cap, amount, ctx)
}
```

Capabilities provide superior security to EVM's role mappings:
- No mapping lookups required
- Physical possession = authorization
- Transferable between addresses
- Type-safe by the compiler
- Harder to compromise than private keys alone

**3. Native DenyList Compliance**

```move
// Pause/freeze via IOTA's native DenyList system
public entry fun set_address_frozen(
    _enforcer_cap: &EnforcerCap,
    deny_list: &mut DenyList,
    deny_cap: &mut DenyCapV1<TOKEN>,
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
```

IOTA's native DenyList provides VM-level enforcement of compliance rules, eliminating the need for custom pause/freeze implementations and ensuring atomic, race-condition-free enforcement.

### Component Architecture

```
move-cmtat/
├── sources/
│   ├── contracts/              # Token contract variants
│   │   ├── light_cmtat.move    # Minimal implementation
│   │   ├── allowlist_cmtat.move # With allowlist support
│   │   ├── debt_cmtat.move     # For debt securities
│   │   └── standard_cmtat.move # Full feature set
│   │
│   ├── engines/                # Business logic modules
│   │   ├── rule_engine_v2.move    # Rule validation system
│   │   ├── snapshot_engine.move   # Balance snapshots
│   │   ├── interest_engine.move   # Coupon & interest calc
│   │   └── debt_engine.move       # Debt management
│   │
│   ├── components/             # State components
│   │   ├── allowlist.move      # Whitelist functionality
│   │   ├── debt.move           # Debt instrument data
│   │   ├── document_registry.move # Document management
│   │   └── bond_validation.move   # Bond calculations
│   │
│   └── interfaces/
│       └── icmtat.move         # Interface constants
│
└── tests/                      # Comprehensive test suite
    ├── rule_engine_v2_tests.move
    ├── snapshot_engine_tests.move
    ├── interest_engine_tests.move
    ├── debt_engine_tests.move
    ├── bond_validation_tests.move
    ├── light_cmtat_tests.move       # Contract unit tests
    ├── allowlist_cmtat_tests.move   # Contract unit tests
    ├── standard_cmtat_tests.move    # Contract unit tests
    ├── debt_cmtat_tests.move        # Contract unit tests
    ├── capability_tests.move        # Role/capability tests
    └── integration_tests.move       # Cross-contract flow tests
```

**Design Philosophy:**
- **Separation of concerns** - Business logic (engines) separate from state (components) separate from contract orchestration
- **Composability** - Components can be mixed and matched across contract variants
- **Testability** - Each engine and component tested in isolation
- **Upgradeability** - Components can evolve independently

---

## Contract Variants

Four contract implementations offering different feature sets:

### Light CMTAT
**Purpose:** Minimal compliance for standard tokens  
**Capabilities:** AdminCap, MintCap, BurnCap, PauseCap, EnforcerCap  
**Features:** Core token functionality, native DenyList compliance, batch operations  
**Use Case:** Simple securities, basic compliance requirements

### Allowlist CMTAT  
**Purpose:** Regulated tokens with whitelist requirements  
**Capabilities:** + AllowlistCap, SnapshotCap  
**Features:** All Light features + allowlist validation + snapshots  
**Use Case:** KYC/AML compliance, accredited investor requirements

### Debt CMTAT
**Purpose:** Corporate bonds and debt instruments  
**Capabilities:** + DebtCap, SnapshotCap  
**Features:** All Light features + debt tracking + credit events + snapshots  
**Use Case:** Corporate bonds, structured debt, fixed income securities

### Standard CMTAT
**Purpose:** General-purpose compliant token  
**Capabilities:** + SnapshotCap  
**Features:** Core compliance features + snapshots  
**Use Case:** Standard securities, institutional tokens

---

## IOTA Move vs EVM Architecture

| Aspect | EVM (Solidity) | IOTA Move (This Implementation) | Impact |
|--------|----------------|--------------------------------|---------|
| **Balance Storage** | `mapping(address => uint256)` in contract | `Coin<TOKEN>` objects owned by users | Explicit ownership, no storage overhead, native operations |
| **Supply Control** | Manual `totalSupply` variable | `TreasuryCap<TOKEN>` VM-enforced | Cannot be manipulated, cryptographically secure |
| **Access Control** | Role mappings (`mapping(address => bool)`) | Capability objects | No lookup overhead, transferable, type-safe |
| **Transfers** | Contract function modifying storage | Native object transfer | Cheaper, VM-optimized, built-in validation |
| **Compliance** | Custom pause/freeze state | Native DenyList | VM-level enforcement, atomic, race-condition-free |
| **Query Pattern** | On-chain `balanceOf()` | Off-chain wallet/indexer | Reduces gas, better scalability |
| **Security Model** | Runtime checks | Compile-time type safety | Prevents entire classes of bugs |

---

## Compliance Features

### Implemented

**Native DenyList Integration:**
- Global pause/unpause (circuit breaker)
- Per-address freeze/unfreeze
- Batch freeze operations
- Epoch-scoped enforcement (atomic state transitions)

**Allowlist Support (allowlist_cmtat):**
- Enable/disable allowlist requirement
- Per-address allowlist status
- Transfer validation against allowlist

**Debt Tracking (debt_cmtat):**
- Debt information management
- Credit events (default, redeemed, rating)
- Default flagging
- Snapshot support

**Snapshot Engine:**
- Balance snapshots at specific timestamps
- Total supply tracking
- Available across all contract variants

### In Development

**Forced Transfer:**
- Court order enforcement capability
- Regulatory seizure support
- Legally required for securities enforcement

**Partial Token Freezing:**
- Granular balance freezing (specific amounts)
- Collateral locking for lending
- Margin requirement enforcement

**Document Registry Integration:**
- CMTAT compliant document management
- Legal document linking (prospectus, indenture)

---

## RuleEngine v2

A comprehensive rule validation system implementing hierarchical compliance checks.

### Features

- **VIP Whitelist** - Bypass certain restrictions for approved addresses
- **Conditional Transfers** - Require operator approval for large transfers
- **Request Lifecycle** - Waiting → Approved → Executed workflow
- **Time-Based Controls** - Approval deadlines, execution windows
- **Configurable Rules** - Enable/disable specific validation rules
- **Blacklist** - Block specific addresses from transacting
- **Sanction List** - Block sanctioned addresses from transacting
- **Max Balance** - Limit maximum transfer amount per transaction

### Restriction Codes

Implements CMTAT compliant transfer restriction codes:

- `0` - Valid (transfer allowed)
- `1` - Paused (contract is paused)
- `2` - Frozen sender
- `3` - Frozen receiver
- `4` - Not allowlisted
- `5` - Insufficient balance
- `6` - Blacklisted address
- `7` - Sanctioned address
- `8` - Exceeds max balance
- `10` - Conditional transfer required
- `11` - Transfer pending approval
- `12` - Transfer request denied
- `13` - Transfer request expired
- `14` - Transfer already executed

### Integration

RuleEngine v2 is fully integrated into `standard_cmtat`, `allowlist_cmtat`, and `debt_cmtat` contracts. All transfers go through rule validation before execution.

---

## Building & Testing

### Prerequisites

```bash
# IOTA CLI
iota --version

# Move compiler
iota move --version
```

### Build

```bash
# Clean build directory if needed
rm -rf build/

# Build all modules
iota move build
```

### Test

```bash
# Run all tests
iota move test

# Run specific module
iota move test --filter rule_engine_v2
iota move test --filter snapshot_engine
```

**Test Status:** 214 tests including 6 integration tests

### Integration Tests

Cross-contract flow tests verifying end-to-end scenarios:

| Test | Flow Description |
|------|------------------|
| `test_token_lifecycle` | init → mint → transfer |
| `test_allowlist_full_flow` | enable allowlist → add addresses → transfer → disable |
| `test_freeze_pause_flow` | freeze address → unfreeze |
| `test_deactivation_flow` | init → mint → deactivate |
| `test_role_escalation_flow` | grant minter → grant pauser → test capabilities |
| `test_rule_engine_integration` | init → whitelist rule → VIP bypass → blacklist → max balance |

Run with: `iota move test --filter integration`

### Known Limitations

**IOTA DenyList Epoch Behavior:**
Freeze and pause changes are epoch-scoped, meaning they take effect in the current epoch for new transactions. This is an IOTA protocol-level behavior that differs from immediate visibility in EVM implementations. Five tests account for this behavior and are expected to pass when run across epoch boundaries.

---

## CMTAT Compliance

### Current Compliance: ~80%

**Fully Compliant Areas:**
- Core token functionality (via native Coin<T>)
- Mint/Burn operations
- Pause/Freeze (via native DenyList)
- Access control (capability-based)
- Snapshot functionality
- Interest calculations
- Bond validation
- RuleEngine v2 (blacklist, sanction list, max balance, conditional transfers)

**Partial Compliance:**
- Document management (component ready but not integrated)
- Debt module (basic structure, needs full instrument fields)

**Critical Gaps:**
- Forced transfer (regulatory requirement)
- Partial token freezing (collateral/lending)

### Comparison to Solidity Reference

**Advantages:**
- Native token architecture (no balance mappings)
- VM-enforced supply integrity
- Capability-based security model
- Parallel execution support
- Type-safe by compiler

**Missing for Full Compliance:**
- Forced transfer system
- Partial balance freezing
- Document registry integration
- RuleEngine contract integration

---

## Roadmap

### Phase 1: Critical Compliance

Implement regulatory requirements for production securities deployment:

1. **Forced Transfer System** - Court orders, regulatory seizures
2. **Partial Token Freezing** - Collateral, lending, margin requirements
3. **Document Registry Integration** - Legal document linking
4. **RuleEngine Integration** - Complex compliance rules
5. **Complete Debt Module** - Full instrument specification
6. **Contract Consistency** - Standardize features across variants

### Phase 2: Production Hardening

- Comprehensive integration testing
- Security audit
- Performance optimization
- Documentation
- Mainnet deployment preparation

### Phase 3: Advanced Features

- Additional capability types
- Enhanced metadata support
- Business day calculations
- Transfer hooks and callbacks

---

## License

Mozilla Public License 2.0 (MPL-2.0)

---

## Resources

- **CMTAT Standard:** https://www.cmtat.org
- **CMTAT Solidity Reference:** https://github.com/CMTA/CMTAT
- **IOTA Documentation:** https://docs.iota.org


---

*Built with IOTA Move native architecture for compliant securities*

*Version 0.2.1 - Work in Progress (~80% CMTAT Compliant)*
