//
//  AlbumTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumTableViewCell.h"
#import "PiwigoAlbumData.h"
#import "ImageService.h"
#import "LEColorPicker.h"
#import "OutlinedText.h"
#import "Model.h"
#import "AlbumService.h"
#import "CategoriesData.h"
#import "MoveCategoryViewController.h"

@interface AlbumTableViewCell()

@property (nonatomic, strong) UIImageView *backgroundImage;
@property (nonatomic, strong) OutlinedText *albumName;
@property (nonatomic, strong) UILabel *numberOfImages;
@property (nonatomic, strong) UILabel *date;
@property (nonatomic, strong) UIView *textUnderlay;
@property (nonatomic, strong) UIImageView *cellDisclosure;
@property (nonatomic, strong) AFHTTPRequestOperation *cellDataRequest;

@end

@implementation AlbumTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoGray];
		
		self.backgroundImage = [UIImageView new];
		self.backgroundImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.backgroundImage.contentMode = UIViewContentModeScaleAspectFill;
		self.backgroundImage.clipsToBounds = YES;
		self.backgroundImage.backgroundColor = [UIColor piwigoGray];
		self.backgroundImage.image = [UIImage imageNamed:@"placeholder"];
		[self.contentView addSubview:self.backgroundImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-5-[img]-5-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:@{@"img" : self.backgroundImage}]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillHeight:self.backgroundImage]];
		
		if(IS_OS_8_OR_LATER)
		{
			UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
			self.textUnderlay = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
		}
		else
		{
			self.textUnderlay = [UIView new];
			self.textUnderlay.alpha = 0.5;
		}
		self.textUnderlay.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:self.textUnderlay];
		
		self.albumName = [OutlinedText new];
		self.albumName.translatesAutoresizingMaskIntoConstraints = NO;
		self.albumName.font = [UIFont piwigoFontNormal];
		self.albumName.font = [self.albumName.font fontWithSize:21.0];
		self.albumName.textColor = [UIColor piwigoOrange];
		self.albumName.adjustsFontSizeToFitWidth = YES;
		self.albumName.minimumScaleFactor = 0.6;
		[self.contentView addSubview:self.albumName];
		
		self.numberOfImages = [UILabel new];
		self.numberOfImages.translatesAutoresizingMaskIntoConstraints = NO;
		self.numberOfImages.font = [UIFont piwigoFontNormal];
		self.numberOfImages.font = [self.numberOfImages.font fontWithSize:16.0];
		self.numberOfImages.textColor = [UIColor piwigoWhiteCream];
		self.numberOfImages.adjustsFontSizeToFitWidth = YES;
		self.numberOfImages.minimumScaleFactor = 0.8;
		self.numberOfImages.lineBreakMode = NSLineBreakByTruncatingTail;
		[self.numberOfImages setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
		[self.contentView addSubview:self.numberOfImages];
		
		self.date = [UILabel new];
		self.date.translatesAutoresizingMaskIntoConstraints = NO;
		self.date.font = [UIFont piwigoFontNormal];
		self.date.font = [self.date.font fontWithSize:16.0];
		self.date.textColor = [UIColor piwigoWhiteCream];
		self.date.textAlignment = NSTextAlignmentRight;
		[self.date setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
		[self.contentView addSubview:self.date];
		
		UIImage *cellDisclosureImg = [UIImage imageNamed:@"cellDisclosure"];
		self.cellDisclosure = [UIImageView new];
		self.cellDisclosure.translatesAutoresizingMaskIntoConstraints = NO;
		self.cellDisclosure.image = [cellDisclosureImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.cellDisclosure.tintColor = [UIColor piwigoWhiteCream];
		self.cellDisclosure.contentMode = UIViewContentModeScaleAspectFit;
		[self.contentView addSubview:self.cellDisclosure];
		
		[self setupAutoLayout];
		
		if([Model sharedInstance].hasAdminRights)
		{
			self.rightSwipeSettings.transition = MGSwipeTransitionStatic;
			self.rightButtons = @[[MGSwipeButton buttonWithTitle:NSLocalizedString(@"categoryCellOption_rename", @"Rename")
														  backgroundColor:[UIColor piwigoOrange]
																 callback:^BOOL(MGSwipeTableCell *sender) {
																	 [self renameCategory];
																	 return YES;
																 }],
								  [MGSwipeButton buttonWithTitle:NSLocalizedString(@"categoryCellOption_move", @"Move")
												 backgroundColor:[UIColor piwigoGrayLight]
														callback:^BOOL(MGSwipeTableCell *sender) {
															[self moveCategory];
															return YES;
														}],
								  [MGSwipeButton buttonWithTitle:NSLocalizedString(@"categoryCellOption_delete", @"Delete")
												 backgroundColor:[UIColor redColor]
														callback:^BOOL(MGSwipeTableCell *sender) {
															[self deleteCategory];
															return YES;
														}]];
		}
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageUpdated) name:kPiwigoNotificationCategoryImageUpdated object:nil];
		
	}
	return self;
}

-(void)setupAutoLayout
{
	NSDictionary *views = @{
							@"name" : self.albumName,
							@"numImages" : self.numberOfImages,
							@"date" : self.date
							};
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[name]-5-[numImages]-15-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.albumName
																 attribute:NSLayoutAttributeLeft
																 relatedBy:NSLayoutRelationEqual
																	toItem:self.contentView
																 attribute:NSLayoutAttributeLeft
																multiplier:1.0
																  constant:20]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.albumName
																 attribute:NSLayoutAttributeRight
																 relatedBy:NSLayoutRelationLessThanOrEqual
																	toItem:self.contentView
																 attribute:NSLayoutAttributeRight
																multiplier:1.0
																  constant:-30]];
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-20-[numImages]-[date]-20-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintViewToSameBase:self.date equalToView:self.numberOfImages]];
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-5-[bg]-5-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:@{@"bg" : self.textUnderlay}]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.textUnderlay amount:0]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.textUnderlay
																 attribute:NSLayoutAttributeTop
																 relatedBy:NSLayoutRelationEqual
																	toItem:self.albumName
																 attribute:NSLayoutAttributeTop
																multiplier:1.0
																  constant:-5]];
	
	[self.cellDisclosure addConstraints:[NSLayoutConstraint constraintView:self.cellDisclosure toSize:CGSizeMake(23, 23)]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromRight:self.cellDisclosure amount:15]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.cellDisclosure amount:38]];
}

-(void)imageUpdated
{
	[self setupBgWithImage:self.albumData.categoryImage];
}

-(void)renameCategory
{
	[UIAlertView showWithTitle:NSLocalizedString(@"renameCategory_title", @"Rename Album")
					   message:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"renameCategory_message", @"Rename album"), self.albumData.name]
						 style:UIAlertViewStylePlainTextInput
			 cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
			 otherButtonTitles:@[NSLocalizedString(@"renameCategory_button", @"Rename")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1)
						  {
							  [AlbumService renameCategory:self.albumData.albumId
												   forName:[alertView textFieldAtIndex:0].text
											  OnCompletion:^(AFHTTPRequestOperation *operation, BOOL renamedSuccessfully) {
												  
												  if(renamedSuccessfully)
												  {
													  self.albumData.name = [alertView textFieldAtIndex:0].text;
													  
													  [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];

													  [UIAlertView showWithTitle:NSLocalizedString(@"renameCategorySuccess_title", @"Rename Success")
																		 message:NSLocalizedString(@"renameCategorySuccess_message", @"Successfully renamed your album")
															   cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
															   otherButtonTitles:nil
																		tapBlock:nil];
												  }
												  else
												  {
													  [self showRenameErrorWithMessage:nil];
												  }
											  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
												  
												  [self showRenameErrorWithMessage:[error localizedDescription]];
											  }];
						  }
					  }];
}
-(void)showRenameErrorWithMessage:(NSString*)message
{
	NSString *errorMessage = NSLocalizedString(@"renameCategoyError_message", @"Failed to rename your album");
	if(message)
	{
		errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
	}
	[UIAlertView showWithTitle:NSLocalizedString(@"renameCategoyError_title", @"Rename Fail")
					   message:errorMessage
			 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
			 otherButtonTitles:nil
					  tapBlock:nil];
}

-(void)moveCategory
{
	MoveCategoryViewController *moveCategoryVC = [[MoveCategoryViewController alloc] initWithSelectedCategory:self.albumData];
	if([self.cellDelegate respondsToSelector:@selector(pushView:)])
	{
		[self.cellDelegate pushView:moveCategoryVC];
	}
}

-(void)deleteCategory
{
	[UIAlertView showWithTitle:NSLocalizedString(@"deleteCategory_title", @"DELETE ALBUM")
					   message:[NSString stringWithFormat:NSLocalizedString(@"deleteCategory_message", @"ARE YOU SURE YOU WANT TO DELETE THE ALBUM \"%@\" AND ALL %@ IMAGES?"), self.albumData.name, @(self.albumData.numberOfSubAlbumImages)]
			 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
			 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1)
						  {
							  [UIAlertView showWithTitle:NSLocalizedString(@"deleteCategoryConfirm_title", @"Are you sure?")
												 message:[NSString stringWithFormat:NSLocalizedString(@"deleteCategoryConfirm_message", @"Please enter the number of images in order to delete this album\nNumber of images: %@"), @(self.albumData.numberOfImages)]
												   style:UIAlertViewStylePlainTextInput
									   cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
									   otherButtonTitles:@[NSLocalizedString(@"deleteCategoryConfirm_deleteButton", @"DELETE")]
												tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
													if(buttonIndex == 1)
													{
														NSInteger number = -1;
														if([alertView textFieldAtIndex:0].text.length > 0)
														{
															number = [[alertView textFieldAtIndex:0].text integerValue];
														}
														if(number == self.albumData.numberOfSubAlbumImages)
														{
															[AlbumService deleteCategory:self.albumData.albumId OnCompletion:^(AFHTTPRequestOperation *operation, BOOL deletedSuccessfully) {
																if(deletedSuccessfully)
																{
																	[[CategoriesData sharedInstance] deleteCategory:self.albumData.albumId];
																	[[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
																	[UIAlertView showWithTitle:NSLocalizedString(@"deleteCategorySuccess_title",  @"Delete Successful")
																					   message:[NSString stringWithFormat:NSLocalizedString(@"deleteCategorySuccess_message", @"Deleted \"%@\" album successfully"), self.albumData.name]
																			 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
																			 otherButtonTitles:nil
																					  tapBlock:nil];
																}
																else
																{
																	[self deleteCategoryError:nil];
																}
															} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
																[self deleteCategoryError:[error localizedDescription]];
															}];
														}
														else
														{	// they entered the wrong amount
															[UIAlertView showWithTitle:NSLocalizedString(@"deleteCategoryMatchError_title", @"Number Doesn't Match")
																			   message:NSLocalizedString(@"deleteCategoryMatchError_message", @"The number of images you entered doesn't match the number of images in the category. Please try again if you desire to delete this album")
																	 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
																	 otherButtonTitles:nil
																			  tapBlock:nil];
														}
													}
												}];
						  }
					  }];
}
-(void)deleteCategoryError:(NSString*)message
{
	NSString *errorMessage = NSLocalizedString(@"deleteCategoryError_message", @"Failed to delete your album");
	if(message)
	{
		errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
	}
	[UIAlertView showWithTitle:NSLocalizedString(@"deleteCategoryError_title", @"Delete Fail")
					   message:errorMessage
			 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
			 otherButtonTitles:nil
					  tapBlock:nil];
}

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
	if(!albumData) return;
	
	self.albumData = albumData;
	
	self.albumName.text = self.albumData.name;
	
	NSString *subCategoryImages = @"";
	if(self.albumData.numberOfSubAlbumImages != self.albumData.numberOfImages)
	{
		subCategoryImages = [NSString stringWithFormat:@", %@ %@", @(self.albumData.numberOfSubAlbumImages - self.albumData.numberOfImages), NSLocalizedString(@"categoryTableView_subCategoryImageCount", @"photos in sub-albums")];
	}
	
	self.numberOfImages.text = [NSString stringWithFormat:@"%@ %@%@", @(self.albumData.numberOfImages), NSLocalizedString(@"categoryTableView_photoCount", @"photos"), subCategoryImages];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyy-MM-dd"];
	self.date.text = [formatter stringFromDate:self.albumData.dateLast];
	
	NSInteger imageSize = CGImageGetHeight(albumData.categoryImage.CGImage) * CGImageGetBytesPerRow(albumData.categoryImage.CGImage);
	
	if(albumData.categoryImage && imageSize > 0)
	{
		[self setupBgWithImage:albumData.categoryImage];
	}
	else if(albumData.albumThumbnailId > 0)
	{
		__weak typeof(self) weakSelf = self;
		self.cellDataRequest = [ImageService getImageInfoById:albumData.albumThumbnailId
					  ListOnCompletion:^(AFHTTPRequestOperation *operation, PiwigoImageData *imageData) {
						  if(!imageData.mediumPath)
						  {
							  albumData.categoryImage = [UIImage imageNamed:@"placeholder"];
						  }
						  else
						  {
							  [self.backgroundImage setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[imageData.mediumPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]
														  placeholderImage:nil
																   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
																	   
																	   albumData.categoryImage = image;
																	   [weakSelf setupBgWithImage:image];
							  } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
								  NSLog(@"fail to get imgage for album");
							  }];
						  }
					  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
						  NSLog(@"Fail to get album bg image: %@", [error localizedDescription]);
					  }];
	}
}

-(void)setupBgWithImage:(UIImage*)image
{
	self.backgroundImage.image = image;
	
	if(!IS_OS_8_OR_LATER)
	{
		LEColorPicker *colorPicker = [LEColorPicker new];
		LEColorScheme *colorScheme = [colorPicker colorSchemeFromImage:image];
		UIColor *backgroundColor = colorScheme.backgroundColor;
	//	UIColor *primaryColor = colorScheme.primaryTextColor;
	//	UIColor *secondaryColor = colorScheme.secondaryTextColor;

		CGFloat bgRed = CGColorGetComponents(backgroundColor.CGColor)[0] * 255;
		CGFloat bgGreen = CGColorGetComponents(backgroundColor.CGColor)[1] * 255;
		CGFloat bgBlue = CGColorGetComponents(backgroundColor.CGColor)[2] * 255;


		int threshold = 105;
		int bgDelta = (bgRed * 0.299) + (bgGreen * 0.587) + (bgBlue * 0.114);
		UIColor *bgColor = (255 - bgDelta < threshold) ? [UIColor blackColor] : [UIColor whiteColor];
		self.textUnderlay.backgroundColor = bgColor;
		self.numberOfImages.textColor = (255 - bgDelta < threshold) ? [UIColor piwigoWhiteCream] : [UIColor piwigoGray];
		self.date.textColor = self.numberOfImages.textColor;
		self.cellDisclosure.tintColor = self.numberOfImages.textColor;
	}
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
	[self.cellDataRequest cancel];
	[self.backgroundImage cancelImageRequestOperation];
	self.backgroundImage.image = [UIImage imageNamed:@"placeholder"];
	
	self.albumName.text = @"";
	self.numberOfImages.text = @"";
}

-(void)setFrame:(CGRect)frame
{
	frame.size.height -= 8.0;
	[super setFrame:frame];
}

@end
