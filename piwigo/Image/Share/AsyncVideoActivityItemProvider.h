//
//  AsyncVideoActivityItemProvider.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"

FOUNDATION_EXPORT NSString * const kPiwigoNotificationDidShareVideo;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCancelDownloadVideo;

@class PiwigoImageData;

@protocol AsyncImageActivityItemProviderDelegate;


@interface AsyncVideoActivityItemProvider : UIActivityItemProvider

@property (weak, nonatomic) id<AsyncImageActivityItemProviderDelegate> delegate;

-(instancetype)initWithPlaceholderImage:(PiwigoImageData *)imageData;

@end
