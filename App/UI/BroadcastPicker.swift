import ReplayKit
import SwiftUI
import UIKit

/// System broadcast picker. Tapping the overlay starts the live-broadcast sheet.
struct BroadcastPicker: UIViewRepresentable {
    var preferredExtension: String = AppConstants.broadcastBundleID

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = preferredExtension
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        if let button = picker.subviews.compactMap({ $0 as? UIButton }).first {
            button.setImage(nil, for: .normal)
            button.setTitle(nil, for: .normal)
            button.tintColor = .clear
        }
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        uiView.preferredExtension = preferredExtension
    }
}

struct BroadcastStartButton: View {
    let title: String
    var body: some View {
        ZStack {
            Label(title, systemImage: "dot.radiowaves.left.and.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            BroadcastPicker()
                .opacity(0.02)
        }
        .frame(height: 52)
    }
}
