//  Converted to Swift 5.3 by Swiftify v5.3.28117 - https://swiftify.com/
//
//  VideoView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/11/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

import AVKit
import UIKit

@objc
class VideoView: UIView
{
    var videoView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        videoView = UIView()
        videoView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView?.contentMode = .scaleAspectFit
        if let videoView = videoView {
            addSubview(videoView)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

extension VideoView: AVPlayerViewControllerDelegate
{
    
}
