//
//  AllCategoriesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AllCategoriesViewController.h"
#import "CategoriesData.h"
#import "AlbumService.h"
#import "CategoryTableViewCell.h"
#import "MBProgressHUD.h"

@interface AllCategoriesViewController ()

@property (nonatomic, assign) NSInteger imageId;
@property (nonatomic, assign) NSInteger categoryId;

@end

@implementation AllCategoriesViewController

-(instancetype)initForImageId:(NSInteger)imageId andCategoryId:(NSInteger)categoryId
{
	self = [super init];
	if(self)
	{
		self.title = NSLocalizedString(@"categorySelection", @"Select Album");
		self.imageId = imageId;
		self.categoryId = categoryId;
	}
	return self;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(section == 0)
	{
		return 1;
	}
	return super.categories.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if(section == 1)
	{
		return 0;
	}
    
    // Header height?
    NSString *header = NSLocalizedString(@"categorySelection_forImage", @"Select an album for this image");
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect headerRect = [header boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:context];
    return fmax(44.0, ceil(headerRect.size.height + 10.0));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if(section == 0)
	{
        // Header label
		UILabel *headerLabel = [UILabel new];
		headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
		headerLabel.font = [UIFont piwigoFontNormal];
		headerLabel.textColor = [UIColor piwigoHeaderColor];
		headerLabel.text = NSLocalizedString(@"categorySelection_forImage", @"Select an album for this image");
        headerLabel.textAlignment = NSTextAlignmentCenter;
        headerLabel.numberOfLines = 0;
        headerLabel.adjustsFontSizeToFitWidth = NO;
        headerLabel.lineBreakMode = NSLineBreakByWordWrapping;

        // Header height
        NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
        NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
        context.minimumScaleFactor = 1.0;
        CGRect headerRect = [headerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                           options:NSStringDrawingUsesLineFragmentOrigin
                                                        attributes:attributes
                                                           context:context];
        headerRect.size.height = fmax(44.0, ceil(headerRect.size.height + 10.0));

        // Header view
        UIView *header = [[UIView alloc] initWithFrame:headerRect];
		[header addSubview:headerLabel];
		[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
        if (@available(iOS 11, *)) {
            [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
																	   options:kNilOptions
																	   metrics:nil
																		 views:@{@"header" : headerLabel}]];
        } else {
            [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                           options:kNilOptions
                                                                           metrics:nil
                                                                             views:@{@"header" : headerLabel}]];
        }
		
		return header;
	}
	return nil;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CategoryTableViewCell *cell = (CategoryTableViewCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
	
	PiwigoAlbumData *albumData = nil;
	
	if(indexPath.section == 0)
	{
		albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
	}
	else
	{
		albumData = [super.categories objectAtIndex:indexPath.row];
	}
	
	[cell setupWithCategoryData:albumData];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *albumData;
	
	if(indexPath.section == 1)
	{
        albumData = [super.categories objectAtIndex:indexPath.row];
	}
	else
	{
		albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
	}
	
    UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"categoryImageSet_title", @"Set Image Thumbnail")
                message:[NSString stringWithFormat:NSLocalizedString(@"categoryImageSet_message", @"Are you sure you want to set this image for the album \"%@\"?"), albumData.name]
                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* setImageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                             [self setRepresentativeForCategoryId:albumData.albumId];
                                                         }];
    
    [alert addAction:cancelAction];
    [alert addAction:setImageAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark -- Set category thumbnail

-(void)setRepresentativeForCategoryId:(NSInteger)categoryId
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showSettingRepresentativeHUD];
    });
    
    // Set image as representative
	[AlbumService setCategoryRepresentativeForCategory:categoryId
											forImageId:self.imageId
										  OnCompletion:^(NSURLSessionTask *task, BOOL setSuccessfully) {
											  if(setSuccessfully)
											  {
												  // Update image Id of album
                                                  PiwigoAlbumData *category = [[CategoriesData sharedInstance] getCategoryById:categoryId];
												  category.albumThumbnailId = self.imageId;
												  
                                                  // Update image URL of album
                                                  PiwigoImageData *imgData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:[NSString stringWithFormat:@"%@", @(self.imageId)]];
												  category.albumThumbnailUrl = imgData.ThumbPath;

                                                  // Image will be downloaded when displaying list of albums
                                                  category.categoryImage = nil;
												  
                                                  // Close HUD
                                                  [self hideSettingRepresentativeHUDwithSuccess:YES completion:^{
                                                      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 700 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                                                          [self.navigationController popViewControllerAnimated:YES];
                                                      });
                                                  }];
											  }
											  else
											  {
                                                  // Close HUD and inform user
                                                  [self hideSettingRepresentativeHUDwithSuccess:NO completion:^{
                                                      dispatch_async(dispatch_get_main_queue(),^{
                                                          [self showSetRepresentativeError:nil];
                                                      });
                                                  }];
											  }
										  } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                              // Close HUD and display error
                                              [self hideSettingRepresentativeHUDwithSuccess:NO completion:^{
                                                  dispatch_async(dispatch_get_main_queue(),^{
                                                      [self showSetRepresentativeError:[error localizedDescription]];
                                                  });
                                              }];
										  }];
}

-(void)showSetRepresentativeError:(NSString*)message
{
	NSString *bodyMessage = NSLocalizedString(@"categoryImageSetError_message", @"Failed to set the album image");
	if(message)
	{
		bodyMessage = [NSString stringWithFormat:@"%@\n%@", bodyMessage, message];
	}
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"categoryImageSetError_title", @"Image Set Error")
                                                                   message:bodyMessage
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark -- HUD methods

-(void)showSettingRepresentativeHUD
{
    // Create the loading HUD if needed
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if (!hud) {
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
    
    // Change the background view shape, style and color.
    hud.square = NO;
    hud.animationType = MBProgressHUDAnimationFade;
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
    hud.contentColor = [UIColor piwigoHudContentColor];
    hud.bezelView.color = [UIColor piwigoHudBezelViewColor];

    // Define the text
    hud.label.text = NSLocalizedString(@"categoryImageSetHUD_updating", @"Updating Album Thumbnail…");
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideSettingRepresentativeHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        if (hud) {
            if (success) {
                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"Complete", nil);
                [hud hideAnimated:YES afterDelay:3.f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}

@end
