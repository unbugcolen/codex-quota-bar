import AppKit

final class SegmentedBatteryView: NSView {
    var remainingPercent: Double? {
        didSet {
            needsDisplay = true
        }
    }

    private let segmentCount = 16
    private let segmentGap: CGFloat = 2

    override var intrinsicContentSize: NSSize {
        NSSize(width: 180, height: 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds.insetBy(dx: 0.5, dy: 1.5)
        let radius: CGFloat = 3
        let outline = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        NSColor.separatorColor.setStroke()
        outline.lineWidth = 1
        outline.stroke()

        let percent = min(100, max(0, remainingPercent ?? 0))
        let filledSegments = Int(ceil((percent / 100) * Double(segmentCount)))
        let segmentWidth = (bounds.width - CGFloat(segmentCount - 1) * segmentGap) / CGFloat(segmentCount)

        for index in 0..<segmentCount {
            let x = bounds.minX + CGFloat(index) * (segmentWidth + segmentGap)
            let rect = NSRect(x: x, y: bounds.minY, width: segmentWidth, height: bounds.height)
                .insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)

            if index < filledSegments {
                fillColor(for: percent).setFill()
            } else {
                NSColor.quaternaryLabelColor.withAlphaComponent(0.35).setFill()
            }
            path.fill()
        }
    }

    private func fillColor(for percent: Double) -> NSColor {
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
