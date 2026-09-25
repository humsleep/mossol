"""필요한 파이썬 패키지를 프로젝트 전용 가상환경에 준비한다.

맥의 Homebrew 파이썬은 시스템 전체 설치를 막는다(PEP 668). 그래서 `pip3 install` 이
`externally-managed-environment` 로 실패한다. 도구를 쓰는 쪽이 이걸 몰라도 되게,
스크립트가 스스로 `.venv/` 를 만들고 그 파이썬으로 자신을 다시 실행한다.

    from _venv import ensure
    ensure("PIL", pip="Pillow")     # 맨 위에서 한 번

`.venv/` 는 저장소에 올리지 않는다(.gitignore).
"""

from __future__ import annotations

import os
import pathlib
import subprocess
import sys
import venv

ROOT = pathlib.Path(__file__).resolve().parent.parent
VENV = ROOT / ".venv"
PY = VENV / "bin" / "python"

# 다시 실행할 때 무한 반복을 막는 표시.
_FLAG = "MOSSOL_TOOL_VENV"


def ensure(module: str, *, pip: str | None = None) -> None:
    """[module] 을 못 불러오면 `.venv` 를 준비해 그 파이썬으로 이 스크립트를 다시 실행한다."""
    try:
        __import__(module)
        return
    except ImportError:
        pass

    if os.environ.get(_FLAG):
        # 이미 venv 안인데도 없다 — 설치가 실패한 것이다. 더 돌지 않는다.
        print(f"{pip or module} 를 설치하지 못했다. 직접 설치하라:\n"
              f"  {PY} -m pip install {pip or module}", file=sys.stderr)
        raise SystemExit(2)

    if not PY.exists():
        print(f"파이썬 가상환경을 만든다 ({VENV.relative_to(ROOT)}/) — 처음 한 번만 걸린다.")
        venv.EnvBuilder(with_pip=True, clear=False).create(VENV)

    # 이미 들어 있으면 pip 을 건너뛴다. 매번 "설치 중" 이 뜨면 시끄럽다.
    have = subprocess.run(
        [str(PY), "-c", f"import {module}"], capture_output=True
    ).returncode == 0
    if not have:
        print(f"{pip or module} 설치 중…")
        r = subprocess.run([str(PY), "-m", "pip", "install", "-q", pip or module])
        if r.returncode != 0:
            print(f"설치 실패. 직접 해 보라:  {PY} -m pip install {pip or module}",
                  file=sys.stderr)
            raise SystemExit(2)

    # 준비된 파이썬으로 같은 명령을 다시 실행하고, 그 결과를 그대로 돌려준다.
    env = {**os.environ, _FLAG: "1"}
    raise SystemExit(subprocess.run([str(PY), *sys.argv], env=env).returncode)
