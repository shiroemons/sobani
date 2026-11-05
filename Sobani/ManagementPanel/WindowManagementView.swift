import SwiftUI

struct WindowManagementView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var isMinimapUnlocked = false

    var body: some View {
        let states = viewModel.windowStates
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack {
                    Toggle(isOn: $isMinimapUnlocked) {
                        Label(
                            L("minimap_placement_mode"),
                            systemImage: isMinimapUnlocked ? "lock.open" : "lock"
                        )
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.top, 4)

                PresetMinimapView(
                    states: states,
                    images: viewModel.windowImages,
                    // 複数選択時はすべて強調する
                    selectedIndices: Set(states.indices.filter {
                        viewModel.selectedWindowIds.contains(states[$0].windowId)
                    }),
                    onWindowTapped: { index in
                        guard states.indices.contains(index) else { return }
                        viewModel.selectedWindowIds = [states[index].windowId]
                    },
                    isDragEnabled: isMinimapUnlocked,
                    onWindowDragChanged: { windowId, newOrigin in
                        viewModel.moveWindowWithoutRefresh(
                            windowId: windowId, origin: newOrigin
                        )
                    },
                    onWindowDragEnded: { windowId, newOrigin in
                        viewModel.moveWindowAndRefresh(
                            windowId: windowId, origin: newOrigin
                        )
                    }
                )
            }

            Divider()

            HSplitView {
                WindowListView(viewModel: viewModel)
                    .splitPanelFrame()

                WindowDetailView(viewModel: viewModel)
                    .splitPanelFrame()
            }
        }
    }
}
