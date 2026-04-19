import SwiftUI

struct AppLogoView: View {
    let size: CGFloat
    var cornerRadius: CGFloat? = nil

    var body: some View {
        Image("AppLogo", bundle: .module)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius ?? size * 0.22,
                    style: .continuous
                )
            )
    }
}
