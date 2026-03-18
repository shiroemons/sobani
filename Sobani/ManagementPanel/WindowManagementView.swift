import SwiftUI

struct WindowManagementView: View {
    @Bindable var viewModel: ManagementPanelViewModel
    @State private var isMinimapUnlocked = false

    var body: some View {
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
                    states: viewModel.windowStates,
                    images: viewModel.windowImages,
                    selectedWindowId: viewModel.selectedWindowIds.first,
                    onWindowTapped: { windowId in
                        viewModel.selectedWindowIds = [windowId]
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
