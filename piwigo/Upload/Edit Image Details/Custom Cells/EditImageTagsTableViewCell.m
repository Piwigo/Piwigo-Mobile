//
//  EditImageTagsTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageTagsTableViewCell.h"
#import "TagsData.h"

@interface EditImageTagsTableViewCell()

@property (weak, nonatomic) IBOutlet UILabel *leftLabel;
@property (weak, nonatomic) IBOutlet UILabel *rightLabel;

@property (nonatomic, strong) NSString *tagsString;

@end

@implementation EditImageTagsTableViewCell

- (void)awakeFromNib
{
    // Initialization code
    [super awakeFromNib];

    self.backgroundColor = [UIColor piwigoBackgroundColor];
	
	self.tagsString = @"";
	self.leftLabel.text = NSLocalizedString(@"editImageDetails_tags", @"Tags:");
    self.leftLabel.font = [UIFont piwigoFontNormal];
    self.rightLabel.font = [UIFont piwigoFontNormal];
}

-(void)setTagsString:(NSString *)tagsString
{
	_tagsString = tagsString;

	if (tagsString.length <= 0)
	{
		self.rightLabel.text = NSLocalizedString(@"none", @"none");
	}
	else
	{
		self.rightLabel.text = tagsString;
	}
}

-(void)setTagList:(NSArray*)tags
{
	self.tagsString = [[TagsData sharedInstance] getTagsStringFromList:tags];
    self.leftLabel.textColor = [UIColor piwigoLeftLabelColor];
    self.rightLabel.textColor = [UIColor piwigoLeftLabelColor];
    self.rightLabel.backgroundColor = [UIColor piwigoCellBackgroundColor];
}

@end
