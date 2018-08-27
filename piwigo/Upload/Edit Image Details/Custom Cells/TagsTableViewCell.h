//
//  TagsTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TagsTableViewCell : UITableViewCell

-(void)paletteChanged;
-(void)setTagList:(NSArray*)tags;

@end
