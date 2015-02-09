//
//  EditImageDetailsViewController.h
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImageUpload;

@protocol EditImageDetailsDelegate <NSObject>

-(void)didFinishEditingDetails:(ImageUpload*)details;

@end

@interface EditImageDetailsViewController : UIViewController

@property (nonatomic, weak) id<EditImageDetailsDelegate> delegate;
@property (nonatomic, strong) ImageUpload *imageDetails;

@end
