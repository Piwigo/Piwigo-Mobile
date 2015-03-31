//
//  LoginViewController_iPhone.m
//  piwigo
//
//  Created by Olaf on 31.03.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LoginViewController_iPhone.h"

@interface LoginViewController_iPhone ()

@end

@implementation LoginViewController_iPhone

-(instancetype)init {
    self = [super init];
    if(self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setupAutoLayout
{
    NSInteger textFeildHeight = 64;
    
    NSDictionary *views = @{
                            @"logo" : self.piwigoLogo,
                            @"login" : self.loginButton,
                            @"server" : self.serverTextField,
                            @"user" : self.userTextField,
                            @"password" : self.passwordTextField
                            };
    NSDictionary *metrics = @{
                              @"imageSide" : @25,
                              @"imageTop" : @40,
                              @"imageBottom" : @20,
                              @"side" : @35
                              };
    self.topConstraintAmount = 40;
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[logo]-imageBottom-[server]-[user]-[password]-[login]"
                                                                      options:kNilOptions
                                                                      metrics:metrics
                                                                        views:views]];
    
    self.logoTopConstraint = [NSLayoutConstraint constraintViewFromTop:self.piwigoLogo amount:self.topConstraintAmount];
    [self.view addConstraint:self.logoTopConstraint];
    
    [self.piwigoLogo addConstraint:[NSLayoutConstraint constraintView:self.piwigoLogo toHeight:textFeildHeight + 36]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-imageSide-[logo]-imageSide-|"
                                                                      options:kNilOptions
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.serverTextField addConstraint:[NSLayoutConstraint constraintView:self.serverTextField toHeight:textFeildHeight]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-side-[server]-side-|"
                                                                      options:kNilOptions
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.userTextField addConstraint:[NSLayoutConstraint constraintView:self.userTextField toHeight:textFeildHeight]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-side-[user]-side-|"
                                                                      options:kNilOptions
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.passwordTextField addConstraint:[NSLayoutConstraint constraintView:self.passwordTextField toHeight:textFeildHeight]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-side-[password]-side-|"
                                                                      options:kNilOptions
                                                                      metrics:metrics
                                                                        views:views]];
    
    [self.loginButton addConstraint:[NSLayoutConstraint constraintView:self.loginButton toHeight:textFeildHeight]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-side-[login]-side-|"
                                                                      options:kNilOptions
                                                                      metrics:metrics
                                                                        views:views]];
    
    
    [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.loadingView]];
    [self.loadingView addConstraints:[NSLayoutConstraint constraintCenterView:self.spinner]];
    [self.loadingView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.loggingInLabel]];
    [self.loadingView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[label]-[spinner]"
                                                                             options:kNilOptions
                                                                             metrics:nil
                                                                               views:@{@"spinner" : self.spinner,
                                                                                       @"label" : self.loggingInLabel}]];
}

@end
