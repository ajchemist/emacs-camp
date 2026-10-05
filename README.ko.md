# emacs-camp

[English](README.md) · 한국어

init은 가볍게 유지하면서 패키지 확장성은 포기하지 않는 Emacs 런타임입니다.
`use-package`가 빠진 패키지를 설치하고, 실제로 쓰기 전까지는 아무것도 로드하지
않으며, 패키지가 로드되는 순간 그 패키지의 설정을 적용합니다. Emacs 자체의
설치는 [nix-basecamp](https://github.com/ajchemist/nix-basecamp)가 맡고,
emacs-camp는 그 안에서 도는 것만 다룹니다.

```
nix-basecamp   Emacs 바이너리, GUI/nox, Emacs.app, store .eln warm-up
emacs-camp     lisp/ 런타임 + 이를 배포하는 Home Manager 모듈
your flake     emacs-camp.userFiles로 넣는 자신의 파일
```

## 런타임 (`lisp/`, Nix 불필요)

- **early-init.el**: tool bar·scroll bar 없음(macOS는 시스템 메뉴바 유지),
  시작 화면 없음, init 동안 GC 끔 → 이후 100MB, `package-quickstart`.
- **init.el**: package.el + MELPA(melpa > melpa-stable > nongnu > gnu, 설치 시
  native 컴파일), `use-package-always-ensure t` + `use-package-always-defer t`,
  catppuccin latte, macOS Cmd = Meta·Option = Super,
  exec-path-from-shell(터미널 밖에서 띄운 Emacs.app만), agent-shell, 이어서 `custom.el`,
  `user/*.el`, `local.el`.

Nix 없이도 `lisp/*.el`을 `~/.config/emacs/`에 복사하면 동작합니다. 이 경우
패키지는 배포 때가 아니라 첫 시작 때 설치됩니다.

### 패키지

`use-package` 블록이 곧 패키지 목록입니다.

| 키워드 | 의미 |
|---|---|
| `:ensure` (기본 켜짐) | 없으면 설치; 로드하지 않음. 파일을 원본으로 로드할 때만 동작합니다. byte-compile하면 use-package가 이를 빼 버리므로, 모듈 환경에서는 원본을 로드하는 배포 시점 sync가 설치를 맡습니다 |
| 없음 / `:hook` `:bind` `:mode` `:commands` | 처음 쓸 때 로드 (기본이 지연) |
| `:demand t` | 시작 때 로드; 첫 프레임에 필요한 것만 |
| `:init` | 시작 때 실행; `setq`와 키 바인딩 정도만 |
| `:config` | 패키지가 로드될 때 실행 (`with-eval-after-load`) |

`:config`에서 패키지 함수를 부르는 블록은 `:functions 이름`(또는 `:commands`)이
필요합니다. store 빌드는 패키지 없이 init.el을 컴파일하며 "not known to be
defined" 경고도 에러로 취급하기 때문입니다.

업그레이드는 `M-x package-upgrade-all`. 블록을 지워도 패키지는 남습니다
(`M-x package-delete`).

## Home Manager 모듈

```nix
inputs.emacs-camp = {
  url = "github:ajchemist/emacs-camp";
  inputs.basecamp.follows = "basecamp";
};
# basecamp.lib.mkDarwin / mkHome으로 만든 home, basecamp.emacs.enable = true에서:
imports = [ emacs-camp.homeModules.default ];
emacs-camp.userFiles = [ ./emacs/fonts.el ];
```

basecamp의 계약(`basecamp.emacs.package`, `.warmProgram`)만 읽고, switch마다
다음을 합니다.

| 단계 | 어디서 | 실패하면 |
|---|---|---|
| `lisp/`와 `userFiles` byte-compile | store 빌드 (경고도 에러) | 활성화 전에 switch가 멈춤 |
| `.el` + `.elc`를 `~/.config/emacs/`에 링크 | Home Manager | 해당 없음 |
| 그 파일들 native-compile (+ warm, macOS) | 호스트, `emacsCampNativeCompile` | 경고만; Emacs가 대신 JIT |
| 빠진 패키지 설치, `elpa/` 컴파일, quickstart 갱신, `.eln` warm (macOS) | 호스트, 백그라운드 (`emacsCampPackageSync`) | `~/.cache/emacs-camp/sync.log`에 기록 |

`.eln`은 store에서 만들 수 없습니다. 파일 이름이 Emacs가 소스를 읽는 경로
(`~/.config/emacs/...`)로 정해지기 때문입니다. switch는 패키지 sync를 기다리지
않습니다. 그 사이 시작한 Emacs는 `:ensure`를 건너뛰므로
(`~/.cache/emacs-camp/sync.pid`가 살아 있는 동안) 두 프로세스가 동시에 설치하는
일은 없습니다. 기존 `~/.emacs`나 `~/.emacs.d`는 `~/.config/emacs`를 가리므로 한
번 `*.before-emacs-camp`로 옮깁니다.

### macOS 한정: `.eln` warm-up

macOS는 프로세스가 Mach-O 파일을 처음 `dlopen`할 때마다 그 파일을 검사합니다
(파일당 약 0.3-0.4초, 직렬, 이후 파일별 캐시). native 컴파일된 Lisp(`.eln`)는
Mach-O dylib이므로, macOS에서는 각 기능을 처음 쓸 때 한 번씩 멈칫합니다.
nix-basecamp가 Emacs 내장 `.eln` 약 3000개를 미리 치르고, emacs-camp는 자신이
만드는 것을 치릅니다.

- init과 user 파일의 `.eln`: switch 때 컴파일 직후.
- 패키지 `.eln`: 백그라운드 sync 끝에서, 그리고 Emacs 자신이 시작할 때와 비동기
  컴파일 배치가 끝날 때(`ecamp-eln-warm`).

Linux와 Windows에는 이런 검사가 없어서 아무것도 warm하지 않고 `eln-warm` 링크도
만들지 않습니다. CI가 GitHub macOS runner에서 그 비용을 측정합니다(job
`deploy`, 단계 "macOS .eln vetting cost").

### 무엇이 어디에 놓이나

switch 뒤 호스트는 이렇게 생깁니다(macOS 기준; Linux에는 `eln-warm` 링크가 없습니다).

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
├── package-quickstart.el(c)               모든 패키지 autoload를 한 파일로
├── custom.el                              Custom이 쓰는 곳
└── local.el                               사용자 파일, 선택, 마지막에 로드

~/.cache/emacs-camp/
├── sync.log                         마지막 패키지 sync ("done", "warmed")
└── sync.pid                         sync가 도는 동안만

~/.emacs.before-emacs-camp, ~/.emacs.d.before-emacs-camp   있었다면 한 번 옮겨 둔 것

/nix/store/…-emacs-31.1/             Emacs 본체 (nix-basecamp), 내장 .eln 포함
```

| `~/.config/emacs/` 안의 경로 | 주인 |
|---|---|
| `early-init.el(c)`, `init.el(c)`, `user/*.el(c)`, `eln-warm` (macOS) | 모듈 (store 링크) |
| `eln-cache/` | 위 파일들은 모듈, 패키지는 package.el |
| `elpa/`, `package-quickstart.el` | package.el |
| `custom.el` | Custom |
| `local.el` | 사용자, 호스트별; 마지막에 로드 |

프로파일링: `EMACS_USE_PACKAGE_STATS=1 emacs -q -l ~/.config/emacs/init.el` 후
`M-x use-package-report`(이 설정은 init.el 컴파일 때 고정되므로 원본을 로드해야 합니다).

use-package 정책(`always-ensure`, `always-defer`)은 `eval-and-compile` 안에 있습니다.
use-package는 컴파일 시점에 전개되므로, 단순 `setq`로 두면 `.elc`가 기본값으로
전개되어 시작할 때 모든 패키지를 로드하게 됩니다.

## 검사

`nix flake check`는 플랫폼마다 basecamp의 Emacs와 이 모듈로 home을 하나씩
빌드하며, 그 과정에서 `lisp/`를 그 Emacs로 byte-compile합니다.
