//
//  EditImageTextViewTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditImageTextViewTableViewCell : UITableViewCell

-(void)applyColorPalette;
-(NSString*)getTextViewText;
-(void)setTextForTextView:(NSString*)text;
-(BOOL)isEditingTextView;

@end
