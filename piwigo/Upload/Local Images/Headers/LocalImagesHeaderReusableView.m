//
//  LocalImagesHeaderReusableView.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/02/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>

#import "LocalImagesHeaderReusableView.h"
#import "LocationsData.h"
#import "UploadViewController.h"

@interface LocalImagesHeaderReusableView()

@property (nonatomic, assign) NSInteger section;

@end

@implementation LocalImagesHeaderReusableView

-(void)setupWithImages:(NSArray *)images andLocation:(CLLocation *)location inSection:(NSInteger)section andSelectionMode:(BOOL)selected
{
    // General settings
    self.backgroundColor = [UIColor clearColor];
    
    // Keep section for future use
    self.section = section;

    // Creation date of images (or of availability)
    PHAsset *imageAsset = [images objectAtIndex:0];
    NSDate *dateCreated = [imageAsset creationDate];
    
    // Data label used when place name known
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.numberOfLines = 1;
    self.dateLabel.adjustsFontSizeToFitWidth = NO;
    self.dateLabel.font = [UIFont piwigoFontSmall];
    self.dateLabel.textColor = [UIColor piwigoRightLabelColor];

    // Data label used when place name unknown
    self.dateLabelNoPlace.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabelNoPlace.numberOfLines = 1;
    self.dateLabelNoPlace.adjustsFontSizeToFitWidth = NO;
    self.dateLabelNoPlace.font = [UIFont piwigoFontSemiBold];
    self.dateLabelNoPlace.textColor = [UIColor piwigoLeftLabelColor];

    // Place name of location
    self.placeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeLabel.numberOfLines = 1;
    self.placeLabel.adjustsFontSizeToFitWidth = NO;
    self.placeLabel.font = [UIFont piwigoFontSemiBold];
    self.placeLabel.textColor = [UIColor piwigoLeftLabelColor];

    // Use label accoring to place name availability
    if ((location == nil) || !CLLocationCoordinate2DIsValid(location.coordinate)) {
        self.placeLabel.text = @"";
        self.dateLabel.text = @"";
        self.dateLabelNoPlace.text = [NSDateFormatter localizedStringFromDate:dateCreated dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
    } else {
        self.placeLabel.text = @"";
        self.dateLabel.text = @"";
        self.dateLabelNoPlace.text = @"";
        [[LocationsData sharedInstance] getPlaceNameForLocation:location completion:^(NSString *placeName) {
            if (placeName && [placeName length] > 0) {
                self.placeLabel.text = placeName;
                self.dateLabel.text = [NSDateFormatter localizedStringFromDate:dateCreated dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
            } else {
                self.dateLabelNoPlace.text = [NSDateFormatter localizedStringFromDate:dateCreated dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
            }
        }];
    }
    
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
    self.placeLabel.text = @"";
}

@end
