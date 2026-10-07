# 0003: extras 기본값은 `emacs-camp.extras` 하나로 정한다

날짜: 2026-10-07 · 상태: 채택 · [0001](0001-extras.md)의 "기본값" 항목을 구체화

## 배경

`emacs-camp.korean.enable`은 `emacs-camp.extras`에 `"00-korean"`을 더하는 것 말고는
하는 일이 없었다. 같은 기본값을 두 경로로 정할 수 있었고(`korean.enable = false`여도
`extras`에 있으면 켜진다), 다른 extra에는 없는 예외였으며, 문서마다 두 경로를 함께
설명해야 했다.

## 결정

- 배포 기본값은 `emacs-camp.extras`(extra 이름 목록)로만 정한다. extra마다 전용
  `*.enable` 옵션을 만들지 않는다.
- 이 목록은 customize의 `ecamp-extras`와 같은 이름을 쓴다.
- `emacs-camp.korean.enable`은 제거했다. `mkRemovedOptionModule`이 남아 있어
  쓰던 설정은 평가 오류와 함께 `emacs-camp.extras = [ "00-korean" ]`로 바꾸라는 안내를 받는다.

## 결과

- 이름에 로드 순서용 숫자 접두사(`00-`)가 드러난다. 대신 Nix와 customize가 같은
  어휘를 쓴다.
- 다운스트림은 `korean.enable = true`를 `extras`에 `"00-korean"`을 넣는 것으로 바꿔야 한다.
