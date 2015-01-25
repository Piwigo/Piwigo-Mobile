//
//  AlbumPhotosViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoAlbumData;

@interface AlbumPhotosViewController : UIViewController

-(instancetype)initWithAlbumData:(PiwigoAlbumData*)albumData;

@end
