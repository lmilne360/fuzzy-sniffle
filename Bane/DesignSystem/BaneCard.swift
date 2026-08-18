import SwiftUI

/// Surface container matching `.bn-card`: a hairline-bordered surface with an
/// optional uppercase title/meta header row and a top venom hairline for
/// "accented" cards (mirrors `.bn-card--accent`).
struct BaneCard<Content: View>: View {
    var title: String?
    var meta: String?
    var accented: Bool = false
    var raised: Bool = false
    /// Transparent background, still bordered (mirrors `.bn-card--outline`).
    /// Takes precedence over `raised` if both are set, matching the spec's CSS cascade.
    var outline: Bool = false
    @ViewBuilder var content: Content

    @Environment(\.banePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if accented {
                palette.accent.frame(height: 1)
            }
            if title != nil || meta != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title).baneHeading(13).foregroundStyle(palette.text)
                    }
                    Spacer(minLength: 12)
                    if let meta {
                        Text(meta)
                            .font(BaneFont.mono(11))
                            .tracking(1.0)
                            .textCase(.uppercase)
                            .foregroundStyle(palette.text3)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                Rectangle().fill(palette.line).frame(height: 1)
            }
            content
                .padding(18)
        }
        .background(outline ? Color.clear : (raised ? palette.surface2 : palette.surface))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 1)
        )
    }
}
