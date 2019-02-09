//
//  AsyncImageActivityItemProvider.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"

FOUNDATION_EXPORT NSString * const kPiwigoNotificationDidShareImage;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCancelDownloadImage;

@class PiwigoImageData;

@protocol AsyncImageActivityItemProviderDelegate;


@interface AsyncImageActivityItemProvider : UIActivityItemProvider

@property (weak, nonatomic) id<AsyncImageActivityItemProviderDelegate> delegate;

-(instancetype)initWithPlaceholderImage:(PiwigoImageData *)imageData;

@end


@protocol AsyncImageActivityItemProviderDelegate <NSObject>

-(void)imageActivityItemProviderPreprocessingDidBegin:(UIActivityItemProvider *)imageActivityItemProvider withTitle:(NSString *)title;
-(void)imageActivityItemProvider:(UIActivityItemProvider *)imageActivityItemProvider preprocessingProgressDidUpdate:(float)progress;
-(void)imageActivityItemProviderPreprocessingDidEnd:(UIActivityItemProvider *)imageActivityItemProvider;
-(void)showErrorWithTitle:(NSString *)title andMessage:(NSString *)message;

@end
