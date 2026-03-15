import SwiftUI

struct ManagementPanelView: View {
    @Bindable var viewModel: ManagementPanelViewModel

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 820, minHeight: 560)
    }

    @ViewBuilder
    private var sidebarContent: some View {
        List(ManagementPanelViewModel.ManagementTab.allCases, selection: $viewModel.selectedTab) { tab in
            Label {
                Text(tab.label)
            } icon: {
                Image(systemName: tab.iconName)
            }
            .tag(tab)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.selectedTab {
        case .images:
            WindowManagementView(viewModel: viewModel)
        case .layouts:
            LayoutPresetsView(viewModel: viewModel)
        case .settings:
            SettingsView()
        case .none:
            WindowManagementView(viewModel: viewModel)
        }
    }
}
