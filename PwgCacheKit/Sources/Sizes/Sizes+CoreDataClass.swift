//
//  Sizes+CoreDataClass.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 16/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData
import PwgKit

public typealias SizesCoreDataClassSet = NSSet

@objc(Sizes)
public final nonisolated class Sizes: NSManagedObject {

    public func url(for imageSize: pwgImageSize) -> URL? {
        switch imageSize {
        case .square:
            return self.square?.url as URL?
        case .thumb:
            return self.thumb?.url as URL?
        case .xxSmall:
            return self.xxsmall?.url as URL?
        case .xSmall:
            return self.xsmall?.url as URL?
        case .small:
            return self.small?.url as URL?
        case .medium:
            return self.medium?.url as URL?
        case .large:
            return self.large?.url as URL?
        case .xLarge:
            return self.xlarge?.url as URL?
        case .xxLarge:
            return self.xxlarge?.url as URL?
        case .xxxLarge:
            return self.xxxlarge?.url as URL?
        case .xxxxLarge:
            return self.xxxxlarge?.url as URL?
        default:
            return nil
        }
    }
}
