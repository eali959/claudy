import SwiftUI
import AppKit

/// Ko-fi donation popover — presented from character right-click menu.
struct DonatePopoverView: View {
    private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("☕")
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("If Claud-y made your day a bit better...")
                        .font(.system(size: 13, weight: .semibold))
                    Text("It's free. It'll stay free. But coffee is fuel.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                if let url = URL(string: "https://ko-fi.com/ealiii") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Support on Ko-fi")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(orange, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Text("Ko-fi accepts any amount, one-time or recurring.\nNo account needed.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(width: 260)
    }
}
