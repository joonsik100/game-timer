#!/bin/zsh
# 커밋 전 한 번에 돌리는 검사: 프로젝트 파일 문법 → 로직 테스트 → 앱 빌드.
set -e
cd "${0:a:h}/.."

echo "▶ 프로젝트 파일 문법"
plutil -lint GameTimer.xcodeproj/project.pbxproj
for f in GameTimer/Assets.xcassets/**/Contents.json GameTimer/Assets.xcassets/Contents.json; do
  python3 -m json.tool "$f" > /dev/null && echo "$f: OK"
done

echo "\n▶ 로직 테스트"
./Scripts/test.sh

echo "\n▶ 앱 빌드"
./Scripts/build.sh -quiet && echo "빌드 성공"
