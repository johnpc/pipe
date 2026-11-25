import SwiftUI

/// Row sizing per size class. A phone row (100-pt thumbnail, caption type)
/// stretched across an iPad column reads as a toy; regular width gets a
/// larger thumbnail, body type, and more breathing room. Pure, so it is tested.
struct RowMetrics: Equatable {
    let thumbWidth: CGFloat
    let thumbHeight: CGFloat
    let titleFont: Font
    let metaFont: Font
    let captionFont: Font
    let rowPadding: CGFloat
    /// Wide rows put the title beside the art (the phone stacks it underneath).
    let titleBesideArt: Bool

    static let compact = RowMetrics(thumbWidth: 100, thumbHeight: 56, titleFont: .subheadline, metaFont: .caption,
                                    captionFont: .caption2, rowPadding: 8, titleBesideArt: false)
    static let regular = RowMetrics(thumbWidth: 176, thumbHeight: 99, titleFont: .body, metaFont: .subheadline,
                                    captionFont: .footnote, rowPadding: 12, titleBesideArt: true)
    /// Detail header art: a square chip on the phone, 16:9 on a wide screen.
    static func headerArt(_ sizeClass: UserInterfaceSizeClass?) -> CGSize {
        sizeClass == .regular ? CGSize(width: 240, height: 135) : CGSize(width: 100, height: 100)
    }

    static func forSizeClass(_ sizeClass: UserInterfaceSizeClass?) -> RowMetrics {
        sizeClass == .regular ? regular : compact
    }

    /// Widest a column of prose or a detail page should run on a wide screen.
    static let readableWidth: CGFloat = 820
}
