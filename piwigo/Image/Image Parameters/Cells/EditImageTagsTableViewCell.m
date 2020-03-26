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

@property (weak, nonatomic) IBOutlet UILabel *tagsLabel;
@property (weak, nonatomic) IBOutlet UILabel *tagsList;

@property (nonatomic, strong) NSString *tagsString;

@end

@implementation EditImageTagsTableViewCell

- (void)awakeFromNib
{
    // Initialization code
    [super awakeFromNib];

    self.backgroundColor = [UIColor piwigoColorBackground];
	
	self.tagsString = @"";
	self.tagsLabel.text = NSLocalizedString(@"editImageDetails_tags", @"Tags");
    self.tagsLabel.font = [UIFont piwigoFontNormal];
    self.tagsList.font = [UIFont piwigoFontNormal];
}

-(void)setTagsString:(NSString *)tagsString
{
	_tagsString = tagsString;

	if (tagsString.length <= 0) {
		self.tagsList.text = NSLocalizedString(@"none", @"none");
	}
	else {
		self.tagsList.text = tagsString;
	}
}

-(void)setTagList:(NSArray*)tags inColor:(UIColor *)color
{
	self.tagsString = [[TagsData sharedInstance] getTagsStringFromList:tags];
    self.tagsLabel.textColor = [UIColor piwigoColorRightLabel];
    self.tagsList.textColor = color;
}

@end
