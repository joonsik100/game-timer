// 1024×1024 앱 아이콘을 만든다. 앱과 같은 회색조로, 스톱워치 모양.
// 실행: xcrun swift Scripts/make_icon.swift
//
// 이 파일은 GameTimer/ 폴더 밖에 둔다. 프로젝트가 그 폴더의 .swift를 전부 컴파일하기 때문이다.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let center = CGPoint(x: 512, y: 512)

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    // 알파 없이(불투명) 만든다. 아이콘에 투명도가 있으면 안 된다.
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("비트맵 컨텍스트를 만들 수 없음")
}

func gray(_ value: CGFloat) -> CGColor {
    CGColor(srgbRed: value, green: value, blue: value, alpha: 1)
}

let ink = gray(0.93)

// 배경
context.setFillColor(gray(0.11))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

context.setStrokeColor(ink)
context.setFillColor(ink)
context.setLineCap(.round)

// 다이얼 링
context.setLineWidth(58)
context.addArc(center: center, radius: 300, startAngle: 0, endAngle: .pi * 2, clockwise: false)
context.strokePath()

// 위쪽 용두
let stem = CGRect(x: 512 - 52, y: 812, width: 104, height: 78)
context.addPath(CGPath(roundedRect: stem, cornerWidth: 26, cornerHeight: 26, transform: nil))
context.fillPath()

// 바늘 두 개: 12시 방향과 4시 방향
context.setLineWidth(46)
context.move(to: center)
context.addLine(to: CGPoint(x: 512, y: 512 + 196))
context.strokePath()

context.setLineWidth(40)
context.move(to: center)
context.addLine(to: CGPoint(x: 512 + 124, y: 512 - 72))
context.strokePath()

// 중심점
context.addArc(center: center, radius: 34, startAngle: 0, endAngle: .pi * 2, clockwise: false)
context.fillPath()

guard let image = context.makeImage() else { fatalError("이미지 생성 실패") }

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("GameTimer/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

guard let destination = CGImageDestinationCreateWithURL(
    output as CFURL, UTType.png.identifier as CFString, 1, nil
) else {
    fatalError("PNG 대상 생성 실패")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("PNG 저장 실패") }

print("아이콘 생성: \(output.path)")
