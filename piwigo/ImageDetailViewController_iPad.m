//
//  ImageDetailViewController_iPad.m
//  piwigo
//
//  Created by Olaf on 26.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageDetailViewController_iPad.h"
#import "EditImageDetailsViewController.h"
#import "ImageUpload.h"

@interface ImageDetailViewController_iPad ()

@property (nonatomic, strong) UIBarButtonItem *deleteButton;            // admin
@property (nonatomic, strong) UIBarButtonItem *downloadButton;          // anybody
@property (nonatomic, strong) UIBarButtonItem *editButton;              // admin
@property (nonatomic, strong) UIBarButtonItem *makeAlbumImageButton;    // admin
@end

@implementation ImageDetailViewController_iPad

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (nil == self.downloadButton) {
        _downloadButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"download"]
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(downloadImage:)];
    }

    if([Model sharedInstance].hasAdminRights) {
        if (nil == self.deleteButton) {
            _deleteButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                          target:self
                                                                          action:@selector(deleteImage:)];
        }
        
        if (nil == self.makeAlbumImageButton) {
            _makeAlbumImageButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize
                                                            target:self
                                                            action:@selector(makeAlbumThumbnail:)];
        }
        if (nil == self.editButton) {
            _editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                              target:self
                                                              action:@selector(editImage:)];
        }

        self.navigationItem.rightBarButtonItems = @[  self.editButton,self.makeAlbumImageButton, self.downloadButton, self.deleteButton,];
    } else {
        self.navigationItem.rightBarButtonItem = self.downloadButton;
    }
//    UIBarButtonItem *imageOptionsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(imageOptions)];
//    self.navigationItem.rightBarButtonItem = imageOptionsButton;
    
}


-(IBAction)editImage:(id)sender {
    UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageDetails" bundle:nil];
    EditImageDetailsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageDetails"];
    editImageVC.imageDetails = [[ImageUpload alloc] initWithImageData:self.imageData];
    editImageVC.isEdit = YES;
    UINavigationController *aNavigationController = [[UINavigationController alloc] initWithRootViewController:editImageVC];
    [aNavigationController.navigationBar setBarStyle:UIBarStyleDefault];
    [aNavigationController setModalPresentationStyle:UIModalPresentationFormSheet];
    if(IS_OS_8_OR_LATER) {
        aNavigationController.preferredContentSize = CGSizeMake(320, 480);
        [self presentViewController:aNavigationController animated:YES completion:nil];
    } else {
        [self presentViewController:aNavigationController animated:YES completion:nil];
        aNavigationController.view.superview.bounds = CGRectMake(0, 0, 320, 480);
    }
}


@end
