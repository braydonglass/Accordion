import SwiftUI

struct AccordionView: View {
    @ObservedObject private var engine = Engine.shared

    private struct BlackKey: Identifiable {
        let key: Character
        /// Index of the white key this one sits after.
        let after: Int
        var id: Character { key }
    }

    private static let whites: [Character] = ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"]
    private static let blacks = [
        BlackKey(key: "w", after: 0), BlackKey(key: "e", after: 1), BlackKey(key: "t", after: 3),
        BlackKey(key: "y", after: 4), BlackKey(key: "u", after: 5), BlackKey(key: "o", after: 7),
        BlackKey(key: "p", after: 8),
    ]

    var body: some View {
        VStack(spacing: 18) {
            accordion.frame(height: 270)
            meter
            keyboard.frame(height: 140)
            Text(status).font(.callout).foregroundStyle(.secondary)
        }
        .padding(30)
        .frame(width: 760, height: 560)
        .background(Color(red: 0.09, green: 0.08, blue: 0.10))
        .background(KeyCatcher())
        .preferredColorScheme(.dark)
    }

    private var status: String {
        if let error = engine.soundError { return error }
        if engine.angle == nil { return "No lid sensor found" }
        let shift = engine.octave == 0 ? "" : " (\(engine.octave > 0 ? "+" : "")\(engine.octave))"
        return "Move the lid to blow air, then play with A S D F G H J K L. Z / X change octave\(shift)."
    }

    // MARK: Accordion

    private var accordion: some View {
        Canvas { ctx, size in
            let open = min(max((engine.angle ?? 70) / 135, 0), 1)
            let bodyW: CGFloat = 130
            let bellowsW: CGFloat = 80 + 240 * open
            let h = size.height * 0.85
            let x0 = (size.width - (bodyW * 2 + bellowsW)) / 2
            let top = (size.height - h) / 2
            let bottom = top + h

            let bellowsX = x0 + bodyW
            let folds = 16
            let inset: CGFloat = 14
            for i in 0..<folds {
                let xa = bellowsX + bellowsW * CGFloat(i) / CGFloat(folds)
                let xb = bellowsX + bellowsW * CGFloat(i + 1) / CGFloat(folds)
                // Fold lines alternate between the outer edge and inset, giving the zigzag silhouette.
                let ia = i % 2 == 0 ? 0 : inset
                let ib = i % 2 == 0 ? inset : 0
                var strip = Path()
                strip.move(to: CGPoint(x: xa, y: top + ia))
                strip.addLine(to: CGPoint(x: xb, y: top + ib))
                strip.addLine(to: CGPoint(x: xb, y: bottom - ib))
                strip.addLine(to: CGPoint(x: xa, y: bottom - ia))
                strip.closeSubpath()
                ctx.fill(strip, with: .color(Color(white: i % 2 == 0 ? 0.10 : 0.20)))
                ctx.stroke(strip, with: .color(Color(white: 0.55)), lineWidth: 1)
            }

            let left = CGRect(x: x0, y: top, width: bodyW, height: h)
            let right = CGRect(x: bellowsX + bellowsW, y: top, width: bodyW, height: h)
            for rect in [left, right] {
                let shape = Path(roundedRect: rect, cornerRadius: 16)
                ctx.fill(shape, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.70, green: 0.10, blue: 0.13), Color(red: 0.42, green: 0.05, blue: 0.08)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
                ctx.stroke(shape, with: .color(Color(white: 0.85)), lineWidth: 2)
            }

            // Grill slits on the left body, buttons on the right.
            for row in 0..<7 {
                let y = top + 40 + CGFloat(row) * 24
                let slit = Path(roundedRect: CGRect(x: left.minX + 28, y: y, width: bodyW - 56, height: 8), cornerRadius: 4)
                ctx.fill(slit, with: .color(Color.black.opacity(0.55)))
            }
            for row in 0..<6 {
                for col in 0..<3 {
                    let dot = CGRect(x: right.minX + 26 + CGFloat(col) * 34, y: top + 34 + CGFloat(row) * 32, width: 22, height: 22)
                    ctx.fill(Path(ellipseIn: dot), with: .color(Color(white: 0.92)))
                    ctx.stroke(Path(ellipseIn: dot), with: .color(Color.black.opacity(0.5)), lineWidth: 1)
                }
            }
        }
    }

    // MARK: Air meter

    private var meter: some View {
        HStack(spacing: 10) {
            Text("AIR").font(.caption.monospaced()).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Color.orange).frame(width: geo.size.width * engine.pressure)
                }
            }
            .frame(height: 10)
            Text(engine.angle.map { "lid \(Int($0))°" } ?? "lid --")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
    }

    // MARK: Keys

    private var keyboard: some View {
        GeometryReader { geo in
            let whiteW = geo.size.width / CGFloat(Self.whites.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(Self.whites, id: \.self) { key in
                        keyCap(key, dark: false).frame(width: whiteW)
                    }
                }
                ForEach(Self.blacks) { black in
                    keyCap(black.key, dark: true)
                        .frame(width: whiteW * 0.6, height: geo.size.height * 0.62)
                        .offset(x: whiteW * CGFloat(black.after + 1) - whiteW * 0.3)
                }
            }
        }
    }

    private func keyCap(_ key: Character, dark: Bool) -> some View {
        let lit = engine.held.contains(key)
        let fill = dark
            ? (lit ? Color.orange : Color(white: 0.05))
            : (lit ? Color.orange.opacity(0.8) : Color(white: 0.93))
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5).fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.6), lineWidth: 1))
            Text(String(key).uppercased())
                .font(.caption.bold())
                .foregroundStyle(dark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
                .padding(.bottom, 8)
        }
    }
}
