//
//  ImageUploadParamsViewController.h
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImageUpload;

@protocol UploadParamsDelegate <NSObject>

-(void)didFinishEditingDetails:(ImageUpload*)details;

@end

@interface ImageUploadParamsViewController : UIViewController

@property (nonatomic, weak) id<UploadParamsDelegate> delegate;
@property (nonatomic, strong) NSArray<ImageUpload *> *images;

@end
