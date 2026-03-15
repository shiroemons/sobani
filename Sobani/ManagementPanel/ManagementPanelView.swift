import SwiftUI

struct ManagementPanelView: View {
    @Bindable var viewModel: ManagementPanelViewModel

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 1000, minHeight: 1200)
    }

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            List(ManagementPanelViewModel.ManagementTab.topTabs, selection: $viewModel.selectedTab) { tab in
                Label {
                    Text(tab.label)
                } icon: {
                    Image(systemName: tab.iconName)
                }
                .tag(tab)
            }

            Divider()

            Button {
                viewModel.selectedTab = .settings
            } label: {
                Label {
                    Text(ManagementPanelViewModel.ManagementTab.settings.label)
                } icon: {
                    Image(systemName: ManagementPanelViewModel.ManagementTab.settings.iconName)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .background(
                    viewModel.selectedTab == .settings
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
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
