#!/bin/zsh
# iOS 시뮬레이터용으로 빌드해 컴파일 오류/경고를 확인한다.
# Xcode를 기본 개발자 디렉터리로 지정하지 않아도 되도록 DEVELOPER_DIR을 직접 넘긴다.
# 빌드 산출물은 Xcode 기본 위치(~/Library/Developer/Xcode/DerivedData)에 둔다.
# 프로젝트 폴더를 더럽히지 않고, Xcode GUI 빌드와 캐시를 공유해 재빌드가 빠르다.
set -e
cd "${0:a:h}/.."

: ${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}
export DEVELOPER_DIR
# 기본은 기기 이름에 묶이지 않는 generic 대상이라 어떤 Xcode에서도 빌드된다.
# 특정 기기에 설치하려면 SIMULATOR="iPhone 17 Pro" 처럼 지정한다.
if [[ -n "${SIMULATOR:-}" ]]; then
  DESTINATION="platform=iOS Simulator,name=$SIMULATOR"
else
  DESTINATION="generic/platform=iOS Simulator"
fi

xcodebuild \
  -project GameTimer.xcodeproj \
  -scheme GameTimer \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  build "$@"
