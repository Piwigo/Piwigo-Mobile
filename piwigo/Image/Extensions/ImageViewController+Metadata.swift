//
//  ImageViewController+Metadata.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Presents the metadata of the photo or video (for the time being, its location)
//  - on iPad, in a card floating over the photo, which the user moves to any corner,
//  - on iPhone, in a panel sharing the screen with the photo: below it in portrait orientation,
//    on its right in landscape orientation. The panel is a child view controller whose size
//    is taken from the photo container by changing the constants of the storyboard constraints.
//

import UIKit
import CoreLocation
import PwgKit
import PwgCacheKit
import PwgUIKit

// MARK: - Info Button
extension ImageViewController {
    /// Photos and videos shot with a device knowing its position
    func metadataCoordinate(of image: Image?) -> CLLocationCoordinate2D? {
        guard supportsMetadata(image),
              let image = image, image.latitude != 0.0, image.longitude != 0.0
        else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: image.latitude, longitude: image.longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    /// Metadata are presented for photos and videos, whether they contain any or not
    func supportsMetadata(_ image: Image?) -> Bool {
        guard let image = image else { return false }
        return image.isPDF == false
    }

    @MainActor
    func getInfoBarButton() -> UIBarButtonItem? {
        guard supportsMetadata(imageData) else { return nil }
        return UIBarButtonItem.infoImageButton(isShown: isMetadataShown, target: self,
                                               action: #selector(toggleMetadata))
    }

    /// The icon is filled while the metadata are presented
    @MainActor
    func updateInfoButtonImage() {
        infoBarButton?.image = UIImage(systemName: isMetadataShown ? "info.circle.fill" : "info.circle")
    }

    @MainActor
    var isMetadataShown: Bool {
        if traitCollection.userInterfaceIdiom == .pad {
            return metadataPanel.card != nil
        }
        return metadataPanel.isPresented
    }

    /// The toolbar of an iPhone in portrait orientation follows the navigation bar,
    /// except while the panel is presented: it is then the way to close the panel.
    @MainActor
    var shouldHideToolbar: Bool {
        return (navigationController?.isNavigationBarHidden ?? false) && metadataPanel.isPresented == false
    }

    @MainActor
    @objc func toggleMetadata() {
        if traitCollection.userInterfaceIdiom == .pad {
            if metadataPanel.card != nil {
                dismissMetadataCard()
            } else {
                presentMetadataCard()
            }
        } else {
            setMetadataState(metadataPanel.isPresented ? .closed : .half, animated: true)
        }
    }

    /// Height of the table presenting the metadata of the photo or video
    @MainActor
    var metadataContentHeight: CGFloat {
        let panel = metadataPanel
        if let metadataVC = panel.cardViewController ?? panel.viewController {
            return metadataVC.contentHeight
        }
        return ImageMetadataViewController.preferredContentHeight(hasLocation: metadataCoordinate(of: imageData) != nil)
    }

    /// Presents the location, the EXIF, the GPS and the IPTC metadata of the photo or video in the table
    @MainActor
    func configureMetadata(of metadataVC: ImageMetadataViewController) {
        metadataVC.onContentChange = { [weak self] in self?.metadataContentDidChange() }
        metadataVC.configure(with: metadataCoordinate(of: imageData))
        loadMetadata(into: metadataVC)
    }

    /// Reads the EXIF, GPS, IPTC and WebP metadata of the files in cache, which keep those of the original
    @MainActor
    private func loadMetadata(into metadataVC: ImageMetadataViewController, force: Bool = false) {
        guard supportsMetadata(imageData) else {
            metadataVC.metadataImageID = nil
            metadataVC.clearMetadata()
            return
        }
        let imageID = imageData.pwgID
        guard force || metadataVC.metadataImageID != imageID else { return }

        // Files in cache, from the largest to the smallest
        let urls = pwgImageSize.allCases.sorted { $0.rawValue > $1.rawValue }
            .compactMap { imageData.cacheURL(ofSize: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard urls.isEmpty == false else {
            /// No file in cache yet: the metadata are looked for again when one arrives
            metadataVC.metadataImageID = nil
            metadataVC.clearMetadata()
            return
        }
        metadataVC.metadataImageID = imageID
        metadataVC.metadataLoadNumber += 1
        let loadNumber = metadataVC.metadataLoadNumber

        // Metadata already read?
        if let cached = ImageMetadata.cached(in: urls) {
            present(cached, in: metadataVC)
            return
        }

        // Read the files in the background
        if force == false {
            metadataVC.clearMetadata(keepingHeight: true)
        }
        Task { [weak metadataVC] in
            let metadata = await Task.detached(priority: .userInitiated) {
                ImageMetadata.read(in: urls)
            }.value
            /// Readings overlap, e.g. when a file is downloaded while the previous ones are read:
            /// a reading started earlier may end later and must not replace the last one.
            guard let metadataVC = metadataVC, metadataVC.metadataImageID == imageID,
                  metadataVC.metadataLoadNumber == loadNumber else { return }
            present(metadata, in: metadataVC)
        }
    }

    /// The smaller files of an image may have lost their metadata, which only the file shown
    /// by the page is sure to keep: while that file is being downloaded, a file without metadata
    /// does not tell that the image has none.
    @MainActor
    private func present(_ metadata: ImageMetadata, in metadataVC: ImageMetadataViewController) {
        if metadata.isEmpty, isFileOfPageMissing {
            metadataVC.clearMetadata(keepingHeight: true)
        } else {
            metadataVC.configure(metadata, noteAboutSize: metadata.isEmpty && isLargestFileBelowOriginal)
        }
    }

    /// The largest file in cache is not the original: a file without metadata may have lost them,
    /// which the table explains below its "No metadata" cell.
    @MainActor
    private var isLargestFileBelowOriginal: Bool {
        guard imageData.hasFullResThumbnail else { return false }
        let largest = pwgImageSize.allCases.sorted { $0.rawValue > $1.rawValue }.first {
            imageData.cacheURL(ofSize: $0).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        }
        return largest.map { $0 < .fullRes } ?? false
    }

    /// The file the current page shows is not in cache yet
    @MainActor
    private var isFileOfPageMissing: Bool {
        let size: pwgImageSize
        switch pageViewController?.viewControllers?.first {
        case let page as ImageDetailViewController where page.imageData?.pwgID == imageData.pwgID:
            size = page.previewSize
        case let page as GifDetailViewController where page.imageData?.pwgID == imageData.pwgID:
            size = .fullRes
        default:
            return false
        }
        guard let url = imageData.cacheURL(ofSize: size) else { return false }
        return FileManager.default.fileExists(atPath: url.path) == false
    }

    /// A file of the image has just been downloaded: it may hold metadata the table does not show yet
    @MainActor
    func metadataFilesDidChange(of image: Image?) {
        guard let image = image, image.pwgID == imageData.pwgID, supportsMetadata(image) else { return }
        let panel = metadataPanel
        if let metadataVC = panel.cardViewController {
            loadMetadata(into: metadataVC, force: true)
        } else if panel.state == .half, let metadataVC = panel.viewController {
            loadMetadata(into: metadataVC, force: true)
        }
    }

    /// The panel or the card follows the height of the table, e.g. when more metadata are shown
    @MainActor
    func metadataContentDidChange() {
        let panel = metadataPanel
        // iPad: only the card changes, the photo and its page are left alone
        /// A layout of the whole view inside the animation would animate the pages being laid out.
        if let card = panel.card {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.layoutMetadataCard()
                card.layoutIfNeeded()
            }
            return
        }
        guard panel.state == .half && panel.animator == nil else { return }
        
        // iPhone: nothing to animate if the panel keeps its size, e.g. when turning pages
        let geometry = metadataGeometry(for: view.bounds.size)
        let current = geometry.isSideBySide ? panel.widthConstraint?.constant : panel.heightConstraint?.constant
        guard current != geometry.panelLength else { return }
        
        // Layouts pending, such as the one of a page just turned, must not be part of the animation
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.updateMetadataLayoutIfNeeded()
            self.view.layoutIfNeeded()
        }
    }

    /// Keeps the panel in line with the photo or video being presented
    @MainActor
    func refreshMetadata() {
        // iPad: the card follows the photo, and waits while the photo has no metadata to present
        if metadataPanel.card != nil {
            if supportsMetadata(imageData) {
                if let metadataVC = metadataPanel.cardViewController { configureMetadata(of: metadataVC) }
                setMetadataCardSuspended(false)
                layoutMetadataCard()
            } else {
                setMetadataCardSuspended(true)
            }
            return
        }

        // iPhone: close the panel if the file has no metadata to present
        guard metadataPanel.state == .half, metadataPanel.animator == nil else { return }
        if supportsMetadata(imageData) {
            if let metadataVC = metadataPanel.viewController { configureMetadata(of: metadataVC) }
            view.setNeedsLayout()
        } else {
            setMetadataState(.closed, animated: true)
        }
    }
}


// MARK: - iPad Floating Card
extension ImageViewController {
    @MainActor
    func presentMetadataCard() {
        let panel = metadataPanel
        guard panel.card == nil, supportsMetadata(imageData) else { return }
        
        // Table presenting the metadata, in a card above the photo
        guard let metadataVC = storyboard?.instantiateViewController(withIdentifier: "ImageMetadataViewController") as? ImageMetadataViewController
        else { preconditionFailure("Could not load ImageMetadataViewController") }
        configureMetadata(of: metadataVC)
        addChild(metadataVC)
        let card = MetadataCardView(contentView: metadataVC.view)
        card.onClose = { [weak self] in self?.dismissMetadataCard() }
        card.panGesture.addTarget(self, action: #selector(didPanMetadataCard(_:)))
        view.addSubview(card)
        metadataVC.didMove(toParent: self)
        panel.card = card
        panel.cardViewController = metadataVC
        panel.isCardSuspended = false
        
        // Appear in the corner where the user left it
        let frame = metadataCardFrame(for: panel.cardCorner)
        card.bounds = CGRect(origin: .zero, size: frame.size)
        card.center = CGPoint(x: frame.midX, y: frame.midY)
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState]) {
            card.alpha = 1
            card.transform = .identity
        }
        updateInfoButtonImage()
    }
    
    @MainActor
    func dismissMetadataCard() {
        let panel = metadataPanel
        guard let card = panel.card, let metadataVC = panel.cardViewController else { return }
        panel.card = nil
        panel.cardViewController = nil
        panel.isCardSuspended = false
        panel.isDraggingCard = false
        updateInfoButtonImage()
        
        metadataVC.willMove(toParent: nil)
        UIView.animate(withDuration: 0.2, animations: {
            card.alpha = 0
            card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }, completion: { _ in
            card.removeFromSuperview()
            metadataVC.removeFromParent()
        })
    }
    
    /// The card disappears while the photo has no location and comes back with the next one that has
    @MainActor
    func setMetadataCardSuspended(_ suspended: Bool) {
        let panel = metadataPanel
        guard let card = panel.card, panel.isCardSuspended != suspended else { return }
        panel.isCardSuspended = suspended
        card.isUserInteractionEnabled = !suspended
        UIView.animate(withDuration: 0.2) {
            card.alpha = suspended ? 0 : 1
        }
    }
    
    /// Frame of the card in a corner of the area left free by the bars
    @MainActor
    func metadataCardFrame(for corner: MetadataCardView.Corner) -> CGRect {
        let margin: CGFloat = 16
        let insets = view.safeAreaInsets
        let availableWidth = view.bounds.width - insets.left - insets.right - 2 * margin
        let availableHeight = view.bounds.height - insets.top - insets.bottom - 2 * margin
        let width = min(MetadataCardView.width, availableWidth)
        let height = min(MetadataCardView.preferredHeight(contentHeight: metadataContentHeight), availableHeight)
        let minX = insets.left + margin
        let maxX = view.bounds.width - insets.right - margin - width
        let minY = insets.top + margin
        let maxY = view.bounds.height - insets.bottom - margin - height
        switch corner {
        case .topLeft:      return CGRect(x: minX, y: minY, width: width, height: height)
        case .topRight:     return CGRect(x: maxX, y: minY, width: width, height: height)
        case .bottomLeft:   return CGRect(x: minX, y: maxY, width: width, height: height)
        case .bottomRight:  return CGRect(x: maxX, y: maxY, width: width, height: height)
        }
    }
    
    /// Keeps the card in its corner during rotations and when the bars come and go
    @MainActor
    func layoutMetadataCard() {
        let panel = metadataPanel
        guard let card = panel.card, panel.isDraggingCard == false else { return }
        let frame = metadataCardFrame(for: panel.cardCorner)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if card.bounds.size != frame.size { card.bounds = CGRect(origin: .zero, size: frame.size) }
        if card.center != center { card.center = center }
    }
    
    /// The card follows the finger, then settles in the nearest corner
    @MainActor
    @objc func didPanMetadataCard(_ gesture: UIPanGestureRecognizer) {
        let panel = metadataPanel
        guard let card = panel.card else { return }
        switch gesture.state {
        case .began:
            panel.isDraggingCard = true
            panel.cardDragStart = card.center
            
        case .changed:
            let translation = gesture.translation(in: view)
            card.center = CGPoint(x: panel.cardDragStart.x + translation.x,
                                  y: panel.cardDragStart.y + translation.y)
            
        case .ended, .cancelled, .failed:
            // Corner nearest to where the card would stop
            let velocity = gesture.velocity(in: view)
            let projected = CGPoint(x: card.center.x + 0.15 * velocity.x, y: card.center.y + 0.15 * velocity.y)
            var nearest = panel.cardCorner
            var nearestDistance = CGFloat.greatestFiniteMagnitude
            for corner in MetadataCardView.Corner.allCases {
                let frame = metadataCardFrame(for: corner)
                let distance = hypot(projected.x - frame.midX, projected.y - frame.midY)
                if distance < nearestDistance {
                    nearest = corner
                    nearestDistance = distance
                }
            }
            panel.cardCorner = nearest
            panel.isDraggingCard = false
            let frame = metadataCardFrame(for: nearest)
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5,
                           options: [.allowUserInteraction]) {
                card.center = CGPoint(x: frame.midX, y: frame.midY)
            }
            
        default:
            break
        }
    }
}


// MARK: - iPhone Panel Geometry
extension ImageViewController {
    /// Fraction of the screen height kept for the photo in portrait, whatever the height of the table
    static let minPhotoFraction: CGFloat = 0.4

    /// Portrait: the panel takes the bottom of the screen, up to 60% of its height,
    /// - up to the toolbar before iOS 26, as the toolbar remains visible,
    /// - down to the edge of the screen since iOS 26, where the toolbar floats above it.
    /// Landscape: the panel takes the right half of the screen, the photo the left half.
    @MainActor
    func metadataGeometry(for size: CGSize) -> MetadataGeometry {
        let insets = view.safeAreaInsets
        if size.width > size.height {
            let width = size.width / 2
            return MetadataGeometry(isSideBySide: true, panelLength: width, containerInset: width)
        }
        let content = metadataContentHeight
        /// The unfolded iPhone Duo is tall enough to share its height equally, whatever the content
        let isDuoUnfolded = traitCollection.userInterfaceIdiom == .phone && traitCollection.hasRegularWidthAndHeight
        let panelFraction = isDuoUnfolded ? 0.5 : 1 - Self.minPhotoFraction
        if #available(iOS 26.0, *) {
            let height = isDuoUnfolded ? panelFraction * size.height
                                       : min(content + insets.bottom, panelFraction * size.height)
            return MetadataGeometry(isSideBySide: false, panelLength: height, containerInset: height)
        } else {
            let height = isDuoUnfolded ? panelFraction * size.height - insets.bottom
                                       : min(content, panelFraction * size.height - insets.bottom)
            return MetadataGeometry(isSideBySide: false, panelLength: height,
                                    containerInset: height + insets.bottom)
        }
    }

    /// Size left to a photo for a given size of the window
    @MainActor
    func photoAreaSize(forWindowSize size: CGSize) -> CGSize {
        guard metadataPanel.target != .closed, traitCollection.userInterfaceIdiom != .pad
        else { return size }
        let geometry = metadataGeometry(for: size)
        if geometry.isSideBySide {
            return CGSize(width: size.width - geometry.containerInset, height: size.height)
        }
        return CGSize(width: size.width, height: size.height - geometry.containerInset)
    }

    /// A photo fills its area while the panel shares the screen
    @MainActor
    var photoFillsArea: Bool {
        return metadataPanel.target != .closed && traitCollection.userInterfaceIdiom != .pad
    }
    
    /// Tells the current page that the area available to the photo has changed
    @MainActor
    func updatePhotoArea(isPanelOpen: Bool? = nil) {
        guard let size = pageViewController?.view.bounds.size else { return }
        let fillsArea = isPanelOpen ?? photoFillsArea
        switch pageViewController?.viewControllers?.first {
        case let imageDVC as ImageDetailViewController:
            imageDVC.updateViewSize(size, fillsArea: fillsArea)
        case let gifDVC as GifDetailViewController:
            gifDVC.updateViewSize(size, fillsArea: fillsArea)
        case let videoDVC as VideoDetailViewController:
            videoDVC.updateViewSize(fillsArea: fillsArea)
        default:
            break
        }
    }

    /// Sets the constants of the constraints and the position of the panel for a state
    @MainActor
    func applyMetadataGeometry(for state: MetadataPanelState) {
        let panel = metadataPanel
        guard let panelView = panel.panelView else { return }
        let geometry = metadataGeometry(for: view.bounds.size)
        let isOpen = (state != .closed)
        let direction: CGFloat = view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? -1 : 1

        // Size of the panel and of the photo container
        /// Only changed values are set, as this is also called while the view is laid out.
        func set(_ constraint: NSLayoutConstraint?, to value: CGFloat) {
            if let constraint = constraint, constraint.constant != value { constraint.constant = value }
        }
        let transform: CGAffineTransform
        if geometry.isSideBySide {
            set(panel.widthConstraint, to: geometry.panelLength)
            set(panel.containerTrailing, to: isOpen ? -geometry.containerInset : 0)
            set(panel.containerBottom, to: 0)
            transform = isOpen ? .identity : CGAffineTransform(translationX: direction * geometry.panelLength, y: 0)
        } else {
            set(panel.heightConstraint, to: geometry.panelLength)
            set(panel.containerBottom, to: isOpen ? -geometry.containerInset : 0)
            set(panel.containerTrailing, to: 0)
            transform = isOpen ? .identity : CGAffineTransform(translationX: 0, y: geometry.containerInset)
        }
        if panelView.transform != transform { panelView.transform = transform }
        panel.travel = geometry.isSideBySide ? min(geometry.containerInset, 250) : geometry.containerInset
    }

    /// Keeps the panel in line with the view during rotations and changes of safe area
    @MainActor
    func updateMetadataLayoutIfNeeded() {
        let panel = metadataPanel
        layoutMetadataCard()
        guard panel.state == .half, panel.animator == nil, panel.panelView != nil
        else { return }

        // Orientation changed?
        let isSideBySide = view.bounds.width > view.bounds.height
        if isSideBySide != panel.isSideBySide {
            setMetadataLayout(sideBySide: isSideBySide)
            updateMetadataBars(for: .half)
        }
        applyMetadataGeometry(for: .half)
        
        // A page shown while the panel was open sized its photo from an estimate of the area
        /// (safe area insets may differ when it appears): set it from the real size of the container.
        updatePhotoArea(isPanelOpen: true)
    }

    @MainActor
    private func setMetadataLayout(sideBySide: Bool) {
        let panel = metadataPanel
        panel.isSideBySide = sideBySide
        NSLayoutConstraint.deactivate(sideBySide ? panel.portraitConstraints : panel.sideConstraints)
        NSLayoutConstraint.activate(sideBySide ? panel.sideConstraints : panel.portraitConstraints)
        panel.panelView?.layer.maskedCorners = sideBySide
            ? [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
}


// MARK: - iPhone Panel
extension ImageViewController {
    /// Creates the panel the first time it is needed
    @MainActor
    private func installMetadataPanel() {
        let panel = metadataPanel
        guard panel.panelView == nil else { return }

        // The photo container is pinned to the edges of the view by the storyboard
        if let container = pageViewController?.view.superview {
            panel.containerBottom = view.constraints.first {
                $0.firstItem === container && $0.firstAttribute == .bottom && $0.secondItem === view }
            panel.containerTrailing = view.constraints.first {
                $0.firstItem === container && $0.firstAttribute == .trailing && $0.secondItem === view }
        }

        // Table presenting the metadata
        guard let metadataVC = storyboard?.instantiateViewController(withIdentifier: "ImageMetadataViewController") as? ImageMetadataViewController
        else { preconditionFailure("Could not load ImageMetadataViewController") }
        panel.viewController = metadataVC
        addChild(metadataVC)

        // View hosting the table
        let panelView = UIView()
        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.backgroundColor = .clear
        panelView.clipsToBounds = true
        panelView.layer.cornerRadius = 16
        panelView.isHidden = true
        panelView.accessibilityIdentifier = "ImageMetadataPanel"
        view.addSubview(panelView)
        panel.panelView = panelView

        metadataVC.view.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(metadataVC.view)
        NSLayoutConstraint.activate([
            metadataVC.view.topAnchor.constraint(equalTo: panelView.topAnchor),
            metadataVC.view.bottomAnchor.constraint(equalTo: panelView.bottomAnchor),
            metadataVC.view.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            metadataVC.view.trailingAnchor.constraint(equalTo: panelView.trailingAnchor)
        ])
        metadataVC.didMove(toParent: self)

        // Constraints in portrait orientation
        let height = panelView.heightAnchor.constraint(equalToConstant: 0)
        panel.heightConstraint = height
        let bottomAnchor: NSLayoutYAxisAnchor
        if #available(iOS 26.0, *) {
            bottomAnchor = view.bottomAnchor
        } else {
            bottomAnchor = view.safeAreaLayoutGuide.bottomAnchor
        }
        panel.portraitConstraints = [
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: bottomAnchor),
            height
        ]

        // Constraints in landscape orientation
        let width = panelView.widthAnchor.constraint(equalToConstant: 0)
        panel.widthConstraint = width
        panel.sideConstraints = [
            panelView.topAnchor.constraint(equalTo: view.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            width
        ]
    }

    /// Gets the panel ready to appear
    @MainActor
    private func prepareMetadataPanel() {
        installMetadataPanel()
        let panel = metadataPanel
        guard let panelView = panel.panelView else { return }
        if let metadataVC = panel.viewController { configureMetadata(of: metadataVC) }

        // Layout according to the orientation
        setMetadataLayout(sideBySide: view.bounds.width > view.bounds.height)
        panelView.backgroundColor = .clear
        panelView.isHidden = false
        view.bringSubviewToFront(panelView)

        // Start from the closed position
        if panel.state == .closed {
            applyMetadataGeometry(for: .closed)
            view.layoutIfNeeded()
        }
    }

    /// Hides the navigation bar to give the top of the screen to the photo,
    /// and restores the bars when the panel closes
    @MainActor
    func updateMetadataBars(for state: MetadataPanelState) {
        guard let navController = navigationController else { return }
        let panel = metadataPanel
        if state != .closed {
            navController.setNavigationBarHidden(true, animated: true)
            // The toolbar of an iPhone in portrait orientation remains visible
            if isToolbarRequired, panel.isSideBySide == false {
                navController.setToolbarHidden(false, animated: true)
            }
        } else {
            navController.setNavigationBarHidden(panel.navigationBarWasHidden, animated: true)
            if isToolbarRequired {
                navController.setToolbarHidden(navController.isNavigationBarHidden, animated: true)
            }
        }

        // Background, status bar and description follow the navigation bar
        /// The background is only black around a photo shown full screen, without bars or panel.
        view.backgroundColor = (navController.isNavigationBarHidden && state == .closed)
            ? .black : PwgColor.background
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        if let imagePVC = pageViewController?.viewControllers?.first {
            (imagePVC as? ImageDetailViewController)?.updateDescriptionVisibility()
            (imagePVC as? GifDetailViewController)?.updateDescriptionVisibility()
            (imagePVC as? VideoDetailViewController)?.updateDescriptionControlsVisibility()
        }
    }

    /// Moves the panel to a state, with or without animation
    @MainActor
    func setMetadataState(_ state: MetadataPanelState, animated: Bool) {
        let panel = metadataPanel

        // Let a running animation reach its end first
        if let animator = panel.animator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
        guard state != panel.state else { return }
        guard state == .closed || supportsMetadata(imageData) else { return }

        let animator = makeMetadataAnimator(to: state)
        if animated {
            animator.startAnimation()
        } else {
            animator.startAnimation()
            animator.stopAnimation(false)
            animator.finishAnimation(at: .end)
        }
    }

    /// Animation between the current state and the wanted one
    /// The animator is ready to start or to be driven by a gesture.
    @MainActor
    private func makeMetadataAnimator(to target: MetadataPanelState) -> UIViewPropertyAnimator {
        let panel = metadataPanel

        // Opening: remember the bars and get the panel ready
        if panel.state == .closed {
            panel.navigationBarWasHidden = navigationController?.isNavigationBarHidden ?? false
            prepareMetadataPanel()
        }

        // Bars, icon and pages follow the wanted state straight away
        let isOpening = (target != .closed)
        panel.target = target
        panel.isSideBySide = view.bounds.width > view.bounds.height
        updateMetadataBars(for: target)
        infoBarButton?.image = UIImage(systemName: isOpening ? "info.circle.fill" : "info.circle")

        let animator = UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1.0) { [self] in
            applyMetadataGeometry(for: target)
            view.layoutIfNeeded()
            updatePhotoArea(isPanelOpen: isOpening)
        }
        animator.addCompletion { [self] position in
            // A cancelled gesture returns to the previous state
            let reachedTarget = (position == .end)
            let final: MetadataPanelState = reachedTarget ? target : (isOpening ? .closed : .half)
            commitMetadataState(final)
        }
        panel.animator = animator
        return animator
    }

    @MainActor
    private func commitMetadataState(_ state: MetadataPanelState) {
        let panel = metadataPanel
        let didChange = (panel.state != state)
        panel.animator = nil
        panel.state = state
        panel.target = state
        updateMetadataBars(for: state)
        updateInfoButtonImage()

        // The animation does not restore the constants when it ends at its start
        UIView.performWithoutAnimation {
            applyMetadataGeometry(for: state)
            view.layoutIfNeeded()
            updatePhotoArea(isPanelOpen: state != .closed)
        }
        if state == .closed {
            panel.panelView?.isHidden = true
        }
        
        // Pages kept in memory by the page view controller were laid out for the previous state:
        /// have it request new ones, laid out for this state like any page about to appear.
        if didChange, traitCollection.userInterfaceIdiom != .pad {
            if panel.isPageTurning {
                panel.needsPageCacheReset = true     // Once the pages stopped sliding
            } else {
                resetPageCache()
            }
        }
    }
    
    @MainActor
    private func resetPageCache() {
        metadataPanel.needsPageCacheReset = false
        guard let pageVC = pageViewController, let current = pageVC.viewControllers?.first else { return }
        pageVC.setViewControllers([current], direction: .forward, animated: false)
    }
    
    
    // MARK: - Page Turns
    /// Image data of a page
    @MainActor
    private func imageData(ofPage page: UIViewController?) -> Image? {
        switch page {
        case let imageDVC as ImageDetailViewController: return imageDVC.imageData
        case let gifDVC as GifDetailViewController: return gifDVC.imageData
        case let videoDVC as VideoDetailViewController: return videoDVC.imageData
        case let pdfDVC as PdfDetailViewController: return pdfDVC.imageData
        default: return nil
        }
    }
    
    /// The panel closes while the pages slide if the incoming page has nothing to present:
    /// that page is then laid out for the whole screen from the start,
    /// instead of being drawn for the panel and drawn again once the panel has closed.
    @MainActor
    func metadataPageWillTurn(to pendingPage: UIViewController?) {
        let panel = metadataPanel
        panel.isPageTurning = true
        guard panel.state == .half, traitCollection.userInterfaceIdiom != .pad,
              supportsMetadata(imageData(ofPage: pendingPage)) == false
        else { return }
        panel.didCloseForPageTurn = true
        setMetadataState(.closed, animated: true)
    }
    
    /// The user gave up turning the page: the panel returns
    @MainActor
    func metadataPageTurnWasCancelled() {
        let panel = metadataPanel
        panel.isPageTurning = false
        if panel.didCloseForPageTurn {
            panel.didCloseForPageTurn = false
            setMetadataState(.half, animated: true)
        }
        if panel.needsPageCacheReset { resetPageCache() }
    }
    
    @MainActor
    func metadataPageTurnDidComplete() {
        let panel = metadataPanel
        panel.isPageTurning = false
        panel.didCloseForPageTurn = false
        if panel.needsPageCacheReset {
            DispatchQueue.main.async { [weak self] in self?.resetPageCache() }
        }
    }
}


// MARK: - Gestures
extension ImageViewController: UIGestureRecognizerDelegate {
    /// Swiping up opens the metadata panel, swiping down closes it
    @MainActor
    func addMetadataGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPanForMetadata(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        view.addGestureRecognizer(pan)
        metadataPanel.panGesture = pan
    }

    /// Is the photo zoomed in, i.e. is its scroll view in charge of the pan?
    @MainActor
    private var isCurrentPageZoomed: Bool {
        let page = pageViewController?.viewControllers?.first
        let scrollView = (page as? ImageDetailViewController)?.scrollView
                        ?? (page as? GifDetailViewController)?.scrollView
                        ?? (page as? VideoDetailViewController)?.scrollView
        guard let scrollView = scrollView else { return false }
        return scrollView.zoomScale > scrollView.minimumZoomScale * 1.01
    }

    @MainActor
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let panel = metadataPanel

        // Swiping down returns to the album, unless the panel is open
        if gestureRecognizer is UISwipeGestureRecognizer {
            return panel.isPresented == false
        }

        // Only the iPhone presents a panel
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, pan === panel.panGesture
        else { return true }
        guard traitCollection.userInterfaceIdiom != .pad, panel.animator == nil
        else { return false }

        // The movement must be vertical
        let velocity = pan.velocity(in: view)
        guard abs(velocity.y) > abs(velocity.x) else { return false }

        if panel.isPresented {
            // A drag down closes the panel, unless the table has to scroll
            guard velocity.y > 0 else { return false }
            if let panelView = panel.panelView, let tableView = panel.viewController?.tableView,
               panelView.frame.contains(pan.location(in: view)),
               tableView.contentOffset.y > -tableView.adjustedContentInset.top + 1 {
                return false
            }
            return true
        } else {
            // A drag up opens the panel
            guard velocity.y < 0, supportsMetadata(imageData),
                  isCurrentPageZoomed == false
            else { return false }
            return true
        }
    }

    /// Touches in the panel belong to the table, except those dragging the panel down
    @MainActor
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let panel = metadataPanel
        // The floating card (iPad) handles its own touches
        if let card = panel.card, touch.view?.isDescendant(of: card) == true {
            return false
        }
        if let panelView = panel.panelView, panelView.isHidden == false,
           touch.view?.isDescendant(of: panelView) == true {
            return gestureRecognizer === panel.panGesture
        }
        return true
    }

    @MainActor
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // The table may bounce while the panel follows the finger
        return gestureRecognizer === metadataPanel.panGesture
            && otherGestureRecognizer.view is UIScrollView
    }

    @MainActor
    @objc func didPanForMetadata(_ gesture: UIPanGestureRecognizer) {
        let panel = metadataPanel
        switch gesture.state {
        case .began:
            let target: MetadataPanelState = panel.isPresented ? .closed : .half
            let animator = makeMetadataAnimator(to: target)
            animator.pauseAnimation()

        case .changed:
            guard let animator = panel.animator else { return }
            // Opening follows a drag up, closing a drag down
            let translation = gesture.translation(in: view).y
            let distance = (panel.isPresented ? translation : -translation)
            animator.fractionComplete = max(0, min(1, distance / max(panel.travel, 1)))

        case .ended, .cancelled, .failed:
            guard let animator = panel.animator else { return }
            let velocity = gesture.velocity(in: view).y
            let towardsTarget = panel.isPresented ? velocity : -velocity
            let shouldComplete = gesture.state == .ended
                && (towardsTarget > 500 || (animator.fractionComplete > 0.5 && towardsTarget > -500))
            animator.isReversed = !shouldComplete
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)

        default:
            break
        }
    }
}
