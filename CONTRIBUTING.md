# Contributing

Thanks for helping document Ola scooter software and diagnostics.

## Evidence format

For each finding, provide:

- Exact vehicle generation/model/year and software profile, if known.
- Source path and revision, capture date, and tool version.
- Evidence class: static source, protocol observation, accepted response, physical effect, or independent replication.
- Expected result, observed result, and explicit unknowns.
- Sanitized logs or synthetic fixtures where possible.

Separate observation from interpretation. Preserve unknown units and unverified behavior as unknown.

## Code changes

- Keep read-only decoders and UI separate from vehicle command code.
- Keep simulated/demo transports separate from real vehicle transports.
- Require explicit user confirmation for any active vehicle operation.
- Never add automatic retry/replay behavior for an uncertain vehicle command.
- Add model/build profiles instead of silently changing an existing profile.
- Include tests for parsing, error handling, cancellation, connection loss, stale values, and report privacy.

## Pull request checklist

- [ ] Source revision and build instructions are included.
- [ ] No credentials, private keys, personal identifiers, or raw private captures are included.
- [ ] Model/build profile and evidence class are stated.
- [ ] Unknowns and untested behavior are stated.
- [ ] Demo and physical results are reported separately.
- [ ] App permissions and dependency changes are documented.
- [ ] Build artifacts, if attached, include hash and signing provenance.
