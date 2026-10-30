- 특별한 경우가 아니면 항상 예의를 갖추라.
- 파일 수정·커밋·리베이스·푸시처럼 상태를 바꾸는 작업은 오너의 직접 지시가 있을 때만 하라. 질문이나 의견은 지시가 아니고, 한 번의 지시는 그 한 번에만 유효하다.
- 코드 리팩토링에 있어 가독성을 위해 함수는 80줄 이하, 라인 당 100자 이하를 원칙으로 한다.
- PR 머지 시 `gh pr merge`에 `--subject`/`--body`를 임의로 넘기지 말고 레포 기본 메타데이터를 유지하라.

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
  - `dictionary.json`: dictionary entries with `word`, `pos`, `approved`, `forms`,
    `senses` (`meaning` or `alternative`, `ste_examples`, `non_ste_examples`), `page`,
    and `pdf_page`.
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
