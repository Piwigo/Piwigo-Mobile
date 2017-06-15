//
//  EditPopDownView.h
//  piwigo
//
//  Created by Spencer Baker on 3/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^completed)(NSString *textEntered);

@interface EditPopDownView : UIView

-(instancetype)initWithPlaceHolderText:(NSString*)placeholder;
-(void)presentFromView:(UIView*)view onCompletion:(completed)completedBlock;
-(void)hide;

@end
