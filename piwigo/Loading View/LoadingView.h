//
//  LoadingView.h
//  piwigo
//
//  Created by Spencer Baker on 12/30/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UICountingLabel;

@interface LoadingView : UIView

@property (nonatomic, strong) UICountingLabel *progressLabel;

-(void)hideLoadingWithLabel:(NSString*)text showCheckMark:(BOOL)show withDelay:(CGFloat)delay;
-(void)showLoadingWithLabel:(NSString*)text andProgressLabel:(NSString*)progressText;
-(void)setProgressLabelText:(NSString*)text;

@end
