//
//  TagSelectViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT CGFloat const kTagSelectViewWidth;

@protocol TagSelectViewDelegate <NSObject>

-(void)pushTaggedImagesView:(UIViewController*)viewController;

@end

@interface TagSelectViewController : UIViewController

@property (nonatomic, weak) id<TagSelectViewDelegate> tagSelectDelegate;

@end
