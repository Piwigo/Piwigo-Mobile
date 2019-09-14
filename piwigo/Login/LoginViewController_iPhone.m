//
//  LoginViewController_iPhone.m
//  piwigo
//
//  Created by Olaf on 31.03.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LoginViewController_iPhone.h"
#import "Model.h"

@interface LoginViewController_iPhone ()

@end

@implementation LoginViewController_iPhone

-(instancetype)init
{
    self = [super init];
    if(self) {
    }
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

-(void)viewWillAppear:(BOOL)animated
{
    // Register for keyboard notifications
    [super viewWillAppear:YES];

    // Inform user if the connection is not secure
    self.websiteNotSecure.hidden = [[Model sharedInstance].serverProtocol isEqualToString:@"https://"];
}

-(void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setupAutoLayout
{
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    self.textFieldHeight = 48 + 8 * (([UIScreen mainScreen].bounds.size.height - 480) / (812 - 480));
    NSInteger margin = 36;

    NSDictionary *views = @{
                            @"logo" : self.piwigoLogo,
                            @"url" : self.piwigoButton,
                            @"server" : self.serverTextField,
                            @"user" : self.userTextField,
                            @"password" : self.passwordTextField,
                            @"login" : self.loginButton,
                            @"notSecure" : self.websiteNotSecure,
                            @"by1" : self.byLabel1,
                            @"by2" : self.byLabel2,
                            @"usu" : self.versionLabel
                           };

    NSDictionary *metrics = @{
                              @"height" : @(self.textFieldHeight),
                              @"side" : @(margin)
                              };
    
    // Vertically
    [self.view addConstraint:[NSLayoutConstraint constraintViewFromTop:self.loginButton amount:([UIScreen mainScreen].bounds.size.height / 2.0 + self.textFieldHeight + 2 * 10.0)]];
    
    if ([UIScreen mainScreen].bounds.size.height > 500) {
        [self.view addConstraints:[NSLayoutConstraint
                constraintsWithVisualFormat:@"V:|-(>=50,<=100)-[logo(height)]-(>=20)-[url(==logo)]-10-[server(==logo)]-10-[user(==logo)]-10-[password(==logo)]-10-[login(==logo)]-10-[notSecure]-(>=30)-[by1][by2]-3-[usu]-20-|"
                                   options:kNilOptions metrics:metrics views:views]];
    } else {
        [self.view addConstraints:[NSLayoutConstraint
                constraintsWithVisualFormat:@"V:|-(>=30,<=50)-[logo(height)]-(>=20)-[url(==logo)]-10-[server(==logo)]-10-[user(==logo)]-10-[password(==logo)]-10-[login(==logo)]-10-[notSecure]-(>=30)-[by1][by2]-3-[usu]-20-|"
                                   options:kNilOptions metrics:metrics views:views]];
    }

    // Piwigo logo
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoLogo]];

    // URL button
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoButton]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[url]-side-|" options:kNilOptions metrics:metrics views:views]];

    // Server
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.serverTextField]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[server]-side-|" options:kNilOptions metrics:metrics views:views]];

    // Username
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.userTextField]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[user]-side-|" options:kNilOptions metrics:metrics views:views]];

    // Password
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.passwordTextField]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[password]-side-|" options:kNilOptions metrics:metrics views:views]];

    // Login button
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.loginButton]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[login]-side-|" options:kNilOptions metrics:metrics views:views]];
    
    // Information
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.websiteNotSecure]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel1]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel2]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.versionLabel]];
}

@end
