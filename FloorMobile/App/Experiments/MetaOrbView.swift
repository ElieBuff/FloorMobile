//
//  MetaOrbView.swift
//  FloorMobile
//
//  Temporary visual experiment — not part of the target design system yet.
//

import SwiftUI

/// Closed organic outline: a circle whose radius is modulated by three
/// sine waves with non-harmonic periods. Because they never loop in sync,
/// the eye cannot perceive the repetition.
struct OrganicBlob: Shape {
    var time: Double
    var wobble: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) * 0.42
        let steps = 240

        var path = Path()
        for i in 0...steps {
            let angle = Double(i) / Double(steps) * 2 * .pi
            let deform = sin(3 * angle + time * 0.53)
                + 0.62 * sin(5 * angle - time * 0.37)
                + 0.41 * sin(2 * angle + time * 0.81)
            let radius = base * (1 + wobble * deform)
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct MetaOrbView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)

                ZStack {
                    OrganicBlob(time: t, wobble: 0.11)
                        .fill(Self.ring(rotatedBy: t * 0.45))
                        .blur(radius: side * 0.085)

                    OrganicBlob(time: t + 1.7, wobble: 0.07)
                        .fill(Self.ring(rotatedBy: t * 0.61 + 2))
                        .blur(radius: side * 0.13)
                        .blendMode(.plusLighter)
                        .opacity(0.5)
                }
                .compositingGroup()
                .mask(
                    ZStack {
                        Rectangle()
                        Circle()
                            .frame(width: side * 0.54, height: side * 0.54)
                            .blur(radius: side * 0.012)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
            }
        }
    }

    private static func ring(rotatedBy radians: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: palette),
            center: .center,
            angle: .radians(radians)
        )
    }

    // First and last colors are identical for a seamless loop.
    private static let palette: [Color] = [
        Color(red: 0.74, green: 0.30, blue: 0.91),
        Color(red: 0.30, green: 0.42, blue: 0.97),
        Color(red: 0.11, green: 0.28, blue: 0.95),
        Color(red: 0.13, green: 0.45, blue: 0.96),
        Color(red: 0.22, green: 0.70, blue: 0.93),
        Color(red: 0.74, green: 0.30, blue: 0.91)
    ]
}

struct MetaOrbDemo: View {
    var body: some View {
        ZStack {
            Color(white: 0.93).ignoresSafeArea()
            MetaOrbView()
                .frame(width: 260, height: 260)
        }
    }
}

#Preview {
    MetaOrbDemo()
}
