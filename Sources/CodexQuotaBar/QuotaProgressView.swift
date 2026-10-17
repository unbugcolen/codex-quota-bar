import AppKit

final class QuotaProgressView: NSView {
    var remainingPercent: Double? {
        didSet {
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 180, height: 5)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let height = min(5, bounds.height)
        let rect = NSRect(x: bounds.minX, y: bounds.midY - height / 2, width: bounds.width, height: height)
        let track = NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2)
        NSColor.labelColor.withAlphaComponent(0.08).setFill()
        track.fill()

        guard let remainingPercent else { return }
        let percent = min(100, max(0, remainingPercent))
        guard percent > 0 else { return }
        let fill = NSRect(x: rect.minX, y: rect.minY, width: rect.width * CGFloat(percent / 100), height: rect.height)
        Self.fillColor(for: percent).setFill()
        NSBezierPath(roundedRect: fill, xRadius: height / 2, yRadius: height / 2).fill()
    }

    static func fillColor(for percent: Double) -> NSColor {
        switch percent {
        case 50...:
            return NSColor.systemGreen
        case 20..<50:
            return NSColor.systemOrange
        default:
            return NSColor.systemRed
        }
    }
}
