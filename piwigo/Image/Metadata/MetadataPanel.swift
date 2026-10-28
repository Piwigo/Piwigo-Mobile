//
//  MetadataPanel.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  State and geometry of the panel (iPhone) or of the card (iPad) presenting the metadata
//  of the photo or video shown by ImageViewController.
//

import UIKit

// MARK: - Panel State
/// The panel moves between states. A state where the table covers the photo
/// will be added with the sections presenting the metadata.
enum MetadataPanelState {
    case closed
    case half
}

/// Everything the panel needs to remember
final class MetadataPanel {
    var state: MetadataPanelState = .closed
    var isPresented: Bool { return state != .closed }
    var animator: UIViewPropertyAnimator?
    var panGesture: UIPanGestureRecognizer?

    // Views
    var viewController: ImageMetadataViewController?
    var panelView: UIView?

    // Layout
    var isSideBySide = false
    var portraitConstraints = [NSLayoutConstraint]()
    var sideConstraints = [NSLayoutConstraint]()
    var heightConstraint: NSLayoutConstraint?
    var widthConstraint: NSLayoutConstraint?
    var containerBottom: NSLayoutConstraint?
    var containerTrailing: NSLayoutConstraint?

    // Bars hidden by the panel and restored when it closes
    var navigationBarWasHidden = false

    // Distance covered by a drag between the closed and the open states
    var travel = CGFloat.zero
    
    // State the panel is moving to: the pages are laid out for it
    var target: MetadataPanelState = .closed
    
    // iPad: card floating over the photo
    static var lastCardCorner = MetadataCardView.Corner.topRight
    var card: MetadataCardView?
    var cardViewController: ImageMetadataViewController?
    var cardCorner: MetadataCardView.Corner {
        get { return Self.lastCardCorner }
        set { Self.lastCardCorner = newValue }
    }
    var isCardSuspended = false         // Hidden while the photo has no location
    var isDraggingCard = false
    var cardDragStart = CGPoint.zero
    
    // Page turns
    var isPageTurning = false
    var didCloseForPageTurn = false
    var needsPageCacheReset = false
}

/// Dimensions of the panel for a given size of the view
struct MetadataGeometry {
    let isSideBySide: Bool
    let panelLength: CGFloat        // Height (portrait) or width (side by side) of the panel
    let containerInset: CGFloat     // Space taken from the photo container
}


// MARK: - Pages Kept in Memory
extension UIViewController {
    /// Gives the view of a page the size of the page view controller presenting it, and lays it out.
    /// The page view controller only does so once the page is shown.
    @MainActor
    func fitViewToPageContainer() {
        guard let size = (parent as? UIPageViewController)?.view.bounds.size,
              size != .zero, isViewLoaded, view.bounds.size != size
        else { return }
        view.frame.size = size
        view.layoutIfNeeded()
    }
}
