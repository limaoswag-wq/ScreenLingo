import SwiftUI

struct RegionEditorView: View {
    @Binding var region: OCRRegion
    @Environment(\.dismiss) private var dismiss
    @State private var draft: OCRRegion = .full
    @State private var dragOrigin: OCRRegion = .full
    @State private var resizeOrigin: OCRRegion = .full

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("拖动蓝色框选择识别范围，拖右下角圆点改大小。只影响直播扩展送来的那一帧里被裁出来的部分。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                GeometryReader { geo in
                    let canvas = geo.size
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.35))
                        screenSketch
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        let rect = pixelRect(draft, in: canvas)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        var next = dragOrigin
                                        next.x += Double(value.translation.width / canvas.width)
                                        next.y += Double(value.translation.height / canvas.height)
                                        draft = next.clamped()
                                    }
                                    .onEnded { _ in
                                        dragOrigin = draft
                                        resizeOrigin = draft
                                    }
                            )

                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                            .offset(x: rect.maxX - 11, y: rect.maxY - 11)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        var next = resizeOrigin
                                        next.width += Double(value.translation.width / canvas.width)
                                        next.height += Double(value.translation.height / canvas.height)
                                        draft = next.clamped()
                                    }
                                    .onEnded { _ in
                                        resizeOrigin = draft
                                    }
                            )
                    }
                }
                .aspectRatio(9 / 16, contentMode: .fit)
                .padding(.horizontal)

                HStack {
                    Button("恢复横屏字幕带") {
                        draft = OCRRegion(x: 0.08, y: 0.72, width: 0.84, height: 0.22)
                        dragOrigin = draft
                        resizeOrigin = draft
                    }
                    Spacer()
                    Button("全屏") {
                        draft = .full
                        dragOrigin = draft
                        resizeOrigin = draft
                    }
                }
                .padding(.horizontal)
                .buttonStyle(.bordered)

                Spacer()
            }
            .navigationTitle("翻译区域")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        region = draft.clamped()
                        dismiss()
                    }
                }
            }
            .onAppear {
                draft = region.clamped()
                dragOrigin = draft
                resizeOrigin = draft
            }
        }
    }

    private var screenSketch: some View {
        VStack(spacing: 10) {
            Capsule().fill(Color.white.opacity(0.15)).frame(width: 48, height: 6).padding(.top, 10)
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)).frame(height: 90)
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)).frame(height: 160)
            Spacer()
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)).frame(height: 36).padding(.bottom, 24)
        }
        .padding(16)
    }

    private func pixelRect(_ region: OCRRegion, in size: CGSize) -> CGRect {
        let r = region.clamped()
        return CGRect(
            x: r.x * size.width,
            y: r.y * size.height,
            width: r.width * size.width,
            height: r.height * size.height
        )
    }
}
