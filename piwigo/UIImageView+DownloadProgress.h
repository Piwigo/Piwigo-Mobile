//
//  UIImageView+DownloadProgress.h
//  piwigo
//
//  Created by Spencer Baker on 3/26/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UIImageView+AFNetworking.h"

@interface UIImageView (DownloadProgress)

-(void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, long long totalBytesRead,   long long totalBytesExpectedToRead))block;

@end
