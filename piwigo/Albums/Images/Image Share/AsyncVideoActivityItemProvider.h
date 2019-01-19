//
//  AsyncVideoActivityItemProvider.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"
#import "AsyncImageActivityItemProvider.h"

FOUNDATION_EXPORT NSString * const kPiwigoNotificationDidShareVideo;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCancelShareVideo;

@class PiwigoImageData;

@protocol AsyncImageActivityItemProviderDelegate;


@interface AsyncVideoActivityItemProvider : UIActivityItemProvider

@property (weak, nonatomic) id<AsyncImageActivityItemProviderDelegate> delegate;

-(instancetype)initWithPlaceholderImage:(PiwigoImageData *)imageData;

@end


//@protocol AsyncImageActivityItemProviderDelegate <NSObject>
//
//-(void)imageActivityItemProviderPreprocessingDidBegin:(AsyncImageActivityItemProvider *)imageActivityItemProvider;
//-(void)imageActivityItemProvider:(AsyncImageActivityItemProvider *)imageActivityItemProvider preprocessingProgressDidUpdate:(float)progress;
//-(void)imageActivityItemProviderPreprocessingDidEnd:(AsyncImageActivityItemProvider *)imageActivityItemProvider;
//-(void)showErrorWithTitle:(NSString *)title andMessage:(NSString *)message withOptionToRetry:(BOOL)retry;

//@end
