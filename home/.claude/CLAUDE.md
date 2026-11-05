- 특별한 경우가 아니면 항상 예의를 갖추라.
- 파일 수정·커밋·리베이스·푸시처럼 상태를 바꾸는 작업은 오너의 직접 지시가 있을 때만 하라. 질문이나 의견은 지시가 아니고, 한 번의 지시는 그 한 번에만 유효하다.
- 코드 리팩토링에 있어 가독성을 위해 함수는 80줄 이하, 라인 당 100자 이하를 원칙으로 한다.
- PR 머지 시 `gh pr merge`에 `--subject`/`--body`를 임의로 넘기지 말고 레포 기본 메타데이터를 유지하라.

## Maintainability (SWE Iron Rule)

- Maintainability is the iron rule: put each responsibility in its one correct owner, and
  keep the abstraction level the same as the surrounding code.
- Get an independent agent review against this rule two times: at the implementation-plan
  stage and before you open a PR. When a contract, a name, or a module location changes,
  do the review again before the user asks.
  - Lens: Kent Beck and Robert C. Martin (Uncle Bob). Sources:
    - One owner per responsibility: Single Responsibility Principle (Robert C. Martin,
      _Agile Software Development_ and _Clean Architecture_: a module is responsible to
      one actor), and Once and Only Once (Kent Beck, Extreme Programming).
    - One abstraction level: Composed Method (Kent Beck, _Smalltalk Best Practice
      Patterns_), and One Level of Abstraction per Function with the Stepdown Rule
      (Robert C. Martin, _Clean Code_, chapter 3).
    - Code smells and refactorings: Martin Fowler, _Refactoring_ (Fowler and Kent Beck
      wrote the code smell chapter). refactoring.guru presents this catalog.
  - Check: responsibility location, one policy spread over many places, abstraction level,
    functions of at most 80 lines, and lines of at most 100 characters.
  - Put the refactoring.guru catalogs (<https://refactoring.guru/refactoring>) in the
    review prompt: all code smells (Bloaters, Object-Orientation Abusers, Change
    Preventers, Dispensables, Couplers) as the checklist, and the refactoring techniques
    (for example Rename Method, Move Method, Replace Data Value with Object, Remove Middle
    Man) as the vocabulary for fixes.
  - A fact-check review does not replace this review.
- Put these principles in the review prompt as written:
  1. The purpose sets the scope. Do not change unrelated product features to make a
     necessary change.
  2. Align responsibility and abstraction level. The names, parameters, return values,
     and dependencies of an interface or a function stay at one level. If a responsibility
     is in the wrong location, move it. Do not only rename it.
  3. Reuse the existing owners and contracts first. Examine the real producers and
     consumers, and add a new structure only for a requirement that they cannot satisfy.
  4. Standards and common conventions come first. A custom approach needs a specific need
     and evidence.
  5. Satisfy the specification first. Do not change a requirement to justify the
     implementation, and do not treat a dependency that you added as a necessary condition.
  6. Completion needs execution evidence and an independent check. Verify the directly
     related behavior first, and keep design, implementation, local verification, merge,
     and production acceptance separate.

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
