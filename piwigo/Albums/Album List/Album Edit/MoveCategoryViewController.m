//
//  MoveCategoryViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "MoveCategoryViewController.h"
#import "CategoriesData.h"
#import "AlbumService.h"
#import "CategoryTableViewCell.h"
#import "MBProgressHUD.h"

@interface MoveCategoryViewController () <CategoryListDelegate>

@property (nonatomic, strong) PiwigoAlbumData *selectedCategory;

@end

@implementation MoveCategoryViewController

-(instancetype)initWithSelectedCategory:(PiwigoAlbumData*)category
{
	self = [super init];
	if(self)
	{
		self.title = NSLocalizedString(@"moveCategory", @"Move Album");
		self.selectedCategory = category;
		self.categoryListDelegate = self;
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	NSMutableArray *newCategoryArray = [[NSMutableArray alloc] initWithArray:self.categories];
	for(PiwigoAlbumData *categoryData in self.categories)
	{
		if(categoryData.albumId == self.selectedCategory.albumId)
		{
			[newCategoryArray removeObject:categoryData];
			break;
		}
	}
	
	PiwigoAlbumData *rootAlbum = [PiwigoAlbumData new];
	rootAlbum.albumId = 0;
	rootAlbum.name = @"------------";
	[newCategoryArray insertObject:rootAlbum atIndex:0];
	self.categories = newCategoryArray;
}


-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Header height?
    NSString *header = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectParent", @"Select an album to move album \"%@\" into"), self.selectedCategory.name];
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect headerRect = [header boundingRectWithSize:CGSizeMake(tableView.frame.size.width, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:nil];
    return ceil(headerRect.size.height + 4.0 + 10.0);
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Header label
	UILabel *headerLabel = [UILabel new];
	headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
	headerLabel.font = [UIFont piwigoFontNormal];
	headerLabel.textColor = [UIColor piwigoHeaderColor];
	headerLabel.text = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectParent", @"Select an album to move album \"%@\" into"), self.selectedCategory.name];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;

    // Header height
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect headerRect = [headerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:attributes
                                                       context:nil];
    
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

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CategoryTableViewCell *cell = (CategoryTableViewCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
	
	PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
	if(categoryData.albumId == self.selectedCategory.parentAlbumId)
	{
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	
	return cell;
}

-(void)selectedCategory:(PiwigoAlbumData *)category
{
    UIAlertController* alert = [UIAlertController
               alertControllerWithTitle:NSLocalizedString(@"moveCategory", @"Move Album")
               message:[NSString stringWithFormat:NSLocalizedString(@"moveCategory_message", @"Are you sure you want to move \"%@\" into the album \"%@\"?"), self.selectedCategory.name, category.name]
               preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       [self.navigationController popViewControllerAnimated:YES];
                                   }];
    
    UIAlertAction* moveAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
                                       [self makeSelectedCategoryAChildOf:category.albumId];
                                   }];
    
    [alert addAction:cancelAction];
    [alert addAction:moveAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)makeSelectedCategoryAChildOf:(NSInteger)categoryId
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showMoveCategoryHUD];
    });
    
	[AlbumService moveCategory:self.selectedCategory.albumId
				  intoCategory:categoryId
				  OnCompletion:^(NSURLSessionTask *task, BOOL movedSuccessfully) {
					  if(movedSuccessfully)
					  {
                          [self hideMoveCategoryHUDwithSuccess:YES completion:^{
                              dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                                  self.selectedCategory.parentAlbumId = categoryId;
                                  [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
                                  [self.navigationController popViewControllerAnimated:YES];
                              });
                          }];
					  }
					  else
					  {
                          [self hideMoveCategoryHUDwithSuccess:NO completion:^{
                              [self showMoveCategoryErrorWithMessage:nil];
                          }];
					  }
				  } onFailure:^(NSURLSessionTask *task, NSError *error) {
                      [self hideMoveCategoryHUDwithSuccess:NO completion:^{
                          [self showMoveCategoryErrorWithMessage:[error localizedDescription]];
                      }];
				  }];
}

-(void)showMoveCategoryErrorWithMessage:(NSString*)message
{
    NSString *errorMessage = NSLocalizedString(@"moveCategoryError_message", @"Failed to move your album");
    if(message)
    {
        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
    }
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"moveCategoryError_title", @"Move Fail")
                                message:errorMessage
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction * action) {}];
    
    [alert addAction:dismissAction];
    [self presentViewController:alert animated:YES completion:nil];

    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -- HUD methods

-(void)showMoveCategoryHUD
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
    hud.label.text = NSLocalizedString(@"moveCategoryHUD_moving", @"Moving Album…");
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideMoveCategoryHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
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
