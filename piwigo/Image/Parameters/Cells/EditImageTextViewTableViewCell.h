//
//  EditImageTextViewTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditImageTextViewTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UITextView *textView;

-(void)setComment:(NSString *)imageDetail inColor:(UIColor *)color;

@end
