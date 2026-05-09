import SwiftUI
import UIKit

enum Theme {
    static let accent = Color("AccentColor")
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let subtle = Color(UIColor.tertiaryLabel)

    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let stackSpacing: CGFloat = 16
}

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}
