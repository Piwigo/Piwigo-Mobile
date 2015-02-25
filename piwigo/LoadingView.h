//
//  LoadingView.h
//  missionprep
//
//  Created by Spencer Baker on 12/30/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LoadingView : UIView

-(void)hideLoadingWithLabel:(NSString*)text showCheckMark:(BOOL)show withDelay:(CGFloat)delay;
-(void)showLoadingWithLabel:(NSString*)text andProgressLabel:(NSString*)progressText;
-(void)setProgressLabelText:(NSString*)text;

@end
