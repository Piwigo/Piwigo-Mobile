//
//  UploadViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadViewController.h"
#import "UploadService.h"

@interface UploadViewController ()

@end

@implementation UploadViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor whiteColor];
		
		UIImage *uploadMe = [UIImage imageNamed:@"uploadMe.jpg"];
		
		[UploadService uploadImage:uploadMe
						  withName:@"multi"
						  forAlbum:1
						onProgress:^(NSInteger current, NSInteger total) {
							NSLog(@"%@/%@ (%.4f)", @(current), @(total), (CGFloat)current / total);
						}
					  OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
						  NSLog(@"DONE: %@", response);
					  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
						  NSLog(@"FAIL! : %@", error);
					  }];
	}
	return self;
}



@end
