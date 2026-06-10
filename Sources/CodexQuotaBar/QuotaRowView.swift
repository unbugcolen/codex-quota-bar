import AppKit

final class QuotaRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let batteryView = SegmentedBatteryView()
    private let percentLabel = NSTextField(labelWithString: "--")
    private let resetLabel = NSTextField(labelWithString: "--")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    func configure(title: String, bucket: QuotaBucket?) {
        titleLabel.stringValue = title
        batteryView.remainingPercent = bucket?.remainingPercent
        percentLabel.stringValue = formatPercent(bucket?.remainingPercent)
        resetLabel.stringValue = formatResetDate(bucket?.resetDate)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        percentLabel.alignment = .right
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        resetLabel.font = .systemFont(ofSize: 12)
        resetLabel.textColor = .secondaryLabelColor
        resetLabel.alignment = .right
        resetLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let rightStack = NSStackView(views: [percentLabel, resetLabel])
        rightStack.orientation = .vertical
        rightStack.alignment = .trailing
        rightStack.spacing = 3
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [titleLabel, batteryView, rightStack])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            titleLabel.widthAnchor.constraint(equalToConstant: 52),
            batteryView.widthAnchor.constraint(equalToConstant: 180),
            batteryView.heightAnchor.constraint(equalToConstant: 18),
            rightStack.widthAnchor.constraint(equalToConstant: 122),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func formatPercent(_ percent: Double?) -> String {
        guard let percent else {
            return "--"
        }
        return "\(Int(round(percent)))%"
    }

    private func formatResetDate(_ date: Date?) -> String {
        guard let date else {
            return "重置 --"
        }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "重置 \(formatter.string(from: date))"
    }
}
