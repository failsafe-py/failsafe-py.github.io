# AGENTS.md

## Commits

Conventional commits. Terse descriptions — a subject line, nothing more unless the
*why* is genuinely non-obvious.

```
<type>(<optional scope>): <description>
```

- `<description>`: imperative, lower case, no trailing period, ≤ 50 chars.
- Types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `chore`, `build`, `ci`.
- Scope is the page or area (`retry`, `theme`, `nav`), omitted when it adds nothing.
- Body only for surprising decisions or a `BREAKING CHANGE:` footer. No restating the diff.

Good:

```
docs(retry): document abort conditions
fix(theme): resolve assets through baseurl
chore: port failsafe-go.dev scaffolding
```

Bad: `Updated some files`, `docs: this commit adds a new page about retry policies`.

## Tooling

- No user-wide installs. Containers only — never `gem install` into the system or home
  directory. System Ruby here is 2.6 and cannot build modern Jekyll anyway.
- `bin/build.sh` and `bin/serve.sh` run Jekyll in `jekyll/jekyll:4`.
- `Gemfile.lock` is not committed; the container resolves it.

## Content

- **This is a port of [failsafe-go.dev](https://failsafe-go.dev).** Keep the structure and prose
  unless Python actually differs. Where it differs, say so plainly rather than silently diverging.
- **Never document an API that is not in `~/code/failsafe-py/src/failsafe/`.** Check the
  signature before writing the example. Docstrings are the source of truth; `PLAN.md` is intent.
- Deviations from Go belong on `porting-from-go.md`, not buried in a policy page.
- Gaps are stated, not hidden: hedging is async-only, sync has no cancellation, server-side HTTP
  is not ported.
- Unreleased features get a `{: .callout-unreleased }` note.

## Links

This is an **organisation site**, served from the root of <https://failsafe-py.github.io>, so
`baseurl` is empty.

- Every internal link still goes through `relative_url`, via a reference in
  `_includes/common-links.html`. An empty baseurl makes that a no-op today, and keeps a move to a
  custom domain or a subpath a one-line config change.
- Never hard-code `/retry` or `https://failsafe-py.github.io/...` — the first breaks under any
  future baseurl, the second pins the site to one origin.
- Add a new page's link definition to `common-links.html` and the nav to `_includes/side-menu.md`.

## Before committing

Build and assert that every link resolves and none is broken. A build that succeeds is
not the same as a site whose links resolve.
