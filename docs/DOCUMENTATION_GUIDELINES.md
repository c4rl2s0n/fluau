# Documentation guidelines

These rules apply to framework docs in this repository. They keep prose complementary to the code instead of competing with it.

## Principles

**Do not restate what the code already says.** Exact names, signatures, permission strings, manifest keys, and field-by-field schemas belong in source, annotations, manifests, and generated bindings. Docs should not copy them into tables that go stale.

**Stay descriptive and explanatory at a higher level.** Prefer intent, invariants, trust boundaries, and flows. A reader should finish a doc understanding *why* the system is shaped a certain way and *how* pieces collaborate.

**Do not inventory classes, functions, values, or files.** Roles and collaboration matter more than symbol lists. If a section reads like an API reference extracted from the tree, rewrite it as a narrative.

**Reference paths only when they orient the reader.** Pointing at an example package or a codegen overview is fine. A component-by-component file map is not.

**Answer questions the code cannot.** Architecture story, mental models, when to choose an extension path, security posture, and product limits belong here. Implementation detail does not.

## Practical checks

Before merging a doc change, ask:

1. Would deleting this paragraph lose understanding that is not already obvious from reading the code?
2. Does this section name symbols for their own sake, or to explain a concept?
3. Will this still be true after a rename or a small API tweak?

If the answer to (1) is no, cut it. If (2) is “for their own sake,” rewrite. If (3) is no, move the detail back into code or examples.
