# 0001: extras — 늘 배포하고, 켤지는 사용자가 정한다

날짜: 2026-10-06 · 상태: 채택

## extras에 넣는 것

`extras/`는 emacs-camp가 **예시이자 권장 패턴으로 제공하는 취향 묶음**이다.
(예: `00-korean.el` — 한글 입력, UTF-8 우선, 한/영·한자 키)

- 넣는 기준: 누구 환경에 깔려도 **보안·프라이버시 문제가 없는 것**만.
  계정, 토큰, 호스트 이름, 개인 경로, 외부로 데이터를 보내는 설정은 넣지 않는다.
- 개인 설정은 extras가 아니라 각자의 별도 저장소(downstream)에
  두고 `emacs-camp.userFiles` → `user/*.el`로 얹는다. extras는 그런 저장소와
  무관하게 camp 안에서 완결된다.

## 배포와 로드

- 배포: 모든 `extras/*.el`은 opt-in 여부와 상관없이 항상
  `~/.config/emacs/extras/`에 배포된다 (Nix 모듈, Docker 이미지 모두).
- 로드: `ecamp-extras`(defcustom)에 이름이 있는 것만 로드한다.
  순서는 `custom.el` → extras → `user/*.el` → `local.el`.
- 기본값: Nix 옵션(예: `emacs-camp.korean.enable`)은 `extras-default.el`에
  기본값만 적는다. Docker 이미지는 기본값이 없으므로 아무것도 로드하지 않는다.
- 나중에 바꾸기: `M-x customize-variable RET ecamp-extras`.
  `custom.el`에 저장되고 배포 기본값보다 우선한다.

## 제약: extra는 새 패키지를 요구하지 않는다

`sync.el`은 켜진 extras만 소스로 읽어 `:ensure` 패키지를 설치한다. 배포 뒤에
켠 extra의 패키지는 다음 sync까지 설치되지 않는다. 그래서 **extra는
`:ensure`로 패키지를 새로 끌어오지 않는다.** 내장 기능이나 `init.el`이 이미
설치하는 패키지만 쓴다. 패키지가 필요한 취향은 `init.el` 본체에 넣을지부터
따진다.
