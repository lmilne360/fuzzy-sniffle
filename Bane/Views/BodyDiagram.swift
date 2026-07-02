import SwiftUI

/// A single paintable muscle region on a body diagram, positioned in a unit
/// coordinate space (0...1 on both axes, origin top-left) so the layout scales
/// to any frame. Several regions may map to the same ``Muscle`` (e.g. left and
/// right sides) — they simply share that muscle's intensity.
struct BodyRegion: Identifiable {
    let id = UUID()
    let muscle: Muscle
    /// Position and size within the body canvas, in unit (0...1) coordinates.
    let rect: CGRect

    init(_ muscle: Muscle, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.muscle = muscle
        self.rect = CGRect(x: x, y: y, width: width, height: height)
    }
}

/// A stylized front/back human figure whose muscle regions are tinted by a
/// caller-supplied intensity (0...1). Deliberately schematic — capsule "muscle
/// blocks" over a faint silhouette — rather than anatomically precise, so it
/// stays legible at thumbnail size and needs no image assets.
struct BodyDiagram: View {
    let regions: [BodyRegion]
    /// Normalized training intensity for a muscle, 0 (untrained) ... 1 (top).
    let intensity: (Muscle) -> Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                silhouette(in: size)

                ForEach(regions) { region in
                    Capsule(style: .continuous)
                        .fill(MuscleHeatMap.heatColor(for: intensity(region.muscle)))
                        .frame(
                            width: region.rect.width * size.width,
                            height: region.rect.height * size.height
                        )
                        .position(
                            x: region.rect.midX * size.width,
                            y: region.rect.midY * size.height
                        )
                        .accessibilityLabel(region.muscle.displayName)
                }
            }
        }
    }

    /// A faint head + torso + limb outline drawn behind the muscle blocks so
    /// the figure reads as a body rather than floating capsules.
    private func silhouette(in size: CGSize) -> some View {
        let color = Color(.systemGray4).opacity(0.35)
        return ZStack {
            // Head
            Circle()
                .fill(color)
                .frame(width: 0.16 * size.width, height: 0.16 * size.width)
                .position(x: 0.5 * size.width, y: 0.07 * size.height)
            // Torso
            Capsule(style: .continuous)
                .fill(color)
                .frame(width: 0.44 * size.width, height: 0.40 * size.height)
                .position(x: 0.5 * size.width, y: 0.36 * size.height)
            // Arms
            capsuleLimb(color, x: 0.20, y: 0.36, w: 0.12, h: 0.34, in: size)
            capsuleLimb(color, x: 0.80, y: 0.36, w: 0.12, h: 0.34, in: size)
            // Legs
            capsuleLimb(color, x: 0.40, y: 0.74, w: 0.15, h: 0.44, in: size)
            capsuleLimb(color, x: 0.60, y: 0.74, w: 0.15, h: 0.44, in: size)
        }
    }

    private func capsuleLimb(
        _ color: Color, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, in size: CGSize
    ) -> some View {
        Capsule(style: .continuous)
            .fill(color)
            .frame(width: w * size.width, height: h * size.height)
            .position(x: x * size.width, y: y * size.height)
    }
}

// MARK: - Region layouts

extension BodyDiagram {
    /// Muscle regions visible from the front, laid out over the silhouette.
    static let frontRegions: [BodyRegion] = [
        // Shoulders (deltoids)
        BodyRegion(.shoulders, 0.24, 0.20, 0.16, 0.08),
        BodyRegion(.shoulders, 0.60, 0.20, 0.16, 0.08),
        // Chest
        BodyRegion(.chest, 0.31, 0.25, 0.17, 0.09),
        BodyRegion(.chest, 0.52, 0.25, 0.17, 0.09),
        // Biceps
        BodyRegion(.biceps, 0.18, 0.31, 0.10, 0.13),
        BodyRegion(.biceps, 0.72, 0.31, 0.10, 0.13),
        // Forearms
        BodyRegion(.forearms, 0.15, 0.46, 0.09, 0.15),
        BodyRegion(.forearms, 0.76, 0.46, 0.09, 0.15),
        // Obliques
        BodyRegion(.obliques, 0.34, 0.38, 0.07, 0.14),
        BodyRegion(.obliques, 0.59, 0.38, 0.07, 0.14),
        // Abs
        BodyRegion(.abs, 0.43, 0.37, 0.14, 0.16),
        // Quads
        BodyRegion(.quads, 0.35, 0.58, 0.13, 0.20),
        BodyRegion(.quads, 0.52, 0.58, 0.13, 0.20),
    ]

    /// Muscle regions visible from the back.
    static let backRegions: [BodyRegion] = [
        // Traps
        BodyRegion(.traps, 0.40, 0.17, 0.20, 0.08),
        // Shoulders (rear delts)
        BodyRegion(.shoulders, 0.24, 0.22, 0.14, 0.07),
        BodyRegion(.shoulders, 0.62, 0.22, 0.14, 0.07),
        // Upper back
        BodyRegion(.upperBack, 0.35, 0.25, 0.30, 0.08),
        // Lats
        BodyRegion(.lats, 0.31, 0.33, 0.13, 0.12),
        BodyRegion(.lats, 0.56, 0.33, 0.13, 0.12),
        // Triceps
        BodyRegion(.triceps, 0.18, 0.31, 0.10, 0.13),
        BodyRegion(.triceps, 0.72, 0.31, 0.10, 0.13),
        // Forearms
        BodyRegion(.forearms, 0.15, 0.46, 0.09, 0.15),
        BodyRegion(.forearms, 0.76, 0.46, 0.09, 0.15),
        // Glutes
        BodyRegion(.glutes, 0.37, 0.52, 0.12, 0.09),
        BodyRegion(.glutes, 0.51, 0.52, 0.12, 0.09),
        // Hamstrings
        BodyRegion(.hamstrings, 0.36, 0.62, 0.12, 0.16),
        BodyRegion(.hamstrings, 0.52, 0.62, 0.12, 0.16),
        // Calves
        BodyRegion(.calves, 0.37, 0.80, 0.11, 0.14),
        BodyRegion(.calves, 0.52, 0.80, 0.11, 0.14),
    ]
}

#Preview {
    HStack {
        BodyDiagram(regions: BodyDiagram.frontRegions) { muscle in
            muscle == .chest || muscle == .quads ? 1.0 : 0.4
        }
        .aspectRatio(0.5, contentMode: .fit)
        BodyDiagram(regions: BodyDiagram.backRegions) { muscle in
            muscle == .lats ? 0.9 : 0.2
        }
        .aspectRatio(0.5, contentMode: .fit)
    }
    .padding()
}
