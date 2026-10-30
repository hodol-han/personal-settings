# personal-settings (cck/dev)

개인 개발 환경 복원용 설정과 스크립트입니다. 경로와 사용자 값은 실행할 때 정하므로
특정 PC에 묶이지 않습니다.

## 설치 순서

1. 필요한 패키지: `sudo apt install curl jq python3-venv` (uv가 있으면 python3-venv는
   없어도 됩니다)
2. `scripts/agent-instructions/apply.sh`: 전역 에이전트 지침(`~/.claude/CLAUDE.md`,
   `~/.codex/AGENTS.md`)을 `home/` 사본으로 설치합니다.
3. `scripts/ste100/apply.sh`: ASD-STE100 Issue 9를 Zenodo에서 받아
   `~/.local/share/ste100/issue9/`에 변환해 둡니다. 표준 원문은 이 레포에 넣지 않습니다.
4. CCK를 쓸 때만 `scripts/cck-bazel/apply.sh`: `.bazelrc`와 Bazel 캐시 정리 정책을
   설치합니다. CCK 체크아웃과 bazel이 있어야 합니다.

각 스크립트는 같은 디렉터리의 `verify.sh`로 설치 상태를 다시 확인할 수 있습니다.

## 커밋 전 검사

`pre-commit install` 뒤 커밋하면 shfmt와 shellcheck가 돕니다. shfmt가 없으면
`scripts/install-shfmt-temporarily.sh`로 받은 뒤 스크립트 안내대로 PATH에 넣습니다.
