import SwiftUI

/// Floating side-label annotation shown during V2 demo scenes.
struct V2SideLabelView: View {
    let label: V2DemoModeManager.SideLabel
    private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            // Title
            Text(label.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // Divider line
            Rectangle()
                .fill(orange.opacity(0.4))
                .frame(height: 1)

            // Items list
            ForEach(label.items, id: \.self) { item in
                let isActive = item == label.activeItem
                HStack(spacing: 5) {
                    Text(item)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular,
                                      design: .rounded))
                        .foregroundStyle(isActive ? orange : Color.primary.opacity(0.45))
                    if isActive {
                        Circle()
                            .fill(orange)
                            .frame(width: 5, height: 5)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 5, height: 5)
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: isActive)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 3)
        )
        .fixedSize()
    }
}
