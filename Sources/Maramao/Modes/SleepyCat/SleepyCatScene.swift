import SwiftUI

/// One screen of "Non svegliare il gatto", laid out like a modal over a blurred desktop:
/// the countdown on top, a big landscape photo of the cat in the middle, and under it what
/// the cat has to say. The countdown is on the main screen only.
struct SleepyCatScene: View {
    @ObservedObject var model: SleepyCatModel
    let context: BreakContext
    let isMain: Bool

    var body: some View {
        GeometryReader { geo in
            let photoSize = Self.photoSize(in: geo.size)
            ZStack {
                ModalBackdrop(dim: 0.5)
                VStack(spacing: 24) {
                    ZStack {
                        SleepyCatPhoto(image: model.sleepingPhoto, size: photoSize)
                            .opacity(model.phase == .asleep ? 1 : 0)
                        SleepyCatPhoto(image: model.angryPhoto, size: photoSize)
                            .opacity(model.phase == .awake ? 1 : 0)
                    }
                    .frame(width: photoSize.width, height: photoSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
                    // The line swaps in place, with no animation: the cat snaps at once.
                    // A fixed-height slot, so a line that wraps never moves the photo.
                    SleepyCatCaption(line: model.line, angry: model.phase == .awake)
                        .frame(maxWidth: photoSize.width)
                        .frame(height: Self.captionHeight, alignment: .top)
                        .transaction { $0.animation = nil }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                // Nothing here takes clicks. A portrait photo filling the card is clipped
                // only when drawn: it still covered the countdown above it and ate the
                // clicks on "Chiudi".
                .allowsHitTesting(false)
                // The countdown and its "Chiudi" are pinned to the top and drawn last, as
                // in the other modes, so nothing can sit over the button.
                if isMain {
                    VStack {
                        BreakHUD(context: context)
                        Spacer()
                    }
                    .padding(.top, 44)
                }
            }
        }
        // Waking up is instant, falling asleep again is a short fade.
        .animation(model.phase == .awake ? nil : .easeInOut(duration: 0.4), value: model.phase)
        .ignoresSafeArea()
    }

    /// Room for a caption of up to two lines.
    static let captionHeight: CGFloat = 80

    /// A 3:2 landscape card, as big as fits with room for the countdown and the caption.
    static func photoSize(in screen: CGSize) -> CGSize {
        let maxWidth = screen.width * 0.62
        let maxHeight = max(200, screen.height - 340)
        let width = min(maxWidth, maxHeight * 1.5)
        return CGSize(width: width, height: width / 1.5)
    }
}

/// A photo filling its landscape card. Portrait photos are cropped to the card, never shown
/// with bars on the sides.
struct SleepyCatPhoto: View {
    let image: NSImage?
    let size: CGSize

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                // No photos in this build (`swift run`): an empty card, so the layout holds.
                Color.white.opacity(0.06)
                    .frame(width: size.width, height: size.height)
            }
        }
        .accessibilityHidden(true)
    }
}

/// What the cat says, in a pill like the countdown's, under the photo.
struct SleepyCatCaption: View {
    let line: String
    let angry: Bool

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Text(line)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(background)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var background: some View {
        if contrast == .increased || reduceTransparency {
            Capsule()
                .fill(Color.black)
                .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.black.opacity(0.55)))
        }
    }
}
