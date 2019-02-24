//
//  ImagesHeaderReusableView.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/02/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>

#import "ImagesHeaderReusableView.h"
#import "UploadViewController.h"

@interface ImagesHeaderReusableView()

@property (nonatomic, assign) NSInteger section;

@end

@implementation ImagesHeaderReusableView

-(void)setupWithImages:(NSArray *)images inSection:(NSInteger)section andSelectionMode:(BOOL)selected
{
    // General settings
    self.backgroundColor = [UIColor clearColor];
    
    // Keep section for future use
    self.section = section;

    // Creation date of images (or of availability)
    PHAsset *imageAsset = [images objectAtIndex:0];
    NSDate *dateCreated = [imageAsset creationDate];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.numberOfLines = 1;
    self.dateLabel.adjustsFontSizeToFitWidth = NO;
    self.dateLabel.font = [UIFont piwigoFontNormal];
    self.dateLabel.textColor = [UIColor piwigoHeaderColor];
    self.dateLabel.text = [NSDateFormatter localizedStringFromDate:dateCreated dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
    
    // Select/deselect button
    self.tintColor = [UIColor piwigoOrange];
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoOrange],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    NSString *title = selected ? NSLocalizedString(@"categoryImageList_deselectButton", @"Deselect") : NSLocalizedString(@"categoryImageList_selectButton", @"Select");
    NSAttributedString *buttonTitle = [[NSAttributedString alloc] initWithString:title attributes:attributes];
    [self.selectButton setAttributedTitle:buttonTitle forState:UIControlStateNormal];
}

- (IBAction)tappedSelectButton:(id)sender
{
    if([self.headerDelegate respondsToSelector:@selector(didSelectImagesOfSection:)])
    {
        // Select/deselect section of images
        [self.headerDelegate didSelectImagesOfSection:self.section];
    }
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    
    self.dateLabel.text = @"";
}

@end
