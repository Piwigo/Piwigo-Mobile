//
//  ImageScrollView.swift
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 04/09/2021.
//

import UIKit

class ImageScrollView: UIScrollView
{
    var imageView = UIImageView()
    var playImage = UIImageView()
    private var previousScale: CGFloat = 0.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Scroll settings
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        bouncesZoom = true
        decelerationRate = .fast
        delegate = self

        maximumZoomScale = 5.0
        minimumZoomScale = 1.0
        previousScale = 0.0

        // Image previewed
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)

        // Play button above posters of movie
        let play = UIImage(named: "videoPlay")
        playImage.image = play?.withRenderingMode(.alwaysTemplate)
        playImage.tintColor = UIColor.piwigoColorOrange()
        playImage.isHidden = true
        playImage.translatesAutoresizingMaskIntoConstraints = false
        playImage.contentMode = .scaleAspectFit
        addSubview(playImage)
        addConstraints(NSLayoutConstraint.constraintView(playImage, to: CGSize(width: 50, height: 50))!)
        addConstraints(NSLayoutConstraint.constraintCenter(playImage)!)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

// MARK: - UIScrollViewDelegate Methods
extension ImageScrollView: UIScrollViewDelegate
{
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if (scale == 1.0) && (previousScale == 1.0) {
            // The user scaled down twice the image => back to collection of images
            let name = NSNotification.Name(rawValue: kPiwigoNotificationPinchedImage)
            NotificationCenter.default.post(name: name, object: nil)
        } else {
            previousScale = scale
        }
    }
}
