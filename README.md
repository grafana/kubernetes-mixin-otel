# tsqtsq deliverables (prepared by Cloud Agent)

This branch is a **delivery vehicle only** — it is not meant to be merged.
It carries two prepared commit series for [grafana/tsqtsq](https://github.com/grafana/tsqtsq),
because the agent's GitHub token has no push access to that repository
(`Permission to grafana/tsqtsq.git denied to cursor[bot]`).

Delete this branch once the tsqtsq branches are pushed.

## What's here

| Path | Contents |
| --- | --- |
| `bundles/tsqtsq-branches.bundle` | Both branches as a git bundle (exact commits, signed, author `skl`) |
| `patches/jsonnet-library/` | 3-patch series: jsonnet port + recorder-generated conformance corpus + CI |
| `patches/relicense/` | 1-patch series: AGPL-3.0-only -> Apache-2.0 relicense |

Both series are based on tsqtsq `main` at `c406262` and are fully tested:
144/144 jest tests, 115/115 conformance string cases and 4/4 error cases
replayed against the jsonnet implementation.

## Option A - push the prepared commits as-is (fastest)

Commits are authored by `Stephen Lang <skl@users.noreply.github.com>` and
signed/verified via the Cursor agent key (committer `Cursor Agent`), the same
pattern GitHub already shows as Verified on kubernetes-mixin-otel agent
branches. Commit SHAs are preserved, which keeps the kubernetes-mixin-otel
PR's `jsonnetfile.lock.json` pin (`711e778a...`) valid immediately:

```bash
git clone https://github.com/grafana/tsqtsq && cd tsqtsq
git fetch https://github.com/grafana/kubernetes-mixin-otel.git cursor/tsqtsq-deliverables-4994
git checkout FETCH_HEAD -- bundles patches
git bundle verify bundles/tsqtsq-branches.bundle
git fetch bundles/tsqtsq-branches.bundle 'refs/heads/*:refs/heads/*'
git push origin cursor/jsonnet-library-4994 cursor/relicense-apache-2-4994
git rm -r bundles patches   # drop the delivery files from your checkout
```

## Option B - apply as your own commits (fully skl-signed)

`git am` preserves the author (`skl`) but makes **you** the committer, so with
your own commit signing enabled every commit is 100% skl: authored, committed,
signed and verified by you.

```bash
git clone https://github.com/grafana/tsqtsq && cd tsqtsq
git fetch https://github.com/grafana/kubernetes-mixin-otel.git cursor/tsqtsq-deliverables-4994
git checkout FETCH_HEAD -- patches

git checkout -b jsonnet-library main
git am --gpg-sign patches/jsonnet-library/*.patch
git push origin jsonnet-library

git checkout -b relicense-apache-2 main
git am --gpg-sign patches/relicense/*.patch
git push origin relicense-apache-2

git rm -r patches
```

Note: Option B produces new commit SHAs. The kubernetes-mixin-otel PR pins the
Option-A SHA in `jsonnetfile.lock.json`; after pushing via Option B, refresh it
on that PR branch with:

```bash
make tmp/bin/jb   # or: go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
tmp/bin/jb update github.com/grafana/tsqtsq/jsonnet
git commit -am 'deps: refresh tsqtsq pin' && git push
```

(If you used a different branch name than `cursor/jsonnet-library-4994`, also
update `version` in `jsonnetfile.json` accordingly.)

## Then open the two PRs

Suggested titles/bodies are in the Cloud Agent conversation summary; in short:

1. **jsonnet library PR** (`cursor/jsonnet-library-4994` -> `main`):
   "feat: add jsonnet implementation with recorder-generated conformance corpus"
2. **relicense PR** (`cursor/relicense-apache-2-4994` -> `main`):
   "chore: relicense from AGPL-3.0-only to Apache-2.0" — license change only,
   kept separate so licensing review is not entangled with code review.
