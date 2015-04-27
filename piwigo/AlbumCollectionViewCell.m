//
//  AlbumCollectionViewCell.m
//  piwigo
//
//  Created by Olaf on 01.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumCollectionViewCell.h"

#import "PiwigoAlbumData.h"
#import "ImageService.h"
#import "LEColorPicker.h"
#import "OutlinedText.h"
#import "Model.h"
#import "AlbumService.h"
#import "CategoriesData.h"
#import "MoveCategoryViewController.h"

@interface AlbumCollectionViewCell()

@property (nonatomic, strong) AFHTTPRequestOperation *cellDataRequest;
@property (nonatomic) BOOL isInEditingModePrivate;


@end

@implementation AlbumCollectionViewCell

+(UINib *)nib {
    UINib *nib= [UINib nibWithNibName:@"AlbumCollectionViewCell" bundle:nil];
    return nib;
}

+(NSString *)cellReuseIdentifier {
    return @"AlbumCollectionViewCell";
}

-(void)awakeFromNib {
    self.contentView.backgroundColor = [UIColor piwigoGray];
    
    self.backgroundImage.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundImage.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundImage.clipsToBounds = YES;
    self.backgroundImage.backgroundColor = [UIColor piwigoGray];
    self.backgroundImage.image = [UIImage imageNamed:@"placeholder"];

    if(IS_OS_8_OR_LATER)
    {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _textUnderlay = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    } else {
        self.textUnderlay.alpha = 0.5;
    }
    self.textUnderlay.translatesAutoresizingMaskIntoConstraints = NO;

    self.albumName.translatesAutoresizingMaskIntoConstraints = NO;
    self.albumName.font = [UIFont piwigoFontNormal];
    self.albumName.font = [self.albumName.font fontWithSize:21.0];
    self.albumName.textColor = [UIColor piwigoOrange];
    self.albumName.adjustsFontSizeToFitWidth = YES;
    self.albumName.minimumScaleFactor = 0.6;

    self.numberOfImages.translatesAutoresizingMaskIntoConstraints = NO;
    self.numberOfImages.font = [UIFont piwigoFontNormal];
    self.numberOfImages.font = [self.numberOfImages.font fontWithSize:16.0];
    self.numberOfImages.textColor = [UIColor piwigoWhiteCream];
    self.numberOfImages.adjustsFontSizeToFitWidth = YES;
    self.numberOfImages.minimumScaleFactor = 0.8;
    self.numberOfImages.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.numberOfImages setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.numberOfSubCategoryImages.translatesAutoresizingMaskIntoConstraints = NO;
    self.numberOfSubCategoryImages.font = [UIFont piwigoFontNormal];
    self.numberOfSubCategoryImages.font = [self.numberOfSubCategoryImages.font fontWithSize:16.0];
    self.numberOfSubCategoryImages.textColor = [UIColor piwigoWhiteCream];
    self.numberOfSubCategoryImages.adjustsFontSizeToFitWidth = YES;
    self.numberOfSubCategoryImages.minimumScaleFactor = 0.8;
    self.numberOfSubCategoryImages.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.numberOfSubCategoryImages setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.date.translatesAutoresizingMaskIntoConstraints = NO;
    self.date.font = [UIFont piwigoFontNormal];
    self.date.font = [self.date.font fontWithSize:16.0];
    self.date.textColor = [UIColor piwigoWhiteCream];
    self.date.textAlignment = NSTextAlignmentRight;
    [self.date setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    
    UIImage *cellDisclosureImg = [UIImage imageNamed:@"cellDisclosure"];
    self.cellDisclosure.translatesAutoresizingMaskIntoConstraints = NO;
    self.cellDisclosure.image = [cellDisclosureImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.cellDisclosure.tintColor = [UIColor piwigoWhiteCream];
    self.cellDisclosure.contentMode = UIViewContentModeScaleAspectFit;
    
    
    [self.deleteButton setTitle:NSLocalizedString(@"categoryCellOption_delete", @"Delete") forState:UIControlStateNormal];
    [self.moveButton setTitle:NSLocalizedString(@"categoryCellOption_move", @"Move") forState:UIControlStateNormal];
    [self.renameButton setTitle:NSLocalizedString(@"categoryCellOption_rename", @"Rename") forState:UIControlStateNormal];
    self.deleteButton.backgroundColor = [UIColor redColor];
    self.moveButton.backgroundColor = [UIColor piwigoGrayLight];
    self.renameButton.backgroundColor = [UIColor piwigoOrange];
    
    [self.deleteButton setTitleColor:[UIColor piwigoWhiteCream] forState:UIControlStateNormal];
    [self.moveButton setTitleColor:[UIColor piwigoWhiteCream] forState:UIControlStateNormal];
    [self.renameButton setTitleColor:[UIColor piwigoWhiteCream] forState:UIControlStateNormal];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageUpdated) name:kPiwigoNotificationCategoryImageUpdated object:nil];

    _editViewLeftConstraint.constant = 0.0f;
    _editViewRightConstraint.constant = -self.editView.bounds.size.width;
}


-(void)imageUpdated
{
    [self setupBgWithImage:self.albumData.categoryImage];
}

#pragma mark - Editing Mode -
-(void)exitFromEditMode {
    [self showEditView:NO animated:YES];
}

-(void)goIntoEditMode {
    [self showEditView:YES animated:YES];
}

-(void)showEditView:(BOOL)show animated:(BOOL)animated {
    CGFloat editViewWidth = self.editView.bounds.size.width;
    self.isInEditingModePrivate = show;
    if(animated){
        [UIView animateWithDuration:0.3
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             _editViewLeftConstraint.constant = (show ? - editViewWidth : 0);
                             _editViewRightConstraint.constant = (show ? 0 : -editViewWidth);
                             [self.contentView needsUpdateConstraints];
                             [self.contentView layoutIfNeeded];
                         }
                         completion:nil];
    } else {
        _editViewLeftConstraint.constant = (show ? - editViewWidth : 0);
        //                             _editViewRightConstraint.priority = (show ? 0 : -editViewWidth);
    }
}

-(void)renameAction:(id)sender {
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

-(void)moveAction:(id)sender
{
    MoveCategoryViewController *moveCategoryVC = [[MoveCategoryViewController alloc] initWithSelectedCategory:self.albumData];
    if([self.cellDelegate respondsToSelector:@selector(pushView:)])
    {
        [self.cellDelegate pushView:moveCategoryVC];
    }
}

-(void)deleteAction:(id)sender

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
                                                                    if ([self.cellDelegate respondsToSelector:@selector(cellDidExitEditingMode:)]) {
                                                                        [self.cellDelegate cellDidExitEditingMode:nil];
                                                                    }
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

#pragma mark -

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
    if (nil == albumData) return;
    
    self.albumData = albumData;
    self.albumName.text = self.albumData.name;
    
    if (0 < self.albumData.numberOfSubCategories) {
        self.numberOfSubCategoryImages.text = [NSString stringWithFormat: NSLocalizedString(@"categoryTableView_subCategoryImageCountIpad", @"%1$@ photos in %2$@ sub-albums"), @(self.albumData.numberOfSubAlbumImages - self.albumData.numberOfImages), @(self.albumData.numberOfSubCategories)];
    } else {
        self.numberOfSubCategoryImages.text = @"";
    }
    
    self.numberOfImages.text = [NSString stringWithFormat:@"%@ %@", @(self.albumData.numberOfImages), NSLocalizedString(@"categoryTableView_photoCount", @"photos")];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    self.date.text = [formatter stringFromDate:self.albumData.dateLast];
    
    if(albumData.categoryImage)
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
                                                                                              MyLog(@"fail to get imgage for album");
                                                                                          }];
                                                 }
                                             } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                 MyLog(@"Fail to get album bg image: %@", [error localizedDescription]);
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
