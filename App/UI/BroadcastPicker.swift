import ReplayKit
import SwiftUI
import UIKit

/// System broadcast picker. Tapping the overlay starts the live-broadcast sheet.
struct BroadcastPicker: UIViewRepresentable {
    var preferredExtension: String = AppConstants.broadcastBundleID

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = preferredExtension
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        picker.translatesAutoresizingMaskIntoConstraints = false
        style(picker)
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        uiView.preferredExtension = preferredExtension
        style(uiView)
    }

    private func style(_ picker: RPSystemBroadcastPickerView) {
        picker.subviews.forEach { view in
            view.frame = picker.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            if let button = view as? UIButton {
                button.setImage(nil, for: .normal)
                button.setTitle(nil, for: .normal)
                button.tintColor = .clear
                button.backgroundColor = .clear
            }
        }
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
            BroadcastPicker()
                .opacity(0.02)
        }
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}
