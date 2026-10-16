# 0006: Emacs 빌드와 설치도 emacs-camp가 맡는다

날짜: 2026-10-16 · 상태: 채택 · nix-basecamp의 [ADR 0001](https://github.com/ajchemist/nix-basecamp/blob/main/docs/adr/0001-emacs-install-layers.md)이 basecamp에 둔 설치 층을 이 저장소로 옮김(basecamp ADR 0002) · "basecamp는 input으로 남습니다" 항목은 [0007](0007-upstream-inputs.md)로 대체

## 배경

지금까지 nix-basecamp가 Emacs 바이너리(major 고정, GUI/nox, native 컴파일),
Emacs.app 정리, 내장 `.eln` warm-up을 맡았고, emacs-camp는 그 계약
(`basecamp.emacs.package`, `.warmProgram`) 위에서 런타임만 다뤘습니다. 에디터
하나에 flake가 두 개 필요했고, 소스 패치나 빌드 옵션처럼 Emacs 자체를 바꾸는
일이 두 저장소의 릴리스를 묶었습니다.

## 결정

- 소스 선택(major 31, `lib/emacs.nix`), 빌드 옵션, 소스 패치, 보조 프로그램
  (`eln-warm`, Emacs.app 정리), 설치, 런타임 설정을 이 flake가 모두 맡습니다.
- 설치는 OS마다 한 길입니다. macOS는 nix-darwin 모듈(`darwinModules.default`)이
  시스템 패키지로 설치하고 `/Applications/Nix Apps/Emacs.app`, 다른 Emacs.app
  정리, 내장 `.eln` warm-up을 맡습니다. Linux와 nix-darwin 없는 macOS는 Home
  Manager 모듈이 설치합니다. nix-darwin 아래에서 Home Manager 쪽 빌드 옵션은
  시스템 값을 읽기 전용으로 따르고, 설정은 설치된 바로 그 패키지로 컴파일합니다.
- 설치만 필요하면 `homeModules.emacs`를 import합니다.
- 소스 패치는 nixpkgs의 patches 뒤에 붙어 컴파일 전에 적용됩니다. package.el
  패키지의 런타임 보정과는 별개입니다([소스 패치](../source-patches.md)).
- basecamp는 input으로 남습니다. fixture, CI, 샌드박스가 basecamp의 nixpkgs와
  `mkHome`/`mkDarwin` 빌더를 씁니다. 모듈은 basecamp에 의존하지 않고, basecamp에는
  Emacs가 없습니다. 빌더를 이 저장소에 따로 두지 않습니다. 그러면 downstream이
  home-manager와 nix-darwin을 두 번 lock하게 됩니다.
- 호환 별칭은 두지 않습니다. `basecamp.emacs.*`를 쓰던 downstream은
  `emacs-camp.*`와 `darwinModules.default`로 옮깁니다.

## 결과

- Emacs 버전은 basecamp의 nixpkgs lock이 정합니다. downstream이
  `inputs.basecamp.follows`로 묶으면 downstream의 lock입니다. lock이 같으면
  store 경로도 이전과 같아서 다시 빌드하지 않고 warm-up 마커도 그대로 유효합니다.
- `emacs-camp.enable` 하나가 설치와 런타임 배포를 함께 켭니다. 설치만 하고
  런타임은 빼려면 `homeModules.default` 대신 `homeModules.emacs`를 import합니다.
- 이 flake는 Emacs가 남아 있는 basecamp로도 평가되므로 먼저 낼 수 있습니다.
  basecamp가 Emacs를 뺀 뒤 downstream이 두 lock을 함께 갱신합니다.
