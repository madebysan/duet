import SwiftUI

/// Wide fill bar: drag anywhere to set an exact level, − and + nudge it.
struct VolumeBar: View {
    @Binding var percent: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            nudgeButton(systemName: "minus", label: "Lower volume", up: false)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MixTheme.surfaceLight)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.42))
                        .frame(width: proxy.size.width * CGFloat(percent) / 100)

                    HStack {
                        Image(systemName: percent == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MixTheme.textSecondary)
                        Spacer()
                        Text("\(percent)%")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(MixTheme.textPrimary)
                            .contentTransition(.numericText(value: Double(percent)))
                    }
                    .padding(.horizontal, 14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let raw = value.location.x / max(proxy.size.width, 1) * 100
                            let next = Int(min(max(raw, 0), 100).rounded())
                            if next != percent {
                                if next / 5 != percent / 5 { Haptics.selection() }
                                percent = next
                            }
                        }
                )
            }
            .frame(height: 48)
            .accessibilityElement()
            .accessibilityLabel("Volume")
            .accessibilityValue("\(percent) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: percent = VolumeStep.stepped(from: percent, up: true)
                case .decrement: percent = VolumeStep.stepped(from: percent, up: false)
                @unknown default: break
                }
            }

            nudgeButton(systemName: "plus", label: "Raise volume", up: true)
        }
    }

    private func nudgeButton(systemName: String, label: String, up: Bool) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(.snappy(duration: 0.18)) {
                percent = VolumeStep.stepped(from: percent, up: up)
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MixTheme.textPrimary)
                .frame(width: 40, height: 40)
                .background(MixTheme.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .buttonRepeatBehavior(.enabled)
    }
}
