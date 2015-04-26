//
//  ImageDetailViewController_iPhone.m
//  piwigo
//
//  Created by Olaf on 26.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageDetailViewController_iPhone.h"

#import "Model.h"
#import "EditImageDetailsViewController.h"
#import "ImageUpload.h"

@interface ImageDetailViewController_iPhone ()

@end

@implementation ImageDetailViewController_iPhone


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    UIBarButtonItem *imageOptionsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(imageOptions)];
    self.navigationItem.rightBarButtonItem = imageOptionsButton;
    
}

-(void)imageOptions
{
    NSMutableArray *otherButtons = [NSMutableArray new];
    [otherButtons addObject:NSLocalizedString(@"iamgeOptions_download", @"Download")];
    if([Model sharedInstance].hasAdminRights)
    {
        [otherButtons addObject:NSLocalizedString(@"iamgeOptions_edit",  @"Edit")];
        [otherButtons addObject:NSLocalizedString(@"imageOptions_setAlbumImage", @"Set as Album Image")];
    }
    
    [UIActionSheet showFromBarButtonItem:self.navigationItem.rightBarButtonItem
                                animated:YES
                               withTitle:NSLocalizedString(@"imageOptions_title", @"Image Options")
                       cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                  destructiveButtonTitle:[Model sharedInstance].hasAdminRights ? NSLocalizedString(@"deleteImage_delete", @"Delete") : nil
                       otherButtonTitles:otherButtons
                                tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                                    buttonIndex += [Model sharedInstance].hasAdminRights ? 0 : 1;
                                    switch(buttonIndex)
                                    {
                                        case 0: // Delete
                                            [super deleteImage:nil];
                                            break;
                                        case 1: // Download
                                            [super downloadImage:nil];
                                            break;
                                        case 2: // Edit
                                        {
                                            if(![Model sharedInstance].hasAdminRights) break;
                                            
                                            UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
                                            EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
                                            editImageVC.imageDetails = [[ImageUpload alloc] initWithImageData:self.imageData];
                                            editImageVC.isEdit = YES;

                                            UINavigationController *presentNav = [[UINavigationController alloc] initWithRootViewController:editImageVC];
                                            [self.navigationController presentViewController:presentNav animated:YES completion:nil];
                                            break;
                                        }
                                        case 3:	// set as album image
                                        {
                                            if(![Model sharedInstance].hasAdminRights) break;
                                            [super makeAlbumThumbnail:nil];
                                            break;
                                        }
                                    }
                                }];
}


@end
