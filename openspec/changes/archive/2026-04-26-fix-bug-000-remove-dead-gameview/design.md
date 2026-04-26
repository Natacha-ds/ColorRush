## Context

`ColorGame.xcodeproj/project.pbxproj` uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+): source files are **not** listed manually in the pbxproj — they are auto-discovered from the file system at every build. Therefore:

- No `PBXBuildFile` / `PBXFileReference` to remove for `GameView.swift`.
- Deleting the file from disk is enough: Xcode and `xcodebuild` recompute their source graph at the next build.

This finding (made while applying the change) simplifies the operation: a single file touched on the repo side (`ColorGame/GameView.swift` removed), zero pbxproj edits.

## Goals / Non-Goals

**Goals:**
- Remove `ColorGame/GameView.swift` from the repo and Xcode project atomically.
- Guarantee that `xcodebuild ... build` stays green after removal.
- Touch **nothing** other than these two files.

**Non-Goals:**
- Refactor anything inside `LevelGameView.swift` or elsewhere.
- Reorganize the pbxproj (groups, file order).
- Touch `GameView.swift.xcuserstate` or any derived artifact.

## Decisions

### Manual pbxproj editing rather than via Xcode UI

**Decision**: edit `project.pbxproj` directly with targeted `Edit`s on the four affected sections.

**Rationale**: editing through the Xcode UI would require non-scriptable graphical interaction and would likely produce the same diff modulo UUID order. Manual editing is traceable in the commit and idempotent.

**Alternative rejected**: use the `xcodeproj` Ruby gem or `pbxproj` CLI tools. Would add a dev dependency for a one-shot. Not justified.

> Update during apply: the project uses synchronized groups, so this decision became moot — no pbxproj edit was needed at all.

### Validation strategy

**Decision**: double check — (a) post-deletion `grep` to ensure no `GameView` reference remains, (b) `xcodebuild build` to confirm compilation.

**Rationale**: the grep catches "forgotten implicit reference" regressions, the build catches project graph breaks.

## Risks / Trade-offs

- **[Risk]** The pbxproj contains UUIDs like `C652A42A2ED33AC00017BE76` that must be precisely identified for `GameView.swift`. → **Mitigation**: grep `GameView.swift` in the pbxproj to collect UUIDs before editing, then verify no reference remains afterwards. *(Moot — synchronized groups, no UUIDs to chase.)*

- **[Risk]** Potential conflict with `.xcuserstate` (Xcode user UI state) which mentions the open file. → **Mitigation**: this file is already gitignored (commit `8306a24`), so no repo-side impact.

- **[Trade-off]** Manual pbxproj editing is fragile long-term if Xcode regenerates the file. For this one-shot change, the risk is nil (we make the diff, commit, close Xcode beforehand if needed). *(Moot — see above.)*

## Migration Plan

No migration needed. The change is binary: before/after identical at runtime, the dead code disappears.

**Rollback**: `git revert` the commit; the file and its pbxproj entries return as-is.
