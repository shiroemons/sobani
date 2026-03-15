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
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

                WindowDetailView(viewModel: viewModel)
            }
        }
    }
}
