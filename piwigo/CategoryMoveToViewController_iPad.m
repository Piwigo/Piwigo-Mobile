//
//  CategoryMoveToViewController_iPad.m
//  piwigo
//
//  Created by Olaf Greck on 14.Jun.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryMoveToViewController_iPad.h"

@interface CategoryMoveToViewController_iPad ()

@end

@implementation CategoryMoveToViewController_iPad

- (void)viewDidLoad {
    [super viewDidLoadUniversal];
    // Do any additional setup after loading the view.
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(goBack:)];
    self.navigationItem.leftBarButtonItem = backButton; //self. editButtonItem;
}

// we are the first view in the navigation stack,
// we are on an iPad, therefore dismiss here
-(void)goBack:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
