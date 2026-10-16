# 0007: nixpkgs·Home Manager·nix-darwin은 upstream에서 직접 받는다

날짜: 2026-10-16 · 상태: 채택 · [0006](0006-emacs-ownership.md)의 "basecamp는 input으로 남습니다" 항목을 대체

## 배경

0006 이후 emacs-camp는 Emacs를 직접 빌드하지만, nixpkgs와 테스트용 빌더
(`mkHome`/`mkDarwin`)를 얻으려고 basecamp를 input으로 두었습니다. 그래서
fixture에 Homebrew와 Karabiner 설정이 딸려 오고, basecamp의 lock이 바뀌어야
Emacs의 nixpkgs가 바뀌었습니다. basecamp 없이 emacs-camp만 쓰는 사람도
basecamp를 받아야 했습니다. agent-camp도 같은 구조였습니다.

## 결정

- `nixpkgs`, `home-manager`, `nix-darwin`을 basecamp와 같은 URL로 직접 받습니다.
  basecamp는 input이 아닙니다.
- fixture, 샌드박스, CI 배포는 `ci/fixture.nix`에서 upstream 빌더
  (`home-manager.lib.homeManagerConfiguration`, `nix-darwin.lib.darwinSystem`)를
  그대로 씁니다. 이 빌더는 flake 출력으로 내놓지 않습니다.
- CI 전용 input인 agent-camp도 같은 구조이고, 그 세 input을 이 flake의 것에 묶습니다.
- 하나의 pin은 최상위 flake가 정합니다. downstream은 세 input을 자기 것에
  `follows`로 묶습니다. basecamp를 쓰는 downstream이면
  `inputs.nixpkgs.follows = "basecamp/nixpkgs"`처럼 basecamp의 것에 묶습니다.

## 결과

- 단독으로 쓰면 이 저장소의 lock이 Emacs의 nixpkgs를 정합니다. downstream이
  `follows`로 묶으면 downstream의 lock이 정합니다.
- downstream은 camp마다 `follows` 세 줄을 씁니다. 빠뜨리면 lock에
  `home-manager_2` 같은 사본이 생깁니다.
- lock 갱신은 이 저장소에서 따로 합니다(`nix flake update`).
