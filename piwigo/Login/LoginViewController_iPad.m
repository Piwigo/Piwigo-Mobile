//
//  LoginViewController_iPad.m
//  piwigo
//
//  Created by Olaf on 31.03.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LoginViewController_iPad.h"
#import "Model.h"

@interface LoginViewController_iPad ()

@property (nonatomic, strong) NSArray* portraitConstraints;
@property (nonatomic, strong) NSArray* landscapeConstraints;

@end

@implementation LoginViewController_iPad

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    // Display security message below credentials if needed
    self.websiteNotSecure.hidden = [[Model sharedInstance].serverProtocol isEqualToString:@"https://"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setupAutoLayout
{
    NSInteger textFieldHeight = 64;
    NSInteger alertLabelHeight = 24;
    
    NSDictionary *views = @{
                            @"logo" : self.piwigoLogo,
                            @"login" : self.loginButton,
                            @"server" : self.serverTextField,
                            @"user" : self.userTextField,
                            @"password" : self.passwordTextField,
                            @"notSecure" : self.websiteNotSecure
                            };
    NSDictionary *metrics = @{
                              @"imageSide" : @25,
                              @"imageTop" : @40,
                              @"imageBottom" : @20,
                              @"side" : @35,
                              @"landspaceSpacer" : @100
                              };
    self.topConstraintAmount = 40;
    
    NSMutableArray *logoPortrait = [NSMutableArray new];
    
    [logoPortrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-imageTop-[logo]-imageBottom-[server]-[user]-[password]-[login]-10-[notSecure]"
                                                                              options:kNilOptions
                                                                              metrics:metrics
                                                                                views:views]];
    [logoPortrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-imageSide-[logo]-imageSide-|"
                                                                              options:kNilOptions
                                                                              metrics:metrics
                                                                                views:views]];
    [logoPortrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[server]-side-|"
                                                                              options:kNilOptions
                                                                              metrics:metrics
                                                                                views:views]];
    [logoPortrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[user]-side-|"
                                                                              options:kNilOptions
                                                                              metrics:metrics
                                                                                views:views]];
    [logoPortrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[password]-side-|"
                                                                              options:kNilOptions
                                                                              metrics:metrics
                                                                                views:views]];
    
    [logoPortrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[login]-side-|"
                                                                              options:kNilOptions
                                                                              metrics:metrics
                                                                                views:views]];

    [logoPortrait addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[notSecure]-side-|"
                                                                              options:kNilOptions
                                                                              metrics:metrics
                                                                                views:views]];

    self.portraitConstraints = [NSArray arrayWithArray:logoPortrait];
    
    NSMutableArray *logoLandscape = [NSMutableArray new];
    [logoLandscape addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-landspaceSpacer-[server]-[user]-[password]-[login]"
                                                                               options:kNilOptions
                                                                               metrics:metrics
                                                                                 views:views]];
    [logoLandscape addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[server(==logo)]-side-[logo]-side-|"
                                                                               options:NSLayoutFormatAlignAllTop
                                                                               metrics:metrics
                                                                                 views:views]];
    [logoLandscape addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[user]-side-[logo]-side-|"
                                                                               options:kNilOptions
                                                                               metrics:metrics
                                                                                 views:views]];
    [logoLandscape addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[password]-side-[logo]-side-|"
                                                                               options:kNilOptions
                                                                               metrics:metrics
                                                                                 views:views]];
    
    [logoLandscape addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[login]-side-[logo]-side-|"
                                                                               options:kNilOptions
                                                                               metrics:metrics
                                                                                 views:views]];

    [logoLandscape addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-side-[notSecure]-side-[logo]-side-|"
                                                                               options:kNilOptions
                                                                               metrics:metrics
                                                                                 views:views]];
    
    self.landscapeConstraints = [NSArray arrayWithArray:logoLandscape];
    
    [self.piwigoLogo addConstraint:[NSLayoutConstraint constraintView:self.piwigoLogo toHeight:textFieldHeight + 36]];
    
    [self.serverTextField addConstraint:[NSLayoutConstraint constraintView:self.serverTextField toHeight:textFieldHeight]];
    
    [self.userTextField addConstraint:[NSLayoutConstraint constraintView:self.userTextField toHeight:textFieldHeight]];
    
    [self.passwordTextField addConstraint:[NSLayoutConstraint constraintView:self.passwordTextField toHeight:textFieldHeight]];
    
    [self.loginButton addConstraint:[NSLayoutConstraint constraintView:self.loginButton toHeight:textFieldHeight]];

    [self.websiteNotSecure addConstraint:[NSLayoutConstraint constraintView:self.websiteNotSecure toHeight:alertLabelHeight]];
}

-(void)updateViewConstraints {
    [self.view removeConstraints:self.portraitConstraints];
    [self.view removeConstraints:self.landscapeConstraints];
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
        [self.view addConstraints:self.landscapeConstraints];
    } else {
        [self.view addConstraints:self.portraitConstraints];
    }
    [super updateViewConstraints];
}

@end
