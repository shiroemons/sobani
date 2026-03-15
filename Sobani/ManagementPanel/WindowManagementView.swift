import SwiftUI

struct WindowManagementView: View {
    @Bindable var viewModel: ManagementPanelViewModel

    var body: some View {
        HSplitView {
            WindowListView(viewModel: viewModel)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            WindowDetailView(viewModel: viewModel)
        }
    }
}
