import SwiftUI

struct WindowPositionEditorView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    let windowInfo: ManagementPanelViewModel.WindowInfo
    @State private var posX: String = ""
    @State private var posY: String = ""
    @State private var sizeW: String = ""
    @State private var sizeH: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("management.position"))
                .font(.subheadline.bold())

            HStack(spacing: 12) {
                labeledField("X", text: $posX)
                labeledField("Y", text: $posY)
            }

            Text(L("management.size"))
                .font(.subheadline.bold())
                .padding(.top, 4)

            HStack(spacing: 12) {
                labeledField("W", text: $sizeW)
                labeledField("H", text: $sizeH)
            }

            Button(L("management.apply")) {
                applyChanges()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .onAppear { loadValues() }
        .onChange(of: windowInfo.originX) { loadValues() }
        .onChange(of: windowInfo.originY) { loadValues() }
        .onChange(of: windowInfo.width) { loadValues() }
        .onChange(of: windowInfo.height) { loadValues() }
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 16)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
                .frame(maxWidth: 80)
        }
    }

    private func loadValues() {
        posX = "\(Int(windowInfo.originX))"
        posY = "\(Int(windowInfo.originY))"
        sizeW = "\(Int(windowInfo.width))"
        sizeH = "\(Int(windowInfo.height))"
    }

    private func applyChanges() {
        guard let xVal = Double(posX),
              let yVal = Double(posY),
              let wVal = Double(sizeW),
              let hVal = Double(sizeH),
              wVal > 0, hVal > 0 else { return }
        viewModel.changePositionAndSize(
            windowId: windowInfo.windowId,
            origin: CGPoint(x: xVal, y: yVal),
            size: CGSize(width: wVal, height: hVal)
        )
    }
}
