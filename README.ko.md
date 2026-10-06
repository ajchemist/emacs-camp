# emacs-camp

[![Try it on Killercoda](https://img.shields.io/badge/Try_it-Killercoda-1e90ff?logo=gnuemacs&logoColor=white)](https://killercoda.com/emacs-camp/scenario/emacs-camp)
[![CI](https://github.com/ajchemist/emacs-camp/actions/workflows/ci.yml/badge.svg)](https://github.com/ajchemist/emacs-camp/actions/workflows/ci.yml)
[![Demo image](https://github.com/ajchemist/emacs-camp/actions/workflows/demo-image.yml/badge.svg)](https://github.com/ajchemist/emacs-camp/actions/workflows/demo-image.yml)

[English](README.md) · 한국어

emacs-camp는 init을 작게 두면서도 패키지는 넉넉히 쓰는 Emacs 런타임입니다.
패키지마다 `use-package`가 알아서 처리합니다. 없으면 설치하고, 누가 실제로
부르기 전까지는 로드하지 않고, 로드되는 시점에 설정을 붙입니다. Emacs 설치는
[nix-basecamp](https://github.com/ajchemist/nix-basecamp)가 담당하므로 이
저장소는 그 위에서 돌아가는 부분만 신경 씁니다.

**브라우저에서 써 보기:** [Killercoda playground](https://killercoda.com/emacs-camp/scenario/emacs-camp)를
열면 emacs-camp가 설치된 터미널이 뜹니다(Emacs 31, 터미널 빌드). `emacs`를
입력하면 됩니다. 무료 Killercoda 계정이 필요하고 세션은 1시간입니다. 이미지는
`ghcr.io/ajchemist/emacs-camp-demo`(`demo/Dockerfile`, 매주 다시 빌드)이므로
로컬에서도 `docker run --rm -it ghcr.io/ajchemist/emacs-camp-demo`로 실행할 수
있습니다.

```
nix-basecamp   Emacs 바이너리, GUI/nox, Emacs.app, store .eln warm-up
emacs-camp     lisp/ 런타임 + 이를 배포하는 Home Manager 모듈
your flake     emacs-camp.userFiles로 넣는 자신의 파일
```

## 런타임 (`lisp/`, Nix 불필요)

- **early-init.el**: tool bar와 scroll bar를 없애고(macOS 시스템 메뉴바는
  그대로), 시작 화면을 건너뛰고, init 중에는 GC를 껐다가 끝나면 100MB로
  두고, `package-quickstart`를 켭니다.
- **init.el**: package.el과 MELPA(우선순위 melpa > melpa-stable > nongnu >
  gnu, 설치할 때 native 컴파일), `use-package-always-ensure t`와
  `use-package-always-defer t`, catppuccin latte 테마, macOS에서 Cmd는 Meta·
  Option은 Super, exec-path-from-shell(터미널이 아닌 곳에서 띄운 Emacs.app일
  때만), 완성(vertico, orderless, marginalia, consult, embark +
  embark-consult; 버퍼 안에서는 corfu + cape), git(magit + forge, 파일
  버퍼마다 diff-hl), agent-shell, 그리고 마지막으로 `custom.el`,
  `user/*.el`, `local.el`.

Nix를 아예 쓰지 않아도 됩니다. `lisp/*.el`을 `~/.config/emacs/`에 복사하면
되고, 그러면 패키지는 배포 시점이 아니라 처음 실행할 때 설치됩니다.

### 패키지

패키지 목록은 따로 없고 `use-package` 블록들이 그 역할을 합니다.

| 키워드 | 의미 |
|---|---|
| `:ensure` (기본 켜짐) | 없으면 설치; 로드하지 않음. 소스로 로드할 때만 효과가 있습니다. byte-compile하면 use-package가 이 부분을 지워 버리므로, 모듈을 쓸 때는 소스를 로드하는 배포 시점 sync가 설치를 담당합니다 |
| 없음 / `:hook` `:bind` `:mode` `:commands` | 처음 쓸 때 로드 (기본이 지연) |
| `:demand t` | 시작 때 로드; 첫 프레임에 꼭 필요한 것에만 |
| `:init` | 시작 때 실행; `setq`와 키 바인딩 정도로 제한 |
| `:config` | 패키지가 로드될 때 실행 (`with-eval-after-load`) |

`:config`에서 그 패키지의 함수를 호출한다면 블록에 `:functions 이름`(또는
`:commands`)을 붙여야 합니다. store 빌드는 패키지가 하나도 없는 상태로
init.el을 컴파일하고, "not known to be defined"도 에러로 처리하기 때문입니다.

업그레이드는 `M-x package-upgrade-all`로 합니다. 블록을 지운다고 패키지가
삭제되지는 않으니, 지우려면 `M-x package-delete`를 쓰세요.

## Home Manager 모듈

```nix
inputs.emacs-camp = {
  url = "github:ajchemist/emacs-camp";
  inputs.basecamp.follows = "basecamp";
};
# basecamp.lib.mkDarwin / mkHome으로 만든 home, basecamp.emacs.enable = true에서:
imports = [ emacs-camp.homeModules.default ];
emacs-camp.userFiles = [ ./emacs/fonts.el ];
emacs-camp.korean.enable = true;  # C-\ 한글 입력, EUC-KR 대신 UTF-8 우선, 한/영·한자 키
```

모듈이 basecamp에서 가져다 쓰는 것은 계약(`basecamp.emacs.package`,
`.warmProgram`)뿐이고, switch할 때마다 아래 작업을 합니다.

| 단계 | 어디서 | 실패하면 |
|---|---|---|
| `lisp/`와 `userFiles` byte-compile | store 빌드 (경고도 에러) | 활성화 전에 switch가 멈춤 |
| `.el` + `.elc`를 `~/.config/emacs/`에 링크 | Home Manager | 해당 없음 |
| 그 파일들 native-compile (+ warm, macOS) | 호스트, `emacsCampNativeCompile` | 경고만; Emacs가 대신 JIT |
| 빠진 패키지 설치, `elpa/` 컴파일, quickstart 갱신, `.eln` warm (macOS) | 호스트, 백그라운드 (`emacsCampPackageSync`) | `~/.cache/emacs-camp/sync.log`에 기록 |

`.eln`을 store에서 가져올 수는 없습니다. 파일 이름이 Emacs가 소스를 읽어 오는
경로(`~/.config/emacs/...`)에서 나오기 때문입니다. switch는 패키지 sync가
끝날 때까지 기다리지 않습니다(`elpa/`가 아직 없는 첫 switch만 기다려서, 끝나면 바로 완전한 상태로 뜹니다). 그동안 Emacs를 띄우면
`~/.cache/emacs-camp/sync.pid`의 프로세스가 살아 있는 한 `:ensure`를 건너뛰므로,
두 프로세스가 동시에 설치하는 일은 생기지 않습니다. switch 시점의
native-compile도 store byte-compile처럼 `:ensure`를 끈 채로 돌립니다. 끄지
않으면 컴파일 중간에 패키지가 설치되고, 그렇게 만들어진 `.eln`은 시작할 때
패키지를 전부 로드해 버립니다. sync는 `elpa/`를 코어 전부를 써서
native-compile하고(Emacs 기본은 절반이라 3코어 머신이면 작업이 하나뿐),
단계(`install`, `native-compile`, `warmed`)마다 걸린 초를 로그에 적습니다.
그다음 다른 Emacs 빌드의 `eln-cache/` 하위 디렉터리를 지웁니다(빌드마다 하나씩
쌓이지만 읽히는 건 실행 중인 빌드 것뿐이고, 옛 빌드로 돌아가면 다시 JIT할 뿐입니다).
기존 `~/.emacs`나 `~/.emacs.d`는 `~/.config/emacs`보다 우선하므로, switch가
그것을 발견할 때마다 `*.before-emacs-camp`로 옮깁니다. 이전 백업은
`*.before-emacs-camp.~N~`가 되고, 심링크는 대상은 그대로 둔 채 링크만 옮깁니다.

### macOS 한정: `.eln` warm-up

macOS는 어떤 프로세스가 Mach-O 파일을 처음 `dlopen`할 때 그 파일을 검사합니다.
파일 하나에 0.3-0.4초 정도 걸리고 한 번에 하나씩 처리하며, 결과는 파일별로
캐시됩니다. native 컴파일된 Lisp 파일(`.eln`)도 Mach-O dylib이라, 미리 데워
두지 않으면 macOS에서는 기능마다 처음 쓸 때 한 번씩 멈춥니다. Emacs에 들어
있는 `.eln` 약 3000개는 nix-basecamp가 이 비용을 미리 치르고, emacs-camp는
자기가 만든 것들을 맡습니다.

- init과 user 파일의 `.eln`: switch가 컴파일을 마치자마자.
- 패키지 `.eln`: 백그라운드 sync가 끝날 때, 그리고 Emacs가 직접 시작 시점과
  비동기 컴파일 배치가 끝날 때마다(`ecamp-eln-warm`).

Linux와 Windows는 이런 검사를 하지 않으므로 warm도 하지 않고 `eln-warm`
링크도 두지 않습니다. GitHub의 macOS runner도 검사를 건너뜁니다(CI의 "macOS
.eln vetting cost" 단계에서 두 번 다 0.000초). 반면 평범한 Apple Silicon
Mac에서는 새 `.eln`을 처음 열 때 0.4초쯤 듭니다.

### 무엇이 어디에 놓이나

switch를 마친 호스트는 다음과 같습니다(macOS 기준; Linux에는 `eln-warm` 링크가 없습니다).

```
~/.config/emacs/                     user-emacs-directory (일반 디렉터리)
├── early-init.el  -> /nix/store/…-emacs-camp-config/early-init.el
├── early-init.elc -> /nix/store/…-emacs-camp-config/early-init.elc
├── init.el        -> /nix/store/…-emacs-camp-config/init.el
├── init.elc       -> /nix/store/…-emacs-camp-config/init.elc
├── user/
│   ├── fonts.el   -> /nix/store/…   emacs-camp.userFiles 항목마다 한 쌍
│   └── fonts.elc  -> /nix/store/…
├── eln-warm       -> /nix/store/…-eln-warm/bin/eln-warm   (macOS)
├── eln-cache/31.1-<hash>/
│   ├── init-<path>-<content>.eln          switch 때 컴파일
│   └── agent-shell-<path>-<content>.eln   패키지 sync가 컴파일
├── elpa/
│   ├── agent-shell-<version>/ …           패키지 sync가 설치
│   └── archives/                          MELPA/ELPA 목록
├── package-quickstart.el(c)               패키지 autoload 전부를 한 파일에
├── custom.el                              Custom이 기록
└── local.el                               사용자 파일, 선택, 마지막에 로드

~/.cache/emacs-camp/
├── sync.log                         가장 최근 패키지 sync, 단계별 초
└── sync.pid                         sync 중에만 존재

~/.emacs.before-emacs-camp(.~N~), ~/.emacs.d.before-emacs-camp(.~N~)   나타날 때마다 옮겨 둔 것

/nix/store/…-emacs-31.1/             Emacs 본체 (nix-basecamp), 내장 .eln 포함
```

| `~/.config/emacs/` 안의 경로 | 주인 |
|---|---|
| `early-init.el(c)`, `init.el(c)`, `user/*.el(c)`, `eln-warm` (macOS) | 모듈 (store 링크) |
| `eln-cache/` | 위 파일들은 모듈, 패키지는 package.el; 다른 빌드의 하위 디렉터리는 sync가 정리 |
| `elpa/`, `package-quickstart.el` | package.el |
| `custom.el` | Custom |
| `local.el` | 사용자, 호스트별; 마지막에 로드 |

프로파일링하려면 `EMACS_USE_PACKAGE_STATS=1 emacs -q -l ~/.config/emacs/init.el`로
띄운 뒤 `M-x use-package-report`를 실행하세요. 이 설정은 init.el을 컴파일할 때
박혀 버리므로 소스를 로드해야 합니다.

use-package 정책(`always-ensure`, `always-defer`)은 `eval-and-compile`로 감싸
두었습니다. use-package는 컴파일할 때 전개되기 때문에 그냥 `setq`만 쓰면
`.elc`가 기본값 기준으로 전개되고, 결국 시작할 때 패키지를 전부 로드합니다.

## 검사

`nix flake check`는 플랫폼별로 basecamp의 Emacs와 이 모듈을 묶은 home을
빌드합니다. 이 빌드가 곧 그 Emacs로 `lisp/`를 byte-compile하는 과정입니다.

CI(`.github/workflows/ci.yml`)에는 lint 작업, ubuntu·macOS·Windows에서 모듈
없이 `lisp/`만 복사해 돌리는 런타임 작업, ubuntu·macOS에서 실제로 배포하는
작업이 있습니다. 모든 작업은 basecamp의 Emacs(이 flake의
`packages.<system>.emacs`)를 씁니다. Nix가 돌지 않는 Windows는 lint가 flake에서
읽은 것과 같은 버전의 GNU 빌드를 설치합니다. 코드(`lisp/`, `ci/`, `sync.el`,
`module.nix`, flake, workflow)가 바뀔 때와 매주 정기 실행 때만 돕니다.
`ci/smoke.el`은 Emacs와 같은 순서로 설정을 띄운 다음 아래를 확인합니다.

- init이 가벼운지: `ECAMP_INIT_BUDGET`초(기본 1.5, 측정값은 job summary에
  기록) 안에 끝나고, 시작 직후 magit, forge, transient, consult, embark,
  diff-hl, vc, org, agent-shell이 하나도 로드되어 있지 않은지. 완성
  UI(vertico, savehist, marginalia, orderless, corfu, cape)도 마찬가지로,
  첫 명령 때 `pre-command-hook`의 `ecamp-completion-ui`가 켜고 훅에서
  스스로 빠지는지.
- 처음 쓸 때 로드되는지: `C-x g`를 누르면 magit이(이어서 forge도), `M-s l`이면
  consult가, `C-.`이면 embark가(embark-consult와 함께) 올라오고, git 저장소
  안의 파일을 열면 diff-hl, corfu, cape capf가 켜지는지.
- `use-package` 패키지 하나하나가 init 뒤에 에러 없이 로드되는지. 앞서 로드된
  것의 덕을 보지 않도록 패키지마다 새 Emacs에서 잽니다. `ECAMP_LOAD_BUDGET`초
  (기본 2.0)를 넘기면 실패가 아니라 warning annotation을 남깁니다. 공유
  러너는 편차가 크기 때문입니다. job summary에는 작업마다 표가 남습니다. init 시간,
  시작 시 로드된 feature 수와 GC 횟수, 그리고 패키지별로 언제 로드되는지,
  첫 로딩 시간, 함께 딸려오는 feature 수입니다.

runtime 작업은 `elpa/`를 OS, 패키지 목록, ISO 주차를 키로 캐시합니다. 매주
예약 실행은 캐시 없이 시작하므로 MELPA 쪽 변화도 놓치지 않습니다. Windows
러너에서 PATH에 잡히는 `gpg`는 Git for Windows에 딸린 MSYS 빌드인데, 이것이
GNU/NonGNU ELPA 아카이브(`compat`이 여기 있음)마다 `bad-signature`를
보고합니다. 그래서 CI는 그 플랫폼에서 서명 검사를 끕니다. Windows
데스크톱에서는 대신 네이티브 gpg(Gpg4win)를 설치하세요.

agents 잡은 ubuntu와 macOS에서 emacs-camp를
[agent-camp](https://github.com/ajchemist/agent-camp)와 함께 배포합니다. 배포 대상은
claude, codex, pi, goose와 각각의 ACP 어댑터(`claude-agent-acp`, `codex-acp`,
`pi-acp`, `goose acp`)입니다. 그다음 `ci/acp-handshake.el`이 agent-shell로 각
에이전트를 자체 설정대로 시작하고, ACP initialize 교환이 끝날 때까지 기다립니다.
initialize는 인증보다 먼저 일어나므로 계정이 필요 없습니다. emacs-camp 모듈은
agent-camp에 의존하지 않으며, flake input은 CI에서만 씁니다. 자기 머신에 어댑터를
설치하려면 agent-camp 모듈을 import하고 `<agent>-acp`에 yes로 답하거나, 원하는
방법으로 직접 설치하면 됩니다.
