# emacs-camp

[![Try it on Killercoda](https://img.shields.io/badge/Try_it-Killercoda-1e90ff?logo=gnuemacs&logoColor=white)](https://killercoda.com/emacs-camp/scenario/emacs-camp)
[![CI](https://github.com/ajchemist/emacs-camp/actions/workflows/ci.yml/badge.svg)](https://github.com/ajchemist/emacs-camp/actions/workflows/ci.yml)
[![Image](https://github.com/ajchemist/emacs-camp/actions/workflows/image.yml/badge.svg)](https://github.com/ajchemist/emacs-camp/actions/workflows/image.yml)

[English](README.md) · 한국어

emacs-camp는 init은 작게 두고 패키지는 넉넉히 갖춘 Emacs 런타임입니다.
패키지는 `use-package`가 관리합니다. 없으면 설치하고, 무언가 호출하기
전까지는 로드하지 않으며, 로드될 때 설정을 적용합니다. Emacs 자체는
[nix-basecamp](https://github.com/ajchemist/nix-basecamp)가 제공하고, 이
저장소는 그 위에서 돌아가는 부분만 다룹니다.

브라우저에서 써 보려면
[Killercoda playground](https://killercoda.com/emacs-camp/scenario/emacs-camp)를
열고 터미널에 `emacs`를 입력하세요. 같은 이미지를 로컬에서 실행하려면
`docker run --rm -it ghcr.io/ajchemist/emacs-camp`를 쓰면 됩니다. 자세한
내용은 [데모 이미지 절](#데모-이미지와-killercoda)에 있습니다.

```
nix-basecamp   Emacs 바이너리, GUI/nox, Emacs.app, store .eln warm-up
emacs-camp     lisp/ 런타임 + 이를 배포하는 Home Manager 모듈
your flake     emacs-camp.userFiles로 넣는 자신의 파일
```

## 런타임 (`lisp/`, Nix 불필요)

- **early-init.el**은 tool bar와 scroll bar를 없애고(macOS의 시스템 메뉴바는
  그대로 둡니다), 시작 화면을 건너뜁니다. init 동안 GC를 껐다가 끝나면
  100MB로 맞추고, `package-quickstart`를 켭니다.
- **init.el**은 package.el과 MELPA(우선순위 melpa > melpa-stable > nongnu >
  gnu, 설치할 때 native 컴파일), `use-package-always-ensure t`,
  `use-package-always-defer t`를 설정합니다. 그다음 아래를 구성합니다.
  - catppuccin latte 테마
  - macOS에서 Cmd를 Meta로, Option을 Super로. 터미널이 아닌 곳에서 띄운
    Emacs.app에는 exec-path-from-shell
  - 완성: vertico, savehist, orderless, marginalia, consult, embark,
    embark-consult. 버퍼 안에서는 corfu와 cape
  - dirvish. dired가 처음 로드될 때 dired를 대신합니다
  - Lisp 버퍼의 paredit, elisp eval 결과를 인라인으로 보여주는 eros
  - git: magit, forge, 파일 버퍼마다 diff-hl
  - agent-shell

  마지막으로 `custom.el`, `ecamp-extras`에 지정한 extras, `user/*.el`,
  `local.el`을 이 순서로 로드합니다.

Nix 없이 `lisp/*.el`을 `~/.config/emacs/`에 복사해서 써도 됩니다. 그러면
패키지는 배포할 때가 아니라 처음 실행할 때 설치됩니다. `user/`에 직접 넣은
파일을 컴파일하려면 `bin/emacs-camp-compile-user`를 실행하세요. 그 자리에서
byte 컴파일과 native 컴파일을 하고, 모듈이 관리하는 심볼릭 링크는
건너뜁니다.

### 패키지

패키지 목록은 `use-package` 블록들 그 자체입니다.

| 키워드 | 의미 |
|---|---|
| `:ensure` (기본 켜짐) | 패키지가 없으면 설치하고, 로드는 하지 않습니다. Emacs가 소스 파일을 로드할 때만 동작합니다. byte 컴파일할 때 use-package가 이 키워드를 빼 버리기 때문입니다. 모듈에서는 패키지 sync가 소스를 로드해서 설치를 맡습니다. |
| 없음 / `:hook` `:bind` `:mode` `:commands` | 처음 쓸 때 로드 (기본이 지연 로드) |
| `:demand t` | 시작할 때 로드. 첫 프레임에 꼭 필요한 것에만 씁니다 |
| `:init` | 시작할 때 실행. `setq`와 키 바인딩 정도로 제한합니다 |
| `:config` | 패키지가 로드될 때 실행 (`with-eval-after-load`) |

블록의 `:config`가 그 패키지의 함수를 호출하면 `:functions 이름`(또는
`:commands`)을 붙이세요. store 빌드는 패키지가 하나도 없는 상태로 init.el을
컴파일하고, "not known to be defined"를 에러로 처리합니다.

업그레이드는 `M-x package-upgrade-all`로 합니다. 블록을 지워도 패키지는
삭제되지 않습니다. 삭제하려면 `M-x package-delete`를 쓰세요.

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
emacs-camp.extras = [ "10-prog" ];  # 코드 버퍼와 ielm에 무지개 괄호, eval 깜박임
```

`extras/*.el`은 모두 `~/.config/emacs/extras/`에 배포되지만, `ecamp-extras`에
이름이 있어야만 로드됩니다. `emacs-camp.extras`와 `korean.enable` 같은 옵션은 그 기본값만 정합니다
(`extras-default.el`에 기록). 나중에 켜고 끄려면
`M-x customize-variable RET ecamp-extras`를 쓰면 되고, `custom.el`에 저장됩니다.

모듈이 basecamp에서 쓰는 것은 계약(`basecamp.emacs.package`,
`.warmProgram`)뿐입니다. switch할 때마다 아래 작업을 합니다.

| 단계 | 어디서 | 실패하면 |
|---|---|---|
| `lisp/`와 `userFiles` byte-compile | store 빌드 (경고도 에러) | 활성화 전에 switch가 멈춤 |
| `.el` + `.elc`를 `~/.config/emacs/`에 링크 | Home Manager | 해당 없음 |
| 그 파일들 native-compile (+ warm, macOS) | 호스트, `emacsCampNativeCompile` | 경고만 남고 Emacs가 대신 JIT |
| 빠진 패키지 설치, `elpa/` 컴파일, quickstart 갱신, `.eln` warm (macOS) | 호스트, 백그라운드. 첫 switch는 기다림 (`emacsCampPackageSync`) | `~/.cache/emacs-camp/sync.log`에 기록 |

store는 `.eln` 파일을 제공할 수 없습니다. 파일 이름이 Emacs가 소스를 읽는
경로에서 정해지는데, 그 경로가 `~/.config/emacs/...`이기 때문입니다.

switch는 패키지 sync를 기다리지 않고 끝납니다. 예외는 `elpa/`가 아직 없는 첫
switch입니다. 이때는 기다리므로, Emacs를 처음 띄울 때 패키지가 전부 갖춰져
있습니다.

패키지 sync가 도는 동안 Emacs를 띄우면, `~/.cache/emacs-camp/sync.pid`가 살아
있는 프로세스를 가리키는 한 Emacs는 `:ensure`를 건너뜁니다. 그래서 패키지는
한 번에 한 프로세스만 설치합니다.

switch 때의 native 컴파일도 store byte 컴파일처럼 `:ensure`를 끄고 돌립니다
(둘 다 `compile.el`을 먼저 로드합니다). 끄지 않으면 컴파일 도중에 패키지가
설치되고, 그렇게 만든 `.eln`은 시작할 때 패키지를 전부 로드합니다.

패키지 sync는 `elpa/`를 모든 코어로 native 컴파일합니다. Emacs 기본값은 코어
절반이라, 3코어 머신에서는 작업이 하나뿐입니다. sync는 단계(`install`,
`native-compile`, `warmed`)마다 걸린 초를 로그에 남깁니다. 그다음 다른 Emacs
빌드의 `eln-cache/` 하위 디렉터리를 지웁니다. 하위 디렉터리는 빌드마다 하나씩
생기고, Emacs는 실행 중인 빌드의 것만 읽습니다. 예전 빌드로 돌아가면 다시
JIT합니다.

기존 `~/.emacs`나 `~/.emacs.d`가 있으면 `~/.config/emacs`보다 우선합니다.
그래서 switch는 이를 발견할 때마다 `*.before-emacs-camp`로 이름을 바꿉니다.
이전 백업은 `*.before-emacs-camp.~N~`가 됩니다. 심볼릭 링크는 링크만 옮기고
대상은 그대로 둡니다.

### macOS의 `.eln` warm-up

macOS는 프로세스가 Mach-O 파일을 처음 `dlopen`할 때 그 파일을 검사합니다.
파일 하나에 0.3~0.4초가 걸리고, 한 번에 하나씩 처리하며, 결과는 파일별로
캐시합니다. native 컴파일된 Lisp 파일(`.eln`)도 Mach-O dylib입니다. 그래서
warm-up이 없으면 macOS에서는 기능마다 처음 쓸 때 한 번씩 멈춥니다.
nix-basecamp는 Emacs에 내장된 `.eln` 약 3000개의 검사를 미리 돌려 두고,
emacs-camp는 자기가 만든 것을 맡습니다.

- init과 user 파일의 `.eln`: switch가 컴파일을 마치면 바로
- 패키지 `.eln`: 패키지 sync가 끝날 때. 그리고 Emacs가 직접, 시작할 때와
  비동기 컴파일 배치가 끝날 때마다 (`ecamp-eln-warm`)

Linux와 Windows는 이 검사를 하지 않으므로 warm도 `eln-warm` 링크도 없습니다.
GitHub의 macOS runner도 검사를 건너뜁니다(CI의 "macOS .eln vetting cost"
단계에서 두 번 모두 0.000초). 일반 Apple Silicon Mac은 새 `.eln`을 처음 열 때
0.4초쯤 씁니다.

### 무엇이 어디에 놓이나

switch를 마친 호스트는 다음과 같습니다(macOS 기준. Linux에는 `eln-warm`
링크와 `Applications/`가 없습니다).

```
~/.config/emacs/                     user-emacs-directory (일반 디렉터리)
├── early-init.el  -> /nix/store/…-emacs-camp-config/early-init.el
├── early-init.elc -> /nix/store/…-emacs-camp-config/early-init.elc
├── init.el        -> /nix/store/…-emacs-camp-config/init.el
├── init.elc       -> /nix/store/…-emacs-camp-config/init.elc
├── extras-default.el(c) -> /nix/store/…   ecamp-extras의 기본값
├── extras/
│   └── 00-korean.el(c) -> /nix/store/…    모든 extra, 선택된 것만 로드
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

| `~/.config/emacs/` 안의 경로 | 관리 주체 |
|---|---|
| `early-init.el(c)`, `init.el(c)`, `extras-default.el(c)`, `extras/*.el(c)`, `user/*.el(c)`, `eln-warm` (macOS) | 모듈 (store 링크) |
| `eln-cache/` | 위 파일들은 모듈, 패키지는 package.el. 다른 빌드의 하위 디렉터리는 패키지 sync가 정리 |
| `elpa/`, `package-quickstart.el` | package.el |
| `custom.el` | Custom |
| `local.el` | 사용자, 호스트별. 마지막에 로드 |

프로파일링하려면 `EMACS_USE_PACKAGE_STATS=1 emacs -q -l ~/.config/emacs/init.el`로
띄운 뒤 `M-x use-package-report`를 실행하세요. 이 설정은 init.el을 컴파일할 때
고정되므로 소스를 로드해야 합니다.

use-package 정책(`always-ensure`, `always-defer`)은 `eval-and-compile`로
감싸 두었습니다. use-package는 컴파일할 때 폼을 전개합니다. 그냥 `setq`만
쓰면 컴파일러가 기본값으로 `.elc`를 전개하고, 그 `.elc`는 시작할 때 패키지를
전부 로드합니다.

## 데모 이미지와 Killercoda

`Dockerfile`은 `ghcr.io/ajchemist/emacs-camp`를 빌드합니다.

- 배포 경로는 하나입니다. Nix 단계에서 flake의
  `homeConfigurations.sandbox-<arch>-linux`(basecamp의 Emacs + 이 모듈)를
  빌드하고 Home Manager activation을 실행합니다. 링크, `extras-default.el`,
  컴파일, 패키지 sync가 모두 모듈 그대로입니다. 결과인 홈과 그 `/nix/store`
  closure만 `scratch` 위에 담습니다. 배포판도 Nix도 없습니다(압축 약 170 MB).
- 샌드박스 경량화는 별도 레시피가 아니라 옵션으로 합니다.
  `basecamp.emacs.nativeComp = false`로 gcc와 libgccjit을, `systemctl`을 이름만
  두어 systemd를 빼고, git은 `gitMinimal`을 쓰며, extra는 하나도
  켜지 않습니다(`M-x customize-variable RET ecamp-extras`로 켭니다).
- GitHub Actions(`.github/workflows/image.yml`)가 main에서 `latest`를
  빌드합니다. `lisp/`, `extras/`, `sync.el`, `compile.el`, `module.nix`, `flake.*`, `Dockerfile`이
  바뀌는 push마다 돌고, MELPA 갱신을 받으려고 매일 18:00 UTC(03:00 KST)에도
  돕니다. 새 빌드가 시작되면 돌고 있던 빌드는 취소됩니다.

Killercoda 시나리오는 이 이미지를 실행합니다(`docker run -it ... bash`).
시나리오 파일은 다른 파일이 없는 `killercoda` 브랜치에 있고, Killercoda는 이
브랜치를 동기화합니다. main은 원본으로 쓸 수 없습니다. main의 `.claude/skills`
심볼릭 링크가 커밋되지 않은 `.agents/skills`를 가리키는데, 이 깨진 링크가
Killercoda 동기화를 멈추게 합니다.

무료 Killercoda 계정은 세션이 1시간이고 하루 사용 제한은 없습니다. 방문자는
무료 Killercoda 계정으로 로그인해야 합니다.

## 검사

`nix flake check`는 플랫폼마다 basecamp의 Emacs와 이 모듈로 home을 빌드하고,
그 빌드가 같은 Emacs로 `lisp/`를 byte 컴파일합니다.

CI(`.github/workflows/ci.yml`)에는 세 종류의 작업이 있습니다.

- lint 작업
- ubuntu, macOS, Windows에서 모듈 없이 `lisp/`만 복사해 돌리는 런타임 작업
- ubuntu와 macOS에서 실제로 배포하는 작업

모든 작업은 basecamp의 Emacs(이 flake의 `packages.<system>.emacs`)를 씁니다.
Nix가 돌지 않는 Windows는 같은 버전의 GNU 빌드를 설치하고, 그 버전은 lint
작업이 flake에서 읽어 옵니다. CI는 코드(`lisp/`, `ci/`, `sync.el`,
`module.nix`, flake, workflow)가 바뀔 때와 매주 정기 실행 때만 돕니다.
`ci/smoke.el`은 Emacs와 같은 방식으로 설정을 띄운 뒤 아래를 확인합니다.

- init이 가벼운지. `ECAMP_INIT_BUDGET`초(기본 1.5, 측정값은 job summary에
  기록) 안에 끝나야 하고, 시작 직후 magit, forge, transient, consult, embark,
  diff-hl, vc, org, agent-shell이 모두 로드되지 않은 상태여야 합니다. 완성
  UI(vertico, savehist, marginalia, orderless, corfu, cape)도 마찬가지입니다.
  `ecamp-completion-ui`가 첫 명령 때 `pre-command-hook`에서 이를 켜고, 그다음
  훅에서 자신을 뺍니다.
- 처음 쓸 때 로드되는지. `C-x g`는 magit을(이어서 forge도), `M-s l`은
  consult를, `C-.`는 embark를(embark-consult와 함께) 로드합니다. git 저장소
  안의 파일을 열면 diff-hl, corfu, cape capf가 켜집니다.
- `use-package` 패키지가 모두 init 뒤에 에러 없이 로드되는지. 앞서 로드된
  것 때문에 측정값이 줄지 않도록 패키지마다 새 Emacs에서 시간을 잽니다.
  `ECAMP_LOAD_BUDGET`초(기본 2.0)를 넘기면 실패 대신 warning annotation을
  남깁니다. 공유 러너는 편차가 크기 때문입니다. job summary에는 작업마다 표가
  남습니다. init 시간, 시작 시 feature 수와 GC 횟수, 그리고 패키지별로 로드
  시점, 첫 로드 시간, 함께 끌어오는 feature 수입니다.

런타임 작업은 `elpa/`를 OS, 패키지 목록, ISO 주차를 키로 캐시합니다. 매주
정기 실행은 빈 캐시에서 시작하므로 MELPA 쪽 변화도 잡아냅니다.

Windows 러너에서 PATH에 잡히는 `gpg`는 Git for Windows에 딸린 MSYS 빌드입니다.
이 gpg는 GNU/NonGNU ELPA 아카이브마다 `bad-signature`를 보고하고, `compat`이
그 아카이브에서 옵니다. 그래서 CI는 이 플랫폼에서 서명 검사를 끕니다. Windows
데스크톱에서는 네이티브 gpg(Gpg4win)를 설치하세요.

agents 작업은 ubuntu와 macOS에서 emacs-camp를
[agent-camp](https://github.com/ajchemist/agent-camp)와 함께 배포합니다. claude,
codex, pi, goose와 각각의 ACP 어댑터(`claude-agent-acp`, `codex-acp`,
`pi-acp`, `goose acp`)가 함께 설치됩니다. 그다음 `ci/acp-handshake.el`이
agent-shell로 에이전트마다 자체 설정으로 시작하고, ACP initialize 교환이 끝날
때까지 기다립니다. initialize는 인증보다 먼저 일어나므로 계정이 필요
없습니다. emacs-camp 모듈은 agent-camp에 의존하지 않고, flake input은 CI에서만
씁니다. 자기 머신에 어댑터를 설치하려면 agent-camp 모듈을 import해서
`<agent>-acp`에 yes로 답하거나, 원하는 방법으로 직접 설치하세요.
