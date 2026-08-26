import UIKit

/// Own caption board rendered into the sample-buffer PiP. Not copied from another app.
final class CaptionBoardView: UIView {
    var fontSize: CaptionFontSize = .medium {
        didSet { applyFonts() }
    }

    private let sourceLabel = UILabel()
    private let divider = UIView()
    private let translationStack = UIStackView()
    private let statusLabel = UILabel()
    private var translationLabels: [UILabel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        layer.cornerRadius = 10
        layer.masksToBounds = true

        sourceLabel.numberOfLines = 3
        sourceLabel.textAlignment = .center
        sourceLabel.textColor = .white
        sourceLabel.adjustsFontSizeToFitWidth = true
        sourceLabel.minimumScaleFactor = 0.7
        sourceLabel.lineBreakMode = .byTruncatingTail

        divider.backgroundColor = UIColor(white: 1, alpha: 0.18)

        translationStack.axis = .vertical
        translationStack.alignment = .fill
        translationStack.spacing = 4

        statusLabel.numberOfLines = 2
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor(white: 0.78, alpha: 1)
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.75

        let stack = UIStackView(arrangedSubviews: [sourceLabel, divider, translationStack, statusLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
        applyFonts()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        source: String,
        lines: [CaptionLine],
        emptyMessage: String?,
        fontSize: CaptionFontSize
    ) {
        self.fontSize = fontSize
        let hasSource = !source.isEmpty
        sourceLabel.text = source
        sourceLabel.isHidden = !hasSource
        divider.isHidden = !hasSource

        translationStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        translationLabels.removeAll()

        if let emptyMessage, lines.isEmpty {
            statusLabel.text = emptyMessage
            statusLabel.textColor = .systemOrange
            statusLabel.isHidden = false
            return
        }
        if lines.isEmpty && !hasSource {
            statusLabel.text = "切换到其他 App 开始翻译"
            statusLabel.textColor = UIColor(white: 0.78, alpha: 1)
            statusLabel.isHidden = false
            return
        }

        statusLabel.isHidden = true
        for line in lines.prefix(3) {
            let label = UILabel()
            label.numberOfLines = 3
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7
            label.lineBreakMode = .byTruncatingTail
            label.font = UIFont.systemFont(ofSize: fontSize.translatedPoints, weight: .semibold)
            if line.error != nil {
                label.textColor = .systemOrange
            } else if line.pending && line.text.isEmpty {
                label.textColor = UIColor(white: 0.72, alpha: 1)
            } else {
                label.textColor = HexColor.uiColor(from: line.hex)
            }
            label.text = line.displayText
            translationStack.addArrangedSubview(label)
            translationLabels.append(label)
        }
        if hasSource == false, !lines.isEmpty {
            statusLabel.text = "已识别，正在翻译…"
            statusLabel.textColor = UIColor(white: 0.78, alpha: 1)
            statusLabel.isHidden = lines.contains { !$0.text.isEmpty || $0.error != nil }
        }
        layoutIfNeeded()
    }

    private func applyFonts() {
        sourceLabel.font = UIFont.systemFont(ofSize: fontSize.sourcePoints, weight: .regular)
        statusLabel.font = UIFont.systemFont(ofSize: fontSize.sourcePoints, weight: .medium)
        for label in translationLabels {
            label.font = UIFont.systemFont(ofSize: fontSize.translatedPoints, weight: .semibold)
        }
    }
}
