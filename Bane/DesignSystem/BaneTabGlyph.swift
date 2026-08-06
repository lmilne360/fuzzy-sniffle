import SwiftUI

/// The geometric icon set from the design system's `TabBar` component
/// (`components/TabBar/TabBar.jsx`) — plain rectangles/circles rather than SF
/// Symbols, so the tab bar reads as machined/graphic rather than iconographic.
enum BaneTabGlyphKind: Hashable {
    /// Three ascending-then-short bars — mirrors the app icon's bar motif.
    case bars
    /// A 2×2 grid of squares.
    case grid
    /// Three horizontal rules, the last shorter — a list/plan silhouette.
    case list
    /// A rotated square (rhombus).
    case diamond
    /// Three dots in a row.
    case dots
}

/// Renders one ``BaneTabGlyphKind`` as a template `Image` — the native
/// counterpart to the design system's inline-SVG `GLYPHS` map (an 18×18 unit
/// box).
///
/// Goes through `ImageRenderer` to a bitmap rather than composing shapes
/// directly: `UITabBar` snapshots tab-item icons to a bitmap for its own
/// chrome, and a live composed view (`ZStack` of offset shapes, even at a
/// fixed size) renders blank in that pass. A pre-rendered template `Image` is
/// the reliable path for a custom tab icon.
struct BaneTabGlyph: View {
    var kind: BaneTabGlyphKind
    var size: CGFloat = 22

    var body: some View {
        Image(uiImage: Self.image(for: kind, size: size))
            .renderingMode(.template)
    }

    @MainActor
    private static var cache: [BaneTabGlyphKind: UIImage] = [:]

    @MainActor
    private static func image(for kind: BaneTabGlyphKind, size: CGFloat) -> UIImage {
        if let cached = cache[kind] { return cached }
        let renderer = ImageRenderer(content: GlyphMask(kind: kind).frame(width: size, height: size))
        renderer.scale = 3
        let image = (renderer.uiImage ?? UIImage()).withRenderingMode(.alwaysTemplate)
        cache[kind] = image
        return image
    }
}

/// The opaque-black shape composition rendered to a bitmap by
/// ``BaneTabGlyph``; only the alpha channel matters since the resulting image
/// is used in `.template` rendering mode.
private struct GlyphMask: View {
    let kind: BaneTabGlyphKind

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / 18
            content(scale: scale)
                .foregroundStyle(.black)
        }
    }

    @ViewBuilder
    private func content(scale: CGFloat) -> some View {
        switch kind {
        case .bars:
            ZStack(alignment: .topLeading) {
                bar(x: 2, y: 6, w: 3, h: 6, scale: scale)
                bar(x: 7, y: 2, w: 3, h: 14, scale: scale)
                bar(x: 12, y: 8, w: 3, h: 4, scale: scale)
            }
        case .grid:
            ZStack(alignment: .topLeading) {
                bar(x: 2, y: 2, w: 5.5, h: 5.5, scale: scale, cornerRadius: 0)
                bar(x: 10.5, y: 2, w: 5.5, h: 5.5, scale: scale, cornerRadius: 0)
                bar(x: 2, y: 10.5, w: 5.5, h: 5.5, scale: scale, cornerRadius: 0)
                bar(x: 10.5, y: 10.5, w: 5.5, h: 5.5, scale: scale, cornerRadius: 0)
            }
        case .list:
            ZStack(alignment: .topLeading) {
                bar(x: 2, y: 3, w: 14, h: 2.4, scale: scale, cornerRadius: 0)
                bar(x: 2, y: 7.8, w: 14, h: 2.4, scale: scale, cornerRadius: 0)
                bar(x: 2, y: 12.6, w: 9, h: 2.4, scale: scale, cornerRadius: 0)
            }
        case .diamond:
            Rectangle()
                .frame(width: 10 * scale, height: 10 * scale)
                .rotationEffect(.degrees(45))
                .position(x: 9 * scale, y: 8.57 * scale)
        case .dots:
            ZStack(alignment: .topLeading) {
                dot(cx: 3.5, cy: 9, r: 1.8, scale: scale)
                dot(cx: 9, cy: 9, r: 1.8, scale: scale)
                dot(cx: 14.5, cy: 9, r: 1.8, scale: scale)
            }
        }
    }

    private func bar(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, scale: CGFloat, cornerRadius: CGFloat = 1) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius * scale, style: .continuous)
            .frame(width: w * scale, height: h * scale)
            .offset(x: x * scale, y: y * scale)
    }

    private func dot(cx: CGFloat, cy: CGFloat, r: CGFloat, scale: CGFloat) -> some View {
        Circle()
            .frame(width: r * 2 * scale, height: r * 2 * scale)
            .offset(x: (cx - r) * scale, y: (cy - r) * scale)
    }
}
