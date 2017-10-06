//
//  ImageDownloadView.h
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ImageDownloadView : UIView

@property (nonatomic, strong) UIImage *downloadImage;
@property (nonatomic, assign) CGFloat percentDownloaded;

@property (nonatomic, assign) BOOL multiImage;
@property (nonatomic, assign) NSInteger imageDownloadCount;
@property (nonatomic, assign) NSInteger totalImageDownloadCount;

@end
