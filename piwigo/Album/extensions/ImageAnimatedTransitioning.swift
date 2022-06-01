//
//  ImageAnimatedTransitioning.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/09/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

//import Foundation
//import UIKit
//
//final class ImageAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
//
//    static let duration: TimeInterval = 1.25
//
//    private let type: PresentationType
//    private let firstViewController: AlbumImagesViewController
//    private let secondViewController: ImageDetailViewController
//    private let selectedCellImageViewSnapshot: UIView
//    private let cellImageViewRect: CGRect
//
//    init?(type: PresentationType,
//          firstViewController: AlbumImagesViewController,
//          secondViewController: ImageDetailViewController,
//          selectedCellImageViewSnapshot: UIView)
//    {
//        self.type = type
//        self.firstViewController = firstViewController
//        self.secondViewController = secondViewController
//        self.selectedCellImageViewSnapshot = selectedCellImageViewSnapshot
//
//        guard let window = firstViewController.view.window ?? secondViewController.view.window,
//            let selectedCell = firstViewController.selectedCell
//            else { return nil } // i.e. use default present/dismiss animation
//
//        // Get frame of image view of the cell relative to the window’s frame
//        self.cellImageViewRect = selectedCell.cellImage.convert(selectedCell.cellImage.bounds, to: window)
//    }
//
//    // Return duration
//    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
//        return Self.duration
//    }
//
//    // B2 - 13
//    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
//        // steps 18-20 will be here later.
//    }
//}
//
//enum PresentationType {
//    case present
//    case dismiss
//
//    var isPresenting: Bool {
//        return self == .present
//    }
//}
