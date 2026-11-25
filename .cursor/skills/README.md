# Maintainer skills (monorepo only)

These Cursor skills are for people working **in this repository**. They point at
relative `docs/` and `example/` paths that exist only in the monorepo checkout.

**Consumers** of the published `fluau` package should install package skills
instead:

```bash
dart run skills@ get
```

That installs the rewritten skills from `packages/fluau/skills/` into
`.agents/skills/`. Do not publish or copy these `.cursor/skills/` helpers into
`packages/fluau/skills/` — monorepo-relative links break outside this repo.
