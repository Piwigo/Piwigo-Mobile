//
//  TagsViewController.h
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol TagsViewControllerDelegate <NSObject>

-(void)didExitWithSelectedTags:(NSArray*)selectedTags;

@end

@interface TagsViewController : UIViewController

@property (nonatomic, weak) id<TagsViewControllerDelegate> delegate;

@end
