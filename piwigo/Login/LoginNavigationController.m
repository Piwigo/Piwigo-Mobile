//
//  LoginNavigationController.m
//  piwigo
//
//  Created by Spencer Baker on 3/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LoginNavigationController.h"

@interface LoginNavigationController ()

@end

@implementation LoginNavigationController

-(UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    } else {
        return  UIInterfaceOrientationMaskAll;
    }
}

@end
