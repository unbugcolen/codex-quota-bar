import AppKit

final class TouchBarQuotaView: NSView {
    init(title: String, bucket: QuotaBucket?) {
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        build(title: title, bucket: bucket)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func build(title: String, bucket: QuotaBucket?) {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let battery = SegmentedBatteryView()
        battery.remainingPercent = bucket?.remainingPercent

        let percentLabel = NSTextField(labelWithString: formatPercent(bucket?.remainingPercent))
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        percentLabel.alignment = .right

        let stack = NSStackView(views: [titleLabel, battery, percentLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 220),
            heightAnchor.constraint(equalToConstant: 30),
            titleLabel.widthAnchor.constraint(equalToConstant: 46),
            battery.widthAnchor.constraint(equalToConstant: 110),
            battery.heightAnchor.constraint(equalToConstant: 16),
            percentLabel.widthAnchor.constraint(equalToConstant: 38),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func formatPercent(_ percent: Double?) -> String {
        guard let percent else {
            return "--"
        }
        return "\(Int(round(percent)))%"
    }
}
