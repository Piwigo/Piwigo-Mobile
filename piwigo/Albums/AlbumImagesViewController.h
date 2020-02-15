//
//  AlbumImagesViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const kPiwigoNotificationBackToDefaultAlbum;

@class Tag;
@class TagSelectorViewController;

@interface AlbumImagesViewController : UIViewController

@property (nonatomic, assign) NSInteger categoryId;

-(instancetype)initWithAlbumId:(NSInteger)albumId inCache:(BOOL)isCached;

@end
