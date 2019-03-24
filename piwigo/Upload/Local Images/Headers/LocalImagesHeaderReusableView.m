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
#import "AlbumUploadViewController.h"

@interface LocalImagesHeaderReusableView()

@property (nonatomic, assign) NSInteger section;

@end

@implementation LocalImagesHeaderReusableView

-(void)setupWithImages:(NSArray *)images andPlaceNames:(NSDictionary *)placeNames inSection:(NSInteger)section andSelectionMode:(BOOL)selected
{
    // General settings
    self.backgroundColor = [UIColor clearColor];
    
    // Keep section for future use
    self.section = section;

    // Creation date of images (or of availability)
    PHAsset *imageAsset = [images firstObject];
    NSDate *dateCreated1 = [imageAsset creationDate];
    
    // Determine if images of this section were taken today
    NSString *dateLabel = @"";
    if (dateCreated1)
    {
        // Display date of day by default
        dateLabel = [NSDateFormatter localizedStringFromDate:dateCreated1 dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
        
        // Define start time of today
        NSDate *start;
        NSTimeInterval extends;
        NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
        NSDate *today = [NSDate date];
        BOOL success = [calendar rangeOfUnit:NSCalendarUnitDay startDate:&start interval:&extends forDate:today];
        
        // If start time defined with success, gets creation date of other image, etc.
        if(success)
        {
            // Set day start time
            NSTimeInterval dayStartInSecs = [start timeIntervalSinceReferenceDate];

            // Get creation date of last image
            imageAsset = [images lastObject];
            NSDate *dateCreated2 = [imageAsset creationDate];
            if (dateCreated2)
            {
                // Set dates in right order
                NSDate *firstImageDate = MIN(dateCreated1, dateCreated2);
                NSDate *lastImageDate = MAX(dateCreated1, dateCreated2);
                NSTimeInterval dateInSecs = [firstImageDate timeIntervalSinceReferenceDate];
                
                // Images taken today?
                if (dateInSecs > dayStartInSecs)
                {
                    // Images taken today
                    dateLabel = [NSString stringWithFormat:@"%@ - %@", [NSDateFormatter localizedStringFromDate:firstImageDate dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle], [NSDateFormatter localizedStringFromDate:lastImageDate dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle]];
                } else {
                    dateLabel = [NSDateFormatter localizedStringFromDate:dateCreated1 dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
                }
            }
        }
    }

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

    // Use label according to name availabilities
    NSString *placeLabelName = [placeNames objectForKey:@"placeLabel"];
    if (placeLabelName && [placeLabelName length] > 0) {
        self.placeLabel.text = placeLabelName;
        NSString *dateLabelName = [placeNames objectForKey:@"dateLabel"];
        if (dateLabelName && [dateLabelName length] > 0) {
            self.dateLabel.text = [NSString stringWithFormat:@"%@ • %@", dateLabel, dateLabelName];
        } else {
            self.dateLabel.text = dateLabel;
        }
        self.dateLabelNoPlace.text = @"";
    } else {
        self.placeLabel.text = @"";
        self.dateLabel.text = @"";
        self.dateLabelNoPlace.text = dateLabel;
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
    self.dateLabelNoPlace.text = @"";
    self.placeLabel.text = @"";
}

@end
