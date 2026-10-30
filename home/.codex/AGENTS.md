# Global Codex Instructions

## First Principle

- NO BLOAT. NO SLOP. NO SCOPE-CREEP.

## Software Development

Follow the [Manifesto for Agile Software Development](https://agilemanifesto.org/).

Prefer:

- Individuals and interactions over processes and tools.
- Working software over comprehensive documentation.
- Customer collaboration over contract negotiation.
- Responding to change over following a plan.

The items on the right still have value, but prioritize those on the left.

## Korean Response Tone

- When responding in Korean, use polite speech (`존댓말`) by default.
- Do not use casual speech (`반말`) unless the user explicitly asks for it.
- Keep the tone direct and technical; politeness does not require cheerleading,
  flattery, or filler.

## Pull Request And Merge Rules

- When the user asks to create a pull request, use the `git:pr-create` skill and its repository template/workflow. Do not hand-roll PR titles or bodies unless the user explicitly asks for a manual override.
- Before merging, inspect the PR state and preserve the PR title/body and default merge metadata. Do not pass manual `--subject` or `--body` values to `gh pr merge` unless the user explicitly gives those exact values.
- For admin merges, prefer `gh pr merge --admin` with the repository's normal merge method and metadata. Do not switch to alternate APIs or metadata-changing fallbacks without first diagnosing the failure.
- If a merge has already landed with wrong commit metadata, state that PR metadata edits cannot change the existing merge commit. Do not claim to fix already-written commit history without an explicit history-rewrite request.

## Infrastructure Safety

- Treat permission to inspect or estimate as read-only permission only. It does not grant permission to create, modify, delete, or restart infrastructure resources.
- Do not create temporary Kubernetes pods/jobs, run ad hoc workloads in a cluster, port-forward services, exec into production-like infrastructure for database access, modify cloud resources, or perform any other infrastructure operation unless the user explicitly approves that specific action first.
- If read-only AWS/Kubernetes/database commands are insufficient for an estimate, stop and ask for approval before escalating to any action that changes cluster/cloud state, even temporarily.

## CCK Bazel Concurrency

- In any CCK checkout or worktree, serialize Bazel `build`, `test`, and
  `coverage` commands across agent sessions with the shared host lock:
  `flock --close --timeout 55 "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/cck-bazel-build.lock" bazel <command> ...`
- If lock acquisition times out, do not run the command without the lock.
  Report the contention and retry after a status update. Do not lock `bazel run`.

## ASD-STE100 Simplified Technical English

- A local copy of ASD-STE100 Issue 9 is in `~/.local/share/ste100/issue9/`. Source:
  <https://doi.org/10.5281/zenodo.23666005>. If it is missing, ask the user to install it
  with `scripts/ste100/apply.sh` of the personal-settings repository.
  - `ste100.md`: all pages except the dictionary body (front matter, change log, writing
    rules, dictionary introduction, index), with one heading per page and its page label.
    Underlined text is in `<u></u>`. Spaces keep table columns apart.
  - `dictionary.json`: dictionary entries with `word`, `pos`, `approved`, `forms`,
    `help` (notes on the word), `senses` (`meaning` or `alternative`, `help` notes,
    `ste_examples`, `non_ste_examples`), `page`, and `pdf_page`. A phrase headword can have
    an empty `pos`. In an approved entry, `alternative` senses are the words to use for
    other meanings. A sense with empty text is a row with a help note and, usually, examples.
    A note that introduces many alternatives is on the first one. The two example lists are
    not paired by index.
  - `ASD-STE100_ISSUE9.pdf`: the original.
- When you write or check STE text, look up each word in `dictionary.json`, not from memory.
  Cite rules by number and page label from `ste100.md`. For example:

  ```bash
  jq '.[] | select(.word | ascii_downcase | startswith("carry"))' \
    ~/.local/share/ste100/issue9/dictionary.json
  ```
- Do not copy text from these files into repositories, issues, PRs, or other published
  artifacts. ASD forbids reproduction without its written authority. Cite the DOI and the
  rule numbers instead.
