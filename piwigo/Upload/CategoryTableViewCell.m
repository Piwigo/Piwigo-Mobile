//
//  CategoryTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryTableViewCell.h"
#import "PiwigoAlbumData.h"
#import "Model.h"

@interface CategoryTableViewCell()

@property (nonatomic, strong) PiwigoAlbumData *categoryData;

@end

@implementation CategoryTableViewCell

-(void)setupWithCategoryData:(PiwigoAlbumData*)category
{
    // General settings
    self.backgroundColor = [UIColor piwigoCellBackgroundColor];
    self.tintColor = [UIColor piwigoOrange];
    self.textLabel.font = [UIFont piwigoFontNormal];
    
    // Category data and name
    self.categoryData = category;
    self.categoryLabel.text = self.categoryData.name;
    self.categoryLabel.textColor = [UIColor piwigoLeftLabelColor];
    
    // Never show open/close button (# sub-albums)
    self.subAlbumsLabel.text = @"";
    self.upDownImage.hidden = YES;
    
    // Execute tappedLoadView whenever tapped
    [self.loadTapView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedLoadView)]];
}

-(void)setupWithCategoryData:(PiwigoAlbumData*)category atDepth:(NSInteger)depth withSubCategoryButton:(BOOL)access
{
    // General settings
    self.backgroundColor = [UIColor piwigoCellBackgroundColor];
    self.tintColor = [UIColor piwigoOrange];
    self.textLabel.font = [UIFont piwigoFontNormal];

    // Category data
    self.categoryData = category;

    // Is this a sub-category?
    self.categoryLabel.textColor = [UIColor piwigoLeftLabelColor];
    if ((depth < 1) || !access) {
        // Categories in root album
        self.categoryLabel.text = self.categoryData.name;
    } else {
        // Append "—" characters to sub-category names
        NSString *subAlbumPrefix = [@"" stringByPaddingToLength:depth withString:@"…" startingAtIndex:0];
        if ([Model sharedInstance].isAppLanguageRTL) {
            self.categoryLabel.text = [NSString stringWithFormat:@"%@ %@", self.categoryData.name, subAlbumPrefix];
        } else {
            self.categoryLabel.text = [NSString stringWithFormat:@"%@ %@", subAlbumPrefix, self.categoryData.name];
        }
    }
    
    // Show open/close button (# sub-albums) if there are sub-categories
	if ((category.numberOfSubCategories <= 0) || !access) {
        self.subAlbumsLabel.text = @"";
        self.upDownImage.hidden = YES;
    } else {
        self.subAlbumsLabel.text = [NSString stringWithFormat:@"%ld %@",
                               (long)self.categoryData.numberOfSubCategories,
                               self.categoryData.numberOfSubCategories > 1 ? NSLocalizedString(@"categoryTableView_subCategoriesCount", @"sub-albums") : NSLocalizedString(@"categoryTableView_subCategoryCount", @"sub-album")];
        self.upDownImage.hidden = NO;
    }
    
    // Execute tappedLoadView whenever tapped
    [self.loadTapView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedLoadView)]];
}

-(void)tappedLoadView
{
	if([self.categoryDelegate respondsToSelector:@selector(tappedDisclosure:)])
	{
        // Open or close the list of sub-albums
        [self.categoryDelegate tappedDisclosure:self.categoryData];
	}
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
    self.categoryLabel.text = @"";
}

@end
