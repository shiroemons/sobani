import SwiftUI

struct WindowManagementView: View {
    @Bindable var viewModel: ManagementPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            PresetMinimapView(
                states: viewModel.windowStates,
                images: viewModel.windowImages,
                selectedWindowId: viewModel.selectedWindowIds.first,
                onWindowTapped: { windowId in
                    viewModel.selectedWindowIds = [windowId]
                }
            )
            .fixedSize(horizontal: false, vertical: true)

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
