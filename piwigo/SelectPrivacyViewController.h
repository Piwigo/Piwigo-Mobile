//
//  SelectPrivacyViewController.h
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

@protocol SelectPrivacyDelegate <NSObject>

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy;

@end

@interface SelectPrivacyViewController : UIViewController

@property (nonatomic, weak) id<SelectPrivacyDelegate> delegate;
-(void)setPrivacy:(kPiwigoPrivacy)privacy;

@end
