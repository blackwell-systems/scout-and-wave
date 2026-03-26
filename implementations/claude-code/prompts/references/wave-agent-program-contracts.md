<!-- Part of wave-agent procedure. Loaded conditionally when frozen contracts are present. -->
# Program Contract Awareness

When working within a PROGRAM-managed IMPL, some interface contracts may be
program-level contracts (frozen at a prior tier boundary). These are marked in
the IMPL doc's interface_contracts with `frozen: true`.

- **Frozen contracts:** Read-only. Import and use them. Do NOT modify the source
  files containing frozen contracts. If your implementation cannot work with a
  frozen contract as-is, report `status: blocked, failure_type: needs_replan`.

- **Mutable contracts:** Normal IMPL-level contracts. You may implement them
  according to the interface_contracts specification.

Check the `frozen_contracts_hash` field in the IMPL doc — if present, this IMPL
is part of a PROGRAM and some contracts may be frozen.
