import SwiftUI

/// One screen of "Non svegliare il gatto": a full-screen photo of a sleeping cat, or of an
/// angry one when the user touches something. The main screen also gets the HUD.
struct SleepyCatScene: View {
    @ObservedObject var model: SleepyCatModel
    let context: BreakContext
    let isMain: Bool

    var body: some View {
        ZStack {
            Color.black
            if model.phase == .asleep {
                SleepyCatPhoto(image: model.sleepingPhoto, fallback: "😴")
                    .transition(.opacity)
            } else {
                SleepyCatPhoto(image: model.angryPhoto, fallback: "😾")
                    // A new angry cat every time: identity changes with the photo.
                    .id(model.angryPhoto.map { ObjectIdentifier($0) })
                    .transition(.opacity)
            }
            if isMain {
                VStack {
                    BreakHUD(context: context)
                    Spacer()
                }
                .padding(.top, 44)
            }
        }
        // Waking up is instant, falling asleep again is slow.
        .animation(.easeInOut(duration: model.phase == .awake ? 0.12 : 0.9), value: model.phase)
        .ignoresSafeArea()
    }
}

/// A photo filling the screen. When its shape is far from the screen's (a portrait photo on a
/// wide display), the whole photo is shown over a blurred, zoomed copy of itself instead of
/// cropping the cat's head off.
struct SleepyCatPhoto: View {
    let image: NSImage?
    let fallback: String

    var body: some View {
        GeometryReader { geo in
            if let image {
                let screenAspect = geo.size.width / max(geo.size.height, 1)
                let photoAspect = image.size.width / max(image.size.height, 1)
                let fills = photoAspect / screenAspect > 0.75
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: fills ? 0 : 40)
                    if !fills {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            } else {
                Text(verbatim: fallback)
                    .font(.system(size: min(geo.size.width, geo.size.height) * 0.3))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .accessibilityHidden(true)
    }
}
