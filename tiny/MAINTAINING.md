# ego tiny 유지 지침

원본(ego lite)이 계속 바뀌어도 ego tiny가 **원본과 합쳐진 상태**를 유지하기 위한 규칙입니다.
사람과 에이전트 모두 이 문서를 따릅니다.

## 원칙

1. **ego tiny의 변경은 `tiny/` 안에 둔다.** 원본 파일을 직접 고치지 않습니다. 원본 파일을 고치면 병합할 때마다 충돌합니다.
2. **원본 파일에 허용된 변경은 세 가지뿐이다.** 모두 스크립트가 다시 만들어 낼 수 있습니다.
   - 제품 이름 치환 (`tiny/rename-source.sh`)
   - 최상위 `README.md` (ego tiny의 것으로 유지)
   - `AGENTS.md` 맨 위의 ego tiny 안내 블록 (`tiny/agents-head.md`)
3. **충돌은 원본 쪽으로 해결한다.** 그런 다음 위 세 가지를 다시 입힙니다. 손으로 충돌을 풀지 않습니다.
4. **런타임 동작을 바꾸고 싶으면 빌드 단계에서 바꾼다.** `tiny/build-tiny.sh`가 빌드 결과물을 고칩니다(예: 상태 디렉터리 `~/.ego-tiny`). `package/ego-browser/src`는 원본 그대로 둡니다.
5. **전송이 살아 있는 빌드를 만들지 않는다.** 패치 대상이 사라지면 빌드는 실패해야 합니다. 실패를 건너뛰게 고치지 말고, 원인을 다시 조사합니다.

## 업데이트는 두 갈래다

| 무엇이 바뀌나 | 어디서 오나 | 반영 방법 |
| --- | --- | --- |
| 런타임, 가이드, 사이트 학습 | `citrolabs/ego-lite` 저장소 | `tiny/sync-upstream.sh` |
| 브라우저 앱(Chromium, 데몬, 웹 UI) | ego lite 앱의 자체 업데이트 | `tiny/build-tiny.sh --install` |

둘은 서로 독립적입니다. 보통은 한 번에 처리합니다.

```bash
tiny/sync-upstream.sh --install
```

## 저장소 업데이트 절차

1. 작업 트리를 깨끗하게 만든다(커밋하거나 stash).
2. `tiny/sync-upstream.sh`를 실행한다. 하는 일:
   - `upstream/main`을 가져와 병합한다. 충돌은 원본 쪽을 택한다.
   - `tiny/apply-overlay.sh`로 이름 치환, `README.md`, `AGENTS.md` 블록을 다시 입힌다.
   - 런타임 테스트(`npm test`)를 돌린다.
3. 테스트가 실패하면 원본에서도 실패하는지 먼저 확인한다(`git stash` 없이 `upstream/main`을 따로 체크아웃해 비교). 원본에서도 실패하면 ego tiny의 문제가 아니다.
4. 원본이 새 파일에 `ego lite`를 새로운 표기로 썼는지 확인한다. 아래 명령의 결과가 비어 있어야 한다.
   ```bash
   git grep -nIiE 'ego[ (]*lite' -- . ':!tiny' ':!README.md' ':!*package-lock.json' ':!.github' | grep -v 'ego-lite'
   ```
   남은 표기가 있으면 `tiny/rename-source.sh`와 `tiny/patch_app.py`의 `RENAMES`에 추가한다.
5. 푸시한다.

## 앱 업데이트 절차

1. ego lite를 실행해 스스로 최신 버전으로 올라가게 둔다.
2. ego tiny를 종료하고 `tiny/build-tiny.sh --install`을 실행한다.
3. 빌드가 **"endpoints not found"** 로 실패하면, 제작사가 주소를 옮기거나 바꾼 것이다. [새 엔드포인트 조사](#새-엔드포인트-조사)를 따른 뒤 `tiny/patch_app.py`를 고친다.
4. 설치 후 [검증](#검증)을 수행한다.

### 버전에 묶인 패치

`tiny/patch-chromium-xslt.py`는 **특정 버전의 바이너리 오프셋**에 묶여 있습니다(0.6.2.9, 0.6.2.10).
새 ego lite 버전에서는:

- 원본이 Chromium을 올려 이미 수정을 포함했는지 확인한다(`ego-tiny --version`의 chromium 버전이 156.0.8078.96 이상이면 포함).
- 포함했다면 `build-tiny.sh`의 `case`에 새 버전을 추가하지 않는다. 그대로 두면 패치는 적용되지 않는다.
- 포함하지 않았다면 새 오프셋과 해시를 조사해 `ROUTINES`에 추가한다. 해시가 맞지 않으면 스크립트가 거부하므로, 잘못된 위치를 덮어쓰지 않는다.

## 새 엔드포인트 조사

새 버전을 받을 때마다, 그리고 빌드가 실패했을 때 수행합니다.

1. **원본 Chromium과 비교한다.** ego lite 프레임워크에만 있고 같은 버전대의 Chrome에는 없는 호스트를 찾는다.
   ```bash
   strings -a "<ego Framework>" | grep -oE '(https?|wss?)://[a-zA-Z0-9.-]+\.[a-z]{2,}' | sort -u
   ```
2. **압축된 웹 UI를 푼다.** `resources.pak`의 항목은 gzip 또는 brotli라서 `grep`으로 보이지 않는다. `tiny/patch_app.py`의 `patch_pak`이 푸는 방식을 그대로 써서 호스트를 뽑는다.
3. **번들된 Node 데몬을 본다.** `Resources/local-ego-daemon` 아래 JS에서 DSN, 분석 키, 호스트를 찾는다. 데몬은 Chromium 네트워크 스택을 쓰지 않으므로 **실행 플래그로는 막히지 않고, 파일 패치로만 막힌다.**
4. 찾은 주소를 `tiny/patch_app.py`(`BINARY_URLS`, `DAEMON_TEXT`, `PAK_HOSTS`)와 `tiny/launcher.sh`의 차단 규칙 양쪽에 추가한다.

## 검증

설치할 때마다 확인합니다.

- 서명: `codesign --verify --deep --strict "/Applications/ego tiny.app"`
- 차단: `ego-tiny nodejs`로 제작사 주소에 접속해 `ERR_NAME_NOT_RESOLVED`가 나오는지, 일반 사이트는 열리는지
- 실제 연결: 실행 중인 프로세스의 연결(`lsof -nP -a -p <pid> -i`)에 제작사 서버가 없는지
- 크래시 핸들러: `chrome_crashpad_handler`의 `--url`이 `https://0.0.0.0/…`인지
- 공존: `ego-browser`는 ego lite에, `ego-tiny`는 ego tiny에 붙는지

## 하지 말 것

- `package/ego-browser/src`나 `skills/`를 ego tiny 목적으로 직접 수정하지 않는다.
- 병합 충돌을 손으로 풀어 원본과 다른 내용을 남기지 않는다.
- `ego-lite`(하이픈)를 바꾸지 않는다. 원본 저장소 이름과 URL이다.
- 앱 바이너리나 `build/`를 커밋하지 않는다.
- ego lite 앱 자체를 수정하지 않는다. ego tiny는 항상 복사본으로 만든다.
