//
//  ImageDownloadingProgressView.h
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ImageDownloadingProgressView : UIView

@property (nonatomic, assign) CGFloat percent;
@property (nonatomic, strong) UIImage *image;

@end
