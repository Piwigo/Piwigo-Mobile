//
//  ImageUploadViewController.h
//  piwigo
//
//  Created by Spencer Baker on 2/5/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ImageUploadViewController : UIViewController

@property (nonatomic, assign) NSInteger selectedCategory;
@property (nonatomic, strong) NSURL *localAlbum;
@property (nonatomic, strong) NSArray *imagesSelected;

@end
