---
name: maintain-patch-stack
description: Author, audit, rebase, and publish this fork's small `[PATCH]` commit stack on top of canonical T3 Code upstream. Use when adding or revising a local T3 customization, fetching upstream changes, deciding whether upstream supersedes a patch, resolving a patch-stack rebase, or publishing the shared patch-stack branch.
---

# Maintain Patch Stack

Keep `patch-stack` as a linear sequence of self-contained `[PATCH]` commits on
top of `upstream/main`.

- `upstream` is the canonical `pingdotgg/t3code` repository.
- `origin` is the public `johnshaughnessy/t3code` fork.
- `origin/main` remains a clean, fast-forward-only mirror of `upstream/main`.
- `origin/patch-stack` is the one shared customization stack consumed by all
  managed deployments.

Do not create independent host patch stacks. Host-only values and operations
belong in private deployment configuration, not in this public repository.

## Protect the public boundary

Treat every commit and commit message pushed to `origin` as permanently public.
Never commit credentials, `.env` files, pairing URLs, T3 userdata, private
network addresses, logs, certificates, provisioning profiles, signing
identifiers, host-specific bundle identifiers, or derived secret material.
Use environment variables or ignored local configuration for deployment values.

Before every push of `patch-stack`:

1. Inspect every message and complete diff in `upstream/main..HEAD`.
2. Run `.agents/skills/maintain-patch-stack/scripts/audit-public-stack.sh`.
3. Stop rather than push when a value's sensitivity is uncertain.

The audit script is a high-signal guard, not proof that a stack is safe. If a
secret ever enters public history, stop, rotate the credential immediately,
and rewrite the affected public refs. A later deletion is insufficient.

## Author one patch

Start from a clean `patch-stack` worktree. Define one independently useful
behavior change and minimize its conflict surface. Avoid unrelated formatting,
renames, generated native projects, lockfile churn, or dependency updates.
Include focused tests and durable documentation needed to make that concern
complete.

Use this commit structure:

```text
[PATCH] <short imperative description>

Intent:
<why the patch exists and its user-visible outcome>

Behavior:
- <important behavior and edge cases>

Design constraints:
- <choices future conflict resolution must preserve>

Integration:
- <affected clients, providers, contracts, connection modes, or lifecycle>

Verification:
- <focused checks and runtime evidence>

Rebase notes:
- <conflict hotspots and exact upstream supersession criteria>
```

Omit a section only when it has no durable content. Describe semantic behavior,
not a file-by-file changelog. Inspect the staged diff and message before
committing. Every local commit must contain only its stated concern.

## Update from canonical upstream

### Discover and protect

Run read-only discovery first:

```bash
git status --short --branch
git remote -v
git fetch --prune upstream
git fetch --prune origin
git merge-base patch-stack upstream/main
git log --reverse --format='%H %s' upstream/main..patch-stack
git cherry upstream/main patch-stack
```

Require a clean worktree and verify the remote identities above. Record the
literal old base, local tip, and `origin/patch-stack` tip. Create a timestamped
local recovery branch before rewriting history:

```bash
git branch patch-stack-backup/YYYYMMDD-HHMMSS OLD_TIP
```

Substitute the recorded commit; do not reuse the placeholder. Keep recovery
branches local unless the user explicitly authorizes publishing one.

### Audit semantically

Before rebasing:

- Read every `[PATCH]` message and diff in oldest-first order.
- Read upstream commits since the old base, especially changes to overlapping
  paths, contracts, clients, providers, connection modes, and lifecycle.
- Treat patch-id equivalence and conflict-free application as signals, not
  proof of behavioral parity.
- Classify each patch as still needed, partly superseded, fully superseded, or
  design-conflicting.
- Verify every documented constraint. Upstream may implement the headline while
  omitting an edge case or surface that the patch preserves.

### Rebase and verify

Run `git rebase upstream/main`. Resolve each conflict in the patch currently
being replayed, preserving its documented intent while adopting upstream
structure and naming. Keep resolutions narrow.

- Drop a patch only when upstream satisfies its Intent, Behavior, Design
  constraints, and Integration sections.
- When upstream partly supersedes a patch, retain the smallest remaining delta
  and update its message.
- When no mechanically correct resolution preserves both designs, leave the
  recovery branch intact and ask the user to choose the desired behavior.
- Run the smallest focused tests appropriate for every changed or resolved
  concern. Follow the repository's verification rules; do not substitute a
  repository-wide check for focused evidence.

Finish by reviewing the rewrite:

```bash
git range-diff OLD_BASE..OLD_TIP upstream/main..HEAD
git log --reverse --format='%H%n%B%n---' upstream/main..HEAD
git status --short --branch
.agents/skills/maintain-patch-stack/scripts/audit-public-stack.sh
```

Confirm that every local commit starts with `[PATCH]`, represents one concern,
retains durable context, and leaves a clean worktree.

### Publish deliberately

Fast-forward the fork mirror without rewriting it:

```bash
git push origin upstream/main:main
```

If that is not a fast-forward, stop and investigate the unexpected fork-main
divergence. Publish the audited rewritten stack using an explicit lease against
the previously recorded remote tip:

```bash
git push --force-with-lease=patch-stack:OLD_REMOTE_TIP origin patch-stack
```

Never use unconditional force, never push local patches to `upstream`, and never
put a deployment secret into a command line or commit message. After publishing,
managed deployment checkouts may fetch and adopt `origin/patch-stack`; they do
not rebase their own copies.

## Interrupted rebases

- Inspect `git status` and the current patch before acting.
- Continue only after testing a deliberate conflict resolution.
- Skip only a patch proven fully superseded or empty.
- Abort when the chosen strategy is wrong; the recovery branch remains intact.
- Never mix a new feature into a conflict resolution or rewrite upstream commits.
