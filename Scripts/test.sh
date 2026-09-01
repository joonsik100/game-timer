#!/bin/zsh
# 순수 로직(주 계산, 포맷, 저장, 스토어)을 시뮬레이터 없이 바로 실행해 확인한다.
# Models/ 와 Core/ 는 SwiftUI를 import 하지 않기 때문에 이렇게 단독으로 컴파일할 수 있다.
set -e
cd "${0:a:h}/.."

BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

xcrun swiftc -swift-version 5 -O -o "$BUILD/logic-tests" \
  GameTimer/Models/Models.swift \
  GameTimer/Models/Defaults.swift \
  GameTimer/Core/WeekMath.swift \
  GameTimer/Core/TimeFormat.swift \
  GameTimer/Core/ScreenCare.swift \
  GameTimer/Core/Persistence.swift \
  GameTimer/Core/AppStore.swift \
  GameTimer/Support/L10n.swift \
  Tests/LogicTests.swift

"$BUILD/logic-tests"
