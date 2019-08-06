//
//  MoveCategoryViewController.h
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT CGFloat const kMoveCategoryViewWidth;

@class PiwigoAlbumData;

@interface MoveCategoryViewController : UIViewController

-(instancetype)initWithSelectedCategory:(PiwigoAlbumData*)category;

@end
