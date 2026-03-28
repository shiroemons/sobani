import SwiftUI

// MARK: - PositionLogEmptyStateView

struct PositionLogEmptyStateView: View {
    let isEnabled: Bool
    let onEnable: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 20) {
                    if !isEnabled {
                        VStack(spacing: 8) {
                            Image(systemName: "record.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text(L("log.disabled.title"))
                                .font(.headline)
                            Text(L("log.disabled.description"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button(L("log.disabled.action"), action: onEnable)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text(L("log.empty"))
                                .font(.headline)
                            Text(L("log.footer.description"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Divider()
                        .padding(.horizontal, 40)

                    PositionLogInfoView()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(minHeight: geo.size.height)
            }
        }
    }
}

// MARK: - PositionLogInfoView

struct PositionLogInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox {
                Text(L("log.info.purpose.body"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L("log.info.purpose.title"), systemImage: "info.circle")
                    .font(.headline)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    logInfoItem(L("log.info.records.screens"))
                    logInfoItem(L("log.info.records.positions"))
                    logInfoItem(L("log.info.records.sleep"))
                    logInfoItem(L("log.info.records.restore"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L("log.info.records.title"), systemImage: "list.bullet")
                    .font(.headline)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    privacyItem(L("log.info.privacy.no_image_name"), isRecorded: false)
                    privacyItem(L("log.info.privacy.no_file_path"), isRecorded: false)
                    privacyItem(L("log.info.privacy.no_content"), isRecorded: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label(L("log.info.privacy.title"), systemImage: "lock.shield")
                    .font(.headline)
            }
        }
        .frame(maxWidth: 480)
    }

    // MARK: - Private

    private func logInfoItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 2)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func privacyItem(_ text: String, isRecorded: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: isRecorded ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(isRecorded ? Color.red : Color.green)
                .padding(.top, 2)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
