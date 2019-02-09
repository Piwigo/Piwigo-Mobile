//
//  UploadExtensionViewController.m
//  UploadExtension
//
//  Created by Eddy Lelièvre-Berna on 03/02/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "UploadExtensionViewController.h"

@interface UploadExtensionViewController ()

@end

@implementation UploadExtensionViewController

- (BOOL)isContentValid {
    // Do validation of contentText and/or NSExtensionContext attachments here
    NSExtensionContext *myExtensionContext = self.extensionContext;
    NSArray *inputItems = myExtensionContext.inputItems;
    
    return YES;
}

- (void)didSelectPost {
    // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
    // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

- (NSArray *)configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    SLComposeSheetConfigurationItem *categoryItem = [[SLComposeSheetConfigurationItem alloc] init];
    categoryItem.title = NSLocalizedString(@"categorySelection_titleSub", @"Sub-Albums");
    categoryItem.value = @"…?…";
    [categoryItem setTapHandler:^{
        [self tappedCategory];
    }];
    
    return @[categoryItem];
}

- (void)tappedCategory
{
    NSLog(@"Tapped field ;-)");
}

@end
