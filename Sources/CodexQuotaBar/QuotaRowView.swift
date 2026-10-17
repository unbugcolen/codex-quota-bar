import AppKit

final class QuotaRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let progressView = QuotaProgressView()
    private let remainingLabel = NSTextField(labelWithString: "剩余")
    private let percentLabel = NSTextField(labelWithString: "--")
    private let resetLabel = NSTextField(labelWithString: "--")
    private var hasQuota = false
    private var heightConstraint: NSLayoutConstraint?

    var preferredHeight: CGFloat { hasQuota ? 52 : 20 }

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
        hasQuota = bucket?.remainingPercent != nil
        titleLabel.textColor = hasQuota ? .labelColor : .secondaryLabelColor
        progressView.remainingPercent = bucket?.remainingPercent
        progressView.isHidden = !hasQuota
        remainingLabel.isHidden = !hasQuota
        resetLabel.isHidden = !hasQuota
        percentLabel.stringValue = bucket == nil ? "--" : formatPercent(bucket?.remainingPercent)
        percentLabel.font = hasQuota ? .monospacedDigitSystemFont(ofSize: 16, weight: .medium) : .systemFont(ofSize: 12)
        percentLabel.textColor = hasQuota ? .labelColor : .tertiaryLabelColor
        resetLabel.stringValue = formatResetDate(bucket?.resetDate)
        percentLabel.toolTip = hasQuota ? nil : (bucket == nil ? "等待刷新" : "当前账户未提供此额度")
        heightConstraint?.constant = preferredHeight
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        remainingLabel.font = .systemFont(ofSize: 10)
        remainingLabel.textColor = .secondaryLabelColor
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        percentLabel.alignment = .right
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        resetLabel.font = .systemFont(ofSize: 11)
        resetLabel.textColor = .secondaryLabelColor
        resetLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let value = NSStackView(views: [remainingLabel, percentLabel])
        value.orientation = .horizontal
        value.alignment = .firstBaseline
        value.spacing = 5

        let heading = NSStackView(views: [titleLabel, NSView(), value])
        heading.orientation = .horizontal
        heading.alignment = .centerY

        let stack = NSStackView(views: [heading, progressView, resetLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let heightConstraint = heightAnchor.constraint(equalToConstant: preferredHeight)
        self.heightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            heading.widthAnchor.constraint(equalTo: stack.widthAnchor),
            heading.heightAnchor.constraint(equalToConstant: 20),
            progressView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 5),
            resetLabel.heightAnchor.constraint(equalToConstant: 14),
            heightConstraint,
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func formatPercent(_ percent: Double?) -> String {
        guard let percent else {
            return "未提供"
        }
        return "\(Int(round(percent)))%"
    }

    private func formatResetDate(_ date: Date?) -> String {
        guard let date else {
            return "重置时间未提供"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return "\(formatter.string(from: date)) 重置"
    }
}
