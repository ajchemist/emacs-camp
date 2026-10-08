# 0004: 패키지 버전은 elpa-mirror 커밋 하나로 고정한다

날짜: 2026-10-09 · 상태: 채택

## 배경

지금까지는 `use-package`의 `:ensure`가 없는 패키지만 설치했고, 업그레이드는
사람이 `M-x package-upgrade-all`로 했다. 그래서 호스트마다 버전은 각 패키지를
처음 설치한 날 MELPA가 내주던 것이었다. 호스트끼리 버전이 어긋나고, 다시
배포해도 예전 상태를 재현할 수 없었다. MELPA는 새 버전을 빌드하면 옛
tarball을 지우므로, sync 도중 404가 나는 경우를 위해 index를 다시 받아 한 번
더 시도하는 우회도 있었다.

## 결정

- **잠금:** `package-archives`의 melpa를
  [d12frosted/elpa-mirror](https://github.com/d12frosted/elpa-mirror)의 특정
  커밋으로 가리킨다. 그 커밋(`init.el`의 `ecamp-elpa-snapshot`)이 패키지
  잠금이다. emacs-camp 커밋으로만 바뀌고, `flake.lock` 갱신처럼 사람이 올린다.
- **아카이브:** melpa(미러, 고정) > nongnu > gnu. melpa-stable은 뺀다. 미러의
  `stable-melpa/`는 `melpa/`와 바이트 단위로 같은 파일이다.
- **gnu, nongnu는 고정하지 않는다.** 원래 서버(elpa.gnu.org,
  elpa.nongnu.org)에서 받는다. 미러의 GNU `.sig` 상당수가 낡아서(GNU ELPA가
  다시 서명한 tarball에 예전 서명만 남아 있다) 미러에서 받으면
  `bad-signature`로 실패한다. `package-check-signature`는 낮추지 않는다.
  따라서 gnu·nongnu에서 오는 패키지(지금은 의존성뿐)는 index를 받은 시점의
  최신 버전이다. 이것이 이 잠금의 한계다.
- **URL:** GitHub raw(`raw.githubusercontent.com/…/<sha>/melpa/`)가 먼저,
  jsDelivr(`cdn.jsdelivr.net/gh/…@<sha>/melpa/`)가 대체다. 처음에는
  jsDelivr를 먼저 두려 했지만, 이 크기의 저장소에서는 캐시에 없는 파일 일부를
  403("Package size exceeded the configured limit of 50 MB")으로 거절했다
  (2026-10-09, 같은 커밋에서 raw는 모두 200). 대화형 Emacs와 복사만 한
  설치는 첫 URL만 쓰므로 믿을 수 있는 쪽이 먼저다. package.el은 아카이브마다
  URL을 하나만 받으므로 대체는 sync.el이 한다. index를 못 받거나, 받은
  뒤에도 맞추지 못한 패키지가 남으면 다음 URL로 index를 다시 받고 한 번 더
  맞춘다.
- **sync 계약:** 배포 sync는 use-package 블록(과 켠 extra, `user/*.el`)이
  요구하는 패키지와, 그 패키지들의 의존성 중 `elpa/`에 있는 것을 스냅샷과
  정확히 맞춘다. 없으면 설치하고, 버전이 다르면 다시 설치한다(업그레이드와
  다운그레이드 모두). 목록에 없는 패키지는 지우지 않는다(`user/`나
  `local.el`이 쓸 수 있다).
- **index 갱신:** package.el은 index를 아카이브 이름으로 캐시하므로(URL이
  바뀌어도 `elpa/archives/melpa/`는 그대로다) sync는 마지막으로 받은 커밋을
  `elpa/archives/ecamp-snapshot`에 적어 두고, 커밋이 바뀌었을 때만 모든
  index를 다시 받는다. 바뀐 게 없으면 네트워크를 쓰지 않는다.
- **예외:** 패키지 하나를 다른 아카이브로 보내는 `:pin`은 허용한다. `:vc`는
  쓰지 않는다. 바이트 컴파일 중에 설치하고(Nix 샌드박스는 오프라인),
  설치된 뒤에는 `:rev`가 바뀌어도 움직이지 않는다.

## 이유

1. **지금 구조를 그대로 둔다.** package.el, use-package `:ensure`,
   package-quickstart, 배포 때 sync, compile.el이 그대로다. 바뀌는 것은
   `package-archives`와 sync.el의 수십 줄이다.
2. **커밋 하나가 모든 호스트의 잠금이다.** 미러는 2016년부터 한 줄로 이어진
   이력을 다시 쓴 적이 없고, 커밋으로 받으면 MELPA가 지운 옛 tarball도
   그대로 나온다. 그래서 404 재시도 우회가 필요 없어 지웠다.
3. **다른 방법은 package.el을 바꾼다.** elpaca와 straight.el의 잠금 파일은
   패키지마다 정확하지만 package.el을 대체하고 git에서 빌드한다. sync,
   compile.el, quickstart, `elpa/` 구조를 다시 짜야 한다. emacs-overlay와
   twist는 패키지를 Nix store에서 빌드하는 다른 구조다. `:vc :rev`는 위의
   예외 항목대로 맞지 않는다. Emacs 31에도 잠금 기능은 없다.

## 결과

- 올리는 방법: `ecamp-elpa-snapshot`을 미러의 새 커밋으로 바꿔 커밋한다.
  다음 switch의 sync가 index를 다시 받고 모든 호스트를 그 스냅샷으로 맞춘다.
  되돌리면 다운그레이드된다.
- `M-x package-upgrade-all`은 melpa 패키지를 고정된 스냅샷까지만 올리고
  (그 이상은 없다), gnu·nongnu 패키지는 최신으로 올린다. 다운그레이드는
  하지 않는다. melpa를 올리는 길은 커밋을 올리는 것이다.
- 패키지 하나만 올릴 수는 없다. 커밋을 옮기면 melpa 전체가 함께 움직인다.
- 지금은 사람이 손으로 올린다. 자동화는 agent-camp의
  [ADR 0001](https://github.com/ajchemist/agent-camp/blob/main/docs/adr/0001-update-tickets-and-bump-prs.md)
  방식을 따라 만든다. 매주 도는 briefing이 미러가 움직였으면 `update` 티켓
  하나를 열거나 고쳐 쓰고, 그 티켓에 `approved` 라벨을 달면 bump workflow가
  `ecamp-elpa-snapshot` 한 줄을 바꾸는 PR을 열며, CI가 그 PR을 검증한다.
  자동 병합은 없다. 그래서 커밋은 `init.el`의 `defconst` 한 곳에만 둔다.
- 미러에 기대는 위험이 생긴다. 한 사람이 운영하는 약 18 GiB 저장소이고,
  README는 "공식 저장소가 잠시 내려갔을 때만" 쓰라고 한다.

## 다시 열 조건

- 미러가 사라지거나, 이력이 다시 쓰여 고정한 커밋이 404가 될 때. 그때는
  곧바로 melpa를 `https://melpa.org/packages/`로 돌리고(잠금 없음), fork를
  두거나 [mirror-elpa](https://github.com/d12frosted/mirror-elpa)로 직접
  호스팅할지 정한다.
- gnu·nongnu 패키지를 고정해야 할 때(미러의 `.sig`가 고쳐지거나, 서명 정책을
  다시 정해야 할 때).
- raw.githubusercontent가 이 미러를 막거나 속도를 제한할 때(jsDelivr가
  대체로 남아 있지만 위처럼 일부를 거절한다).

## 출처 (2026-10-09 확인)

- 미러: https://github.com/d12frosted/elpa-mirror (4시간마다 스냅샷 커밋, 2016년부터 이력 그대로),
  직접 호스팅용 https://github.com/d12frosted/mirror-elpa
- jsDelivr 제한: https://github.com/jsdelivr/jsdelivr README "Restrictions"
- elpaca 잠금 파일: https://github.com/progfolio/elpaca (`doc/manual.org` "Lock Files")
- straight.el `straight-freeze-versions`: https://github.com/radian-software/straight.el
- emacs-overlay: https://github.com/nix-community/emacs-overlay (MELPA를 하루 2–3번 갱신),
  nixpkgs의 `recipes-archive-melpa.json`은 3–5주마다 갱신
- twist: https://github.com/emacs-twist/twist.nix
- Emacs 31 NEWS(패키지 잠금 기능 없음): https://git.savannah.gnu.org/cgit/emacs.git/plain/etc/NEWS?h=emacs-31
