# Changelog
## Added
- RuleEngine v2 as the primary compliance engine (hierarchical rules, VIP bypass, conditional transfers, approvals, blacklist/sanctions, max-balance enforcement).
- Integration of RuleEngine v2 into `standard_cmtat`, `allowlist_cmtat`, and `debt_cmtat` transfers.
- Snapshot Engine for balance snapshots and supply tracking.
- Interest Engine for coupon schedules, payment tracking, claim handling, and accrued interest.
- Debt Engine for multi-token debt instruments and lifecycle logic.
- Debt instrument components and expanded debt features in `debt_cmtat` (identifier, instrument terms, credit events, maturity validation, redemption, interest integration).
- Expanded test coverage, including role/capability tests and cross-contract integration tests.
- Deployment and ops scripts: `scripts/deploy.ts`, `scripts/verify.ts`, `scripts/interact.ts`, `scripts/setup.sh`, `scripts/localnet.sh`.

## Changed
- Core contracts (`light_cmtat`, `allowlist_cmtat`, `debt_cmtat`, `standard_cmtat`) updated to align with native IOTA patterns and RuleEngine v2 enforcement.
- Allowlist and capability granting flows refined for clearer admin control.
- Debt and rule engine implementations refactored to remove legacy logic and unify validation paths.
- Test suites reorganized and expanded to match the new engine architecture and contract integrations.
- Deployment workflow updated to support skipping build, localnet convenience, verification, and interaction flows.

## Improved
- Transfer restriction validation centralized through RuleEngine v2 with clearer restriction codes and lifecycle handling.
- Compliance enforcement strengthened via native IOTA mechanisms (DenyList + capabilities).
- Deployment/verification reliability improved (timeouts, gas budgets, faucet checks, CLI-based address usage).

## Fixed
- Epoch-related test failures in `light_cmtat`.
- `u_64` arithmetic error in RuleEngine v2.
- Compile issues introduced by earlier refactors.
- Noisy test warnings across multiple suites.

## Removed
- Legacy RuleEngine (`sources/engines/rule_engine.move`) in favor of RuleEngine v2.
- Legacy validation component (`sources/components/validation.move`).
- Pause/freeze components (`sources/components/pause.move`, `sources/components/freeze.move`) after moving to native DenyList behavior.
- `sources/interfaces/icmtat.move`.
- `scripts/deploy.sh` in favor of TS-based deploy tooling.
- `sources/components/document_registry.move` and `sources/components/bond_validation.move` (no longer present in current state).
- `tests/bond_validation_tests.move`
