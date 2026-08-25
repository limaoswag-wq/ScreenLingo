import ReplayKit
import SwiftUI
import UIKit

/// Full-size ReplayKit picker. Same system control iTrans uses:
/// `RPSystemBroadcastPickerView` with its inner UIButton stretched to the whole area.
struct BroadcastPicker: UIViewRepresentable {
    var preferredExtension: String = AppConstants.broadcastBundleID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BroadcastPickerHost {
        let host = BroadcastPickerHost()
        host.preferredExtension = preferredExtension
        return host
    }

    func updateUIView(_ uiView: BroadcastPickerHost, context: Context) {
        uiView.preferredExtension = preferredExtension
    }
}

final class BroadcastPickerHost: UIView {
    var preferredExtension: String = AppConstants.broadcastBundleID {
        didSet { picker.preferredExtension = preferredExtension }
    }

    private let picker = RPSystemBroadcastPickerView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        picker.preferredExtension = preferredExtension
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        addSubview(picker)
        expandButton()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        picker.frame = bounds
        expandButton()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else { return nil }
        if let button = pickerButton {
            return button
        }
        return picker
    }

    private var pickerButton: UIButton? {
        picker.subviews.compactMap { $0 as? UIButton }.first
    }

    private func expandButton() {
        guard let button = pickerButton else { return }
        button.frame = picker.bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.setImage(nil, for: .normal)
        button.setTitle(nil, for: .normal)
        button.tintColor = .clear
        button.backgroundColor = .clear
        button.isUserInteractionEnabled = true
    }
}

struct BroadcastStartButton: View {
    let title: String

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                .allowsHitTesting(false)
            BroadcastPicker()
                .opacity(0.02)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
    }
}
