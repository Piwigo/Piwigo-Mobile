//
//  UIImageView+DownloadProgress.m
//  piwigo
//
//  Created by Spencer Baker on 3/26/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UIImageView+DownloadProgress.h"

@implementation UIImageView (DownloadProgress)

-(void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, long long totalBytesRead,   long long totalBytesExpectedToRead))block
{
	if ( [self respondsToSelector:@selector(af_imageRequestOperation)] )
	{
		[[self performSelector:@selector(af_imageRequestOperation)] setDownloadProgressBlock:block];
	}
}

@end
