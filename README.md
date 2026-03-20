# Move CMTAT - IOTA Native Security Token Standard

> A native IOTA Move implementation of Switzerland's Capital Markets Technology Association token standard



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



**Core Token Infrastructure:**
- Native IOTA `Coin<T>` integration for user balances
- `TreasuryCap<T>` for cryptographically secure supply management
- Capability-based access control (AdminCap, MintCap, BurnCap, PauseCap, EnforcerCap)
- Native DenyList integration for pause/freeze enforcement
- Batch operations for administrative efficiency

**Compliance Engines :**
| Engine | Description |
|--------|-------------|
| **RuleEngine v2** | Hierarchical rule validation with VIP support, conditional transfers, approval workflows |
| **Snapshot Engine** | Balance snapshots with timestamp tracking |
| **Interest Engine** | Coupon schedules, interest calculations, payment tracking |
| **Debt Engine** | Multi-token debt instrument management |

**State Components:**
- **Allowlist** - Whitelist management with enable/disable
- **Debt** - Full debt instrument with identifier, instrument, bond terms, credit events



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

**Two-Tier Capability System:**
```move
// Core admin capabilities (full authority)
TreasuryCap<TOKEN>     // Mint/burn (supply control)
DenyCapV1<TOKEN>       // Pause/freeze (compliance control)

// Delegated operational capabilities
MintCap, BurnCap, PauseCap, EnforcerCap
```

The capability model separates administrative control from delegated operations, enabling fine-grained role assignment without compromising security.

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
│   └── components/             # State components
│       ├── allowlist.move      # Whitelist functionality 
│       └── debt.move           # Debt instrument data
│
├── scripts/                    # Deployment & orchestration scripts
│   ├── setup.sh               # Environment setup
│   ├── localnet.sh            # Local network launcher
│   ├── deploy.ts              # Deploy all 4 CMTAT variants
│   ├── verify.ts              # Verify deployed contracts
│   ├── interact.ts            # Token operations + 7 orchestrated flows
│   ├── CoinHelper.ts          # SDK-based coin operations
│   └── TokenHelper.ts         # SDK-based token operations
│
├── tests/                      # Comprehensive test suite
│   ├── rule_engine_v2_tests.move
│   ├── snapshot_engine_tests.move
│   ├── interest_engine_tests.move
│   ├── debt_engine_tests.move
│   ├── light_cmtat_tests.move       # Contract unit tests
│   ├── allowlist_cmtat_tests.move   # Contract unit tests
│   ├── standard_cmtat_tests.move    # Contract unit tests
│   ├── debt_cmtat_tests.move        # Contract unit tests
│   ├── capability_tests.move        # Role/capability tests
│   └── integration_tests.move       # Cross-contract flow tests
│
├── package.json              
└── CHANGELOG.md                # Version history and release notes
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
**Features:** All Light features + debt tracking + credit events + snapshots + interest engine + maturity validation + redemption  
**Use Case:** Corporate bonds, structured debt, fixed income securities

**Debt Features:**
- Debt Identifier (issuer name, ISIN, guarantor, holder representative)
- Debt Instrument (interest rate, par value, maturity date, coupon frequency, day count conventions)
- Credit Events (rating, default flag, redeemed flag, principal distributed)
- Maturity Validation (transfers blocked when bond matures)
- Redemption (allowed when matured or in default)
- Interest Engine Integration (coupon schedule generation, payment recording, claim tracking)

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
- Full debt instrument (identifier, instrument, bond terms)
- Credit events (default, redeemed, rating, maturity)
- Maturity validation (transfers blocked post-maturity)
- Redemption (allowed when matured or in default)
- Interest engine integration (coupon schedules, payment tracking, claim-based distribution)

**Snapshot Engine:**
- Balance snapshots at specific timestamps
- Total supply tracking
- Available across all contract variants

**Interest Engine:**
- Coupon schedule generation from debt instrument parameters
- Support for ANNUAL, SEMI_ANNUAL, QUARTERLY, MONTHLY frequencies
- Day count convention support (30/360, Actual/360, Actual/365, Actual/Actual)
- Payment recording with timestamps
- Claim-based interest distribution (holders claim interest based on balance at record date)
- Prevents double-claiming via claims tracking table
- Accrued interest calculations




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

**Test Status:** 200+ tests including 6 integration tests

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

## Deployment & Orchestration Scripts

This project includes comprehensive automation scripts for deployment and end-to-end token lifecycle management.

### Script Overview

| Script | Purpose |
|--------|---------|
| `scripts/setup.sh` | Environment setup - checks IOTA CLI, configures client |
| `scripts/localnet.sh` | Start local IOTA network with `--watch` mode for auto-restart |
| `scripts/deploy.ts` | Deploy all 4 CMTAT variants to any network |
| `scripts/verify.ts` | Verify deployed contracts on-chain + explorer |
| `scripts/interact.ts` | Token operations + 7 orchestrated flows |
| `scripts/CoinHelper.ts` | SDK-based coin operations (split, merge, burn) |
| `scripts/TokenHelper.ts` | SDK-based token operations (transfer, conditional transfers) |

**Key Features:**
- Uses CLI's active address (no keypair generation required)
- Automatic faucet funding check for testnet deployments
- Proper gas budgets (1B for publish, 500M for function calls)
- SDK helpers for complex operations requiring Coin object manipulation

### 7-Step Orchestrated Flows

The interaction framework implements complete token lifecycle management:

| Flow | Action | Type | Description |
|------|--------|-------|-------------|
| **FLOW 1** | `flow_setup` | Atomic | Token setup: terms, documents, RuleEngine, DebtEngine, roles |
| **FLOW 2** | `flow_onboard` | Continue | Investor onboarding: allowlist, KYC, jurisdiction rules |
| **FLOW 3** | `flow_issue` | Continue | Primary issuance: batch mint with validation + snapshot |
| **FLOW 4** | `flow_transfer` | Continue | Secondary transfer: direct or conditional mode |
| **FLOW 5** | `flow_coupon` | Continue | Coupon/interest payment: debt schedule + on-chain payment |
| **FLOW 6** | `flow_redeem` | Atomic | Token redemption: maturity check + atomic burn |
| **FLOW 7** | `flow_emergency` | Atomic | Emergency controls: pause, freeze, unfreeze |

### Flow Parameters

```bash
# Token Metadata
--terms <text>                    # Legal terms
--document-uri <uri>              # Document URI
--document-hash <hash>            # Document hash (URI#hash)
--documents <json>                # Document list

# RuleEngine Configuration
--rule-engine-rules <json>        # Rules: whitelist, blacklist, sanctions
--kyc-addresses <addrs>          # KYC-approved addresses
--jurisdiction-rules <json>       # Jurisdiction rules
--lockup-rules <json>             # Lockup rules
--max-balance <n>                 # Max balance per address
--auto-approve <bool>              # Auto-approve conditional transfers

# Debt Configuration
--debt-terms <json>               # Debt terms
--coupon-number <n>               # Coupon period
--coupon-payments <json>          # Coupon payments

# Operations
--allocations <json>              # Allocations [{address, amount}, ...]
--allowlist-addresses <addrs>    # Allowlist addresses
--snapshot-after                 # Take snapshot after minting
--continue-on-error              # Continue on error
--delay-ms <ms>                  # Delay between operations

# Transfer
--transfer-mode <mode>           # direct|conditional

# Emergency
--emergency-action <action>       # pause|unpause|freeze|unfreeze
--freeze-addresses <addrs>       # Addresses for freeze
```

### Flow Examples

```bash
# FLOW 1: Setup token with metadata and roles
node dist/interact.js --package-id 0x40f7... --variant standard \
  --action flow_setup \
  --terms "TokenTerms:v1.0" \
  --document-uri "https://docs.example.com/prospectus.pdf" \
  --document-hash "sha256:abc123" \
  --rule-engine-rules '[{"type":"whitelist","addresses":["0x123..."]}]' \
  --max-balance 1000000 \
  --allowlist-addresses 0x456...,0x789...

# FLOW 2: Onboard investors
node dist/interact.js --package-id 0x40f7... --variant allowlist \
  --action flow_onboard --continue-on-error \
  --allowlist-addresses 0x123...,0x456... \
  --jurisdiction-rules '[{"address":"0x123","jurisdiction":"US"}]'

# FLOW 3: Primary issuance with snapshot
node dist/interact.js --package-id 0x40f7... --action flow_issue \
  --allocations '[{"address":"0x123","amount":1000},{"address":"0x456","amount":2000}]' \
  --snapshot-after --delay-ms 1000

# FLOW 4: Secondary transfer (direct or conditional)
node dist/interact.js --package-id 0x40f7... --action flow_transfer \
  --recipient 0x456 --amount 500 --transfer-mode direct

# FLOW 5: Coupon payment
node dist/interact.js --package-id 0x40f7... --variant debt \
  --action flow_coupon --coupon-number 1 \
  --coupon-payments '[{"address":"0x123","amount":50}]'

# FLOW 6: Redemption
node dist/interact.js --package-id 0x40f7... --variant debt \
  --action flow_redeem \
  --allocations '[{"address":"0x123","amount":1000}]'

# FLOW 7: Emergency controls
node dist/interact.js --package-id 0x40f7... --action flow_emergency \
  --emergency-action pause

# Documents
node dist/interact.js --package-id 0x40f7... --action flow_documents \
  --documents '[{"name":"prospectus","uri":"https://docs.ex.com/prospectus.pdf","hash":"sha256:xyz"}]'
```

Run `node dist/interact.js --help` for complete documentation.

### Deployment Steps

#### 1. Setup Environment
```bash
./scripts/setup.sh
```

#### 2. Build Move Package
```bash
iota move build
```

#### 3. Start Localnet (Optional)

```bash
# Start once
./scripts/localnet.sh

# Or with auto-restart on failure (max 3 retries)
./scripts/localnet.sh --watch
```

#### 4. Deploy All Variants

```bash
npm run build
/usr/bin/node dist/deploy.js
```

#### 5. Verify Deployment

```bash
iota client verify-source .
```

Expected output: `Source verification succeeded!`

#### 6. Interact with Tokens

```bash
# Use individual actions
node dist/interact.js --package-id <PACKAGE_ID> --action mint --amount 1000 --recipient <ADDRESS>
node dist/interact.js --package-id <PACKAGE_ID> --action balance --address <ADDRESS>
node dist/interact.js --package-id <PACKAGE_ID> --action pause

# Or use orchestrated flows
node dist/interact.js --package-id <PACKAGE_ID> --action flow_setup --terms "TokenTerms:v1" ...
node dist/interact.js --package-id <PACKAGE_ID> --action flow_issue --allocations '[...]' ...
```

Run `node dist/interact.js --help` for complete documentation.

### Network Configuration

Default testnet RPC: `https://api.testnet.iota.cafe`

Supported networks:
- `localnet` - Local development
- `testnet` - IOTA testnet (Chain ID: 2304aa97)
- `mainnet` - IOTA mainnet
- `devnet` - IOTA devnet


## Deployed Contracts

### Testnet Deployment

| Contract | Package ID | Status | IOTAScan |
|----------|-----------|--------|----------|
| **move-cmtat** (all variants) | `0x40f7600aaa2417f8541dc8219c4cb065ec38ac3c7539f79aee30eb9add594e0a` |  Deployed & Verified | [View on IOTAScan](https://iotascan.com/testnet/object/0x40f7600aaa2417f8541dc8219c4cb065ec38ac3c7539f79aee30eb9add594e0a/contracts) |

**Transaction Details:**
- **Network:** testnet
- **Transaction Digest:** `7vX9YwwKPyQJXH1DMFwXH2fZ27V2KWkgDxfgdoJhD1Ps`



**Deployed Contract Variants:**
- `light_cmtat` - Minimal compliance token
- `allowlist_cmtat` - Token with allowlist/KYC support
- `debt_cmtat` - Token for debt securities
- `standard_cmtat` - Full-featured compliant token

---

## CMTAT Compliance


**Fully Compliant Areas:**
- Core token functionality (via native Coin<T>)
- Mint/Burn operations
- Pause/Freeze (via native DenyList)
- Access control (capability-based)
- Snapshot functionality
- Interest calculations & coupon schedules
- RuleEngine v2 (blacklist, sanction list, max balance, conditional transfers)
- Debt tracking (full instrument, maturity, redemption)
- Claim-based interest distribution



**In Development for Full Compliance:**
- Forced transfer (regulatory requirement) -  Court order enforcement, regulatory seizures, legally required for securities

- Partial token freezing  - Granular balance freezing for collateral, lending, margin requirements



### Comparison to Solidity Reference

**Advantages:**
- Native token architecture (no balance mappings)
- VM-enforced supply integrity
- Capability-based security model
- Parallel execution support
- Type-safe by compiler



## License

Mozilla Public License 2.0 (MPL-2.0)

---

## Resources

- **CMTAT Standard:** https://www.cmtat.org
- **CMTAT Solidity Reference:** https://github.com/CMTA/CMTAT
- **IOTA Documentation:** https://docs.iota.org


---

*Built with IOTA Move native architecture for compliant securities*

*Version 0.2.1*
