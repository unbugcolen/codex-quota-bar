import AppKit

enum StatusBarProgressRenderer {
    static func miniImage(fiveHourPercent: Double?, weeklyPercent: Double?, appearance: NSAppearance?) -> NSImage {
        makeImage(size: NSSize(width: 28, height: 18), appearance: appearance) {
            NSGraphicsContext.current?.imageInterpolation = .high
            drawMiniRow(percent: fiveHourPercent, y: 10)
            drawMiniRow(percent: weeklyPercent, y: 3)
        }
    }

    static func compactImage(fiveHourPercent: Double?, weeklyPercent: Double?, appearance: NSAppearance?) -> NSImage {
        makeImage(size: NSSize(width: 74, height: 18), appearance: appearance) {
            NSGraphicsContext.current?.imageInterpolation = .high
            drawCompactRow(label: "5h", percent: fiveHourPercent, y: 10)
            drawCompactRow(label: "W", percent: weeklyPercent, y: 1)
        }
    }

    static func singleImage(percent: Double?, appearance: NSAppearance?) -> NSImage {
        makeImage(size: NSSize(width: 94, height: 18), appearance: appearance) {
            let remaining = percent.map { min(100, max(0, $0)) }
            drawSingleLabel(text: "Codex", rect: NSRect(x: 0, y: 3, width: 36, height: 12))
            drawSinglePercent(remaining, rect: NSRect(x: 72, y: 3, width: 22, height: 12))
            drawBar(percent: remaining, rect: NSRect(x: 40, y: 6, width: 29, height: 6))
        }
    }

    static func image(fiveHourPercent: Double?, weeklyPercent: Double?, appearance: NSAppearance?) -> NSImage {
        makeImage(size: NSSize(width: 118, height: 18), appearance: appearance) {
            NSGraphicsContext.current?.imageInterpolation = .high
            drawRow(label: "5h", percent: fiveHourPercent, y: 10)
            drawRow(label: "W", percent: weeklyPercent, y: 1)
        }
    }

    private static func makeImage(size: NSSize, appearance: NSAppearance?, draw: @escaping () -> Void) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        let drawWithDefaults = {
            NSGraphicsContext.current?.imageInterpolation = .high
            draw()
        }

        if let appearance {
            appearance.performAsCurrentDrawingAppearance(drawWithDefaults)
        } else {
            drawWithDefaults()
        }
        return image
    }

    private static func drawRow(label: String, percent: Double?, y: CGFloat) {
        let remaining = percent.map { min(100, max(0, $0)) }
        drawLabel(text: label, rect: NSRect(x: 1, y: y - 1, width: 15, height: 8))
        drawBar(percent: remaining, rect: NSRect(x: 18, y: y + 1, width: 63, height: 5))
        drawPercent(remaining, rect: NSRect(x: 85, y: y - 1, width: 32, height: 8))
    }

    private static func drawCompactRow(label: String, percent: Double?, y: CGFloat) {
        let remaining = percent.map { min(100, max(0, $0)) }
        drawLabel(text: label, rect: NSRect(x: 1, y: y - 1, width: 15, height: 8))
        drawBar(percent: remaining, rect: NSRect(x: 18, y: y + 1, width: 54, height: 5))
    }

    private static func drawMiniRow(percent: Double?, y: CGFloat) {
        let remaining = percent.map { min(100, max(0, $0)) }
        drawBar(percent: remaining, rect: NSRect(x: 2, y: y, width: 24, height: 5))
    }

    private static func drawLabel(text: String, rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7.5, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func drawSingleLabel(text: String, rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func drawPercent(_ percent: Double?, rect: NSRect) {
        let text = percent.map { "\(Int(round($0)))%" } ?? "--"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: rightAlignedParagraphStyle
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func drawSinglePercent(_ percent: Double?, rect: NSRect) {
        let text = percent.map { "\(Int(round($0)))%" } ?? "--"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: rightAlignedParagraphStyle
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func drawBar(percent: Double?, rect: NSRect) {
        let rounded = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.22).setFill()
        rounded.fill()

        guard let percent else {
            return
        }

        let fillWidth = max(1.5, rect.width * CGFloat(percent / 100))
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height)
        NSGraphicsContext.saveGraphicsState()
        rounded.addClip()
        color(for: percent).setFill()
        fillRect.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func color(for percent: Double) -> NSColor {
        switch percent {
        case 50...:
            return .systemGreen
        case 20..<50:
            return .systemOrange
        default:
            return .systemRed
        }
    }

    private static var rightAlignedParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }
}
