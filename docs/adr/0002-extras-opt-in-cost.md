# 0002: extras — 켠 extra만 패키지를 설치하고 컴파일한다

날짜: 2026-10-07 · 상태: 채택 · [0001](0001-extras.md)의 "제약: extra는 새 패키지를 요구하지 않는다"를 대체

## 결정

- **패키지:** extra는 자기에게 필요한 패키지를 extra 안의 `use-package`(`:ensure`)로 직접 가져온다.
  `init.el` 본체로 옮길 필요는 없다.
- **배포 기본값으로 켠 extra**(`emacs-camp.extras` → `extras-default.el`):
  배포할 때 Nix 빌드에서 byte 컴파일(warning을 error로 취급)하고, `.el`과 `.elc`를 링크하며,
  activation에서 native 컴파일하고, 그 switch의 sync에서 패키지를 설치하고 elpa를 컴파일한다.
- **켜지 않은 extra:** `.el`만 배포한다. 컴파일도 패키지 설치도 하지 않는다.
- **배포 뒤 customize로 켠 extra:** 다음에 시작할 때 `.el`로 load된다. sync가 돌고 있지 않으면
  대화형 Emacs는 `use-package-always-ensure`가 `t`이므로(`init.el`) 그 자리에서 패키지가 설치되고,
  native 코드는 처음 load할 때 JIT로 만들어진다. 다음 switch의 sync는 `custom.el`을 거쳐
  그 extra도 읽으므로, 그 뒤로는 기본값으로 켠 extra와 같은 경로를 탄다.
- **CI:** flake fixture가 모든 extra를 켠다. extra 하나하나가 컴파일되는지, 패키지 선언이
  올바른지는 여기서 계속 확인한다.

## 이유

1. **opt-in은 비용도 opt-in이어야 한다.** extras는 취향 묶음이다(0001). 켜지 않은 묶음의 패키지 다운로드,
   byte·native 컴파일, macOS의 eln warm은 쓰는 사람이 없는데 switch 시간과 store·eln-cache를
   차지한다. 켤 때 비용을 내는 구조가 extras의 존재 이유와 맞다.
2. **켜지 않은 extra가 배포를 깨지 않는다.** byte 컴파일은 warning을 error로 취급한다. 그래서
   전부 컴파일하면 쓰지도 않는 extra 하나의 경고가 모든 사용자의 switch를 실패시킨다. 장애 범위를
   켠 사람으로 한정한다. 깨진 extra는 CI fixture가 잡는다.
3. **옛 제약은 의존성 방향을 거꾸로 만들었다.** "extra는 새 패키지 금지"를 지키려면 extra 전용
   패키지를 `init.el`에 넣어야 한다. 그러면 opt-in 기능의 의존성이 모든 사용자에게 강제로 설치된다.
   패키지는 그것을 쓰는 묶음과 함께 있어야 extra를 켜고 끄는 것만으로 설치 범위가 결정된다.
4. **옛 제약이 걱정한 틈은 실제로는 없다.** 0001은 "배포 뒤 켠 extra의 패키지는 다음 sync까지
   설치되지 않는다"를 근거로 들었다. 하지만 켜지 않은 extra는 `.el`로 배포되고, 대화형 Emacs는
   sync가 돌지 않는 동안 `:ensure`가 켜져 있으므로 처음 load할 때 설치된다. sync와 겹치면
   `:ensure`는 꺼지는데(elpa에 쓰는 쪽이 둘이 되지 않도록), 이때만 그 세션에서 해당 패키지가
   빠지고 다음 시작 때 설치된다.

## 결과

- 기본값을 바꾸면(Nix 옵션) 그 switch 한 번으로 설치·컴파일·warm이 끝난다(첫 설치가 아니면 sync는 백그라운드).
- customize로 켠 extra는 첫 load에서 설치와 JIT를 하느라 조금 느리다. 계속 쓸 거라면 Nix 기본값으로 올린다.
- extra는 init.el이 이미 설치하는 패키지를 다시 선언해도 된다. use-package는 중복 설치하지 않는다.
