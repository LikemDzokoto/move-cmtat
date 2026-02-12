# CMTAT Bond Instrument Implementation Plan

## Overview
Full implementation of bond instrument tracking, credit events, interest calculations, document management, and external debt engine pattern using native IOTA Move architecture.

## SPECIFICATIONS (User Requirements)
- **Fixed-point rates**: 4-6 decimal places (use u64 with multiplier 1_000_000)
- **Day count conventions**: 30/360, Actual/360, Actual/365, Actual/Actual
- **Business day conventions**: Following, Modified Following, Preceding, Unadjusted
- **DebtEngine**: External pattern for multi-token reuse
- **Documents**: Free-form naming (Prospectus, Indenture, Terms)
- **Maturity behavior**: Allow redemptions, track principal via credit events, optional deactivation after full redemption
- **Timestamps**: Seconds (Unix epoch)

---

## FILE STRUCTURE

```
sources/
├── components/
│   ├── debt.move                    # [ENHANCED] Core debt structs
│   ├── allowlist.move               # [EXISTING]
│   ├── validation.move              # [EXISTING]
│   ├── bond_validation.move         # [NEW] Bond validation & interest math
│   └── document_registry.move       # [NEW] ERC-1643 document management
├── engines/
│   ├── snapshot_engine.move         # [FIXED] Complete balance tracking
│   ├── rule_engine.move             # [EXISTING]
│   ├── rule_engine_v2.move          # [EXISTING]
│   ├── interest_engine.move         # [NEW] Coupon schedule & calculations
│   └── debt_engine.move             # [NEW] External multi-token debt management
├── contracts/
│   └── debt_cmtat.move              # [UPDATED] Full integration
└── interfaces/
    └── icmtat.move                  # [UPDATED] New interfaces
```

---

## PHASE 1: Enhanced debt.move

### New Enums
```move
public enum DayCountConvention has copy, drop, store {
    Thirty360, Actual360, Actual365, ActualActual
}

public enum BusinessDayConvention has copy, drop, store {
    Following, ModifiedFollowing, Preceding, Unadjusted
}
```

### New Structs

**DebtIdentifier** - Entity identification:
```move
issuer_name: String              // LEI or entity name
issuer_description: String       // Detailed description
guarantor: String                // LEI/UID of guarantor
debt_holder_representative: String
isin: String                     // ISIN or security identifier
```

**DebtInstrument** - Bond specification:
```move
interest_rate: u64               // Fixed-point: rate * 1_000_000
par_value: u64                   // Face value
minimum_denomination: u64        // Minimum tradable
issuance_date: u64               // Unix seconds
maturity_date: u64
coupon_frequency: String         // "ANNUAL", "SEMI_ANNUAL", etc.
day_count_convention: DayCountConvention
business_day_convention: BusinessDayConvention
currency: String
currency_contract: address
```

**CreditEvents** - Structured events:
```move
flag_default: bool
flag_redeemed: bool
flag_matured: bool
rating: String                   // "AAA", "BB+"
principal_distributed: u64
next_coupon_date: u64
```

**BondTerms** - Additional terms:
```move
call_schedule: String
put_schedule: String
sinking_fund_schedule: String
convertible_terms: String
collateral_description: String
```

**Enhanced DebtState**:
```move
identifier: DebtIdentifier
instrument: DebtInstrument
terms: BondTerms
credit_events: CreditEvents
debt_engine: address
use_external_engine: bool
```

---

## PHASE 2: Fixed snapshot_engine.move

**Fix placeholder implementations:**
- Implement actual balance recording in `record_balance_at_snapshot`
- Fix table lookups in `get_balance_at_snapshot`
- Remove dummy returns in `get_snapshot`, `get_total_supply_at`
- Use proper `vec_map::contains` checks

**Pattern:** Nested IOTA tables for snapshot_id → address → balance mapping

---

## PHASE 3: New bond_validation.move

**Fixed-point constants:**
```move
const INTEREST_RATE_MULTIPLIER: u64 = 1_000_000;
const DAYS_360: u64 = 360;
const DAYS_365: u64 = 365;
```

**Functions:**
- `calculate_day_count_30_360()` - 30/360 convention
- `calculate_day_count_actual_360()` - Actual/360
- `calculate_day_count_actual_365()` - Actual/365
- `calculate_day_count_actual_actual()` - Actual/Actual
- `calculate_simple_interest()` - Principal * rate * (days/total_days)
- `calculate_accrued_interest()` - From issuance to current
- `is_matured()` - Check against maturity date
- `validate_minimum_denomination()` - Check transfer amounts
- `is_redemption_allowed()` - Matured but not fully redeemed
- `is_fully_redeemed()` - All principal returned

---

## PHASE 4: New document_registry.move

**Structs:**
```move
Document {
    name: String
    hash: String
    uri: String
    last_modified: u64
}

DocumentRegistryState {
    documents: VecMap<String, Document>
    document_count: u64
}
```

**Functions:**
- `add_document()` - Add new document with event
- `update_document()` - Update hash/URI with event
- `remove_document()` - Remove with event
- `get_document()` - Query by name
- `document_exists()` - Check existence
- `get_all_document_names()` - List all documents

**Events:** DocumentAdded, DocumentUpdated, DocumentRemoved

---

## PHASE 5: New interest_engine.move

**Structs:**
```move
CouponPayment {
    coupon_number: u64
    payment_date: u64
    record_date: u64
    amount_per_bond: u64
    total_amount: u64
    paid: bool
    actual_payment_date: Option<u64>
}

InterestEngineState {
    schedule: InterestSchedule
    payment_history: Table<u64, CouponPayment>
    total_interest_paid: u64
}
```

**Functions:**
- `generate_coupon_schedule()` - From bond terms
- `get_next_coupon()` - Query upcoming payment
- `record_coupon_payment()` - Mark as paid
- `is_coupon_due()` - Check if payment date reached
- `get_total_interest_paid()` - Accumulated payments
- `calculate_accrued_interest()` - Current accrual

**Events:** CouponScheduled, CouponPaid, ScheduleCreated

---

## PHASE 6: New debt_engine.move

**Purpose:** External contract for multi-token debt data management

**Structs:**
```move
TokenDebtData {
    identifier: DebtIdentifier
    instrument: DebtInstrument
    terms: BondTerms
    credit_events: CreditEvents
}

DebtEngineState {
    token_debt_data: Table<address, TokenDebtData>
    supported_tokens: vector<address>
}
```

**Capabilities:** DebtEngineAdminCap

**Functions:**
- `register_token()` - Add token to engine
- `update_token_identifier()` - Modify issuer info
- `update_token_instrument()` - Modify bond terms
- `update_token_credit_events()` - Modify credit status
- `get_token_debt_data()` - Query full data
- `require_token_not_in_default()` - Validation

**Pattern:** Tokens call external engine instead of storing data locally

---

## PHASE 7: Updated debt_cmtat.move

### New Capabilities
```move
DebtAdminCap           // Manage debt instrument data
CreditEventsCap        // Manage credit events
DocumentAdminCap       // Manage documents
BondValidatorCap       // Execute bond validations
InterestAdminCap       // Manage interest/coupons
```

### Enhanced ComplianceState
```move
ComplianceState {
    debt_state: debt::DebtState
    interest_engine: interest_engine::InterestEngineState  // NEW
}
```

### New View Functions
- `issuer_name()`, `isin()` - Debt identifier fields
- `interest_rate()`, `par_value()`, `maturity_date()` - Instrument fields
- `is_default()`, `is_redeemed()`, `is_matured()`, `credit_rating()` - Credit events
- `accrued_interest()` - Calculate current interest
- `next_coupon_amount()` - Upcoming payment
- `document()`, `document_exists()` - Document queries

### New Admin Functions
**Debt Identifier:**
- `set_debt_identifier()`, `set_issuer_name()`, `set_isin()`

**Debt Instrument:**
- `set_debt_instrument()`, `set_interest_rate()`, `set_maturity_date()`
- `set_day_count_convention()`, `set_business_day_convention()`

**Credit Events:**
- `set_credit_events()`, `flag_default()`, `clear_default()`
- `set_credit_rating()`, `record_principal_distribution()`
- `flag_bond_redeemed()`

**Documents:**
- `add_document()`, `update_document()`, `remove_document()`

**Interest:**
- `generate_coupon_schedule()`, `record_coupon_payment()`

**Bond Lifecycle:**
- `check_and_update_maturity()`, `validate_redemption()`

### Enhanced Transfer/Mint/Burn
- Check default status
- Check fully redeemed status
- Validate minimum denomination
- Support external debt engine validation
- Check maturity (emit warnings, don't block)

### New Redemption Functions
```move
redeem()           // Redeem bonds after maturity
batch_redeem()     // Batch redemption
```
- Validate redemption allowed (matured, not fully redeemed)
- Record principal distribution
- Check if fully redeemed, flag accordingly

### Enhanced Snapshot Functions
- `schedule_snapshot()` - Convert ms to seconds
- `record_account_balance_at_snapshot()` - Actually record balances
- `get_balance_at_snapshot()` - Query historical balances

---

## KEY FEATURES SUMMARY

✅ **Full Bond Instrument Tracking**
- DebtIdentifier: LEI, ISIN, guarantor info
- DebtInstrument: Rates, dates, conventions, currency
- BondTerms: Call/put schedules, collateral

✅ **Advanced Credit Events**
- Default, redeemed, matured flags
- Credit rating tracking
- Principal distribution tracking

✅ **Fixed-Point Interest Calculations**
- 4-6 decimal precision (u64 * 1_000_000)
- All day count conventions
- Accrued interest calculation

✅ **Business Day Handling**
- Following, Modified Following
- Preceding, Unadjusted conventions

✅ **Complete Snapshot Engine**
- Balance recording at specific timestamps
- Historical balance queries
- Dividend calculation support

✅ **Document Management (ERC-1643)**
- Free-form naming
- Hash and URI tracking
- Version history

✅ **External DebtEngine**
- Multi-token debt data management
- Reduces per-token contract size
- Centralized updates

✅ **Interest/Coupon Tracking**
- Schedule generation
- Payment recording
- Accrual calculations

✅ **Maturity-Aware Flows**
- Redemption after maturity
- Principal tracking
- Optional deactivation

✅ **Granular Capabilities**
- Separate roles for different operations
- Native IOTA capability pattern

---

## ESTIMATES

- **Lines of Code**: ~2,500-3,000 across all files
- **Implementation Time**: 2-3 days with testing
- **Breaking Changes**: Yes (DebtState structure)
- **Migration Path**: Needed for existing deployments

---

## READY TO IMPLEMENT

This plan captures all your specifications:
- Fixed-point rates (4-6 decimals) ✓
- All day count conventions ✓
- All business day conventions ✓
- External DebtEngine ✓
- Free-form documents ✓
- Maturity redemption flow ✓
- Unix seconds timestamps ✓

**Approve this plan to proceed with implementation.**