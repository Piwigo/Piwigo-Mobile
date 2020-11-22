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

-(void)viewDidLoad
{
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
    NSInteger side = 40;
    CGFloat textFieldHeight = 64;
    NSInteger textFieldWidth = 500;
    
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
    
    // ==> Portrait
    NSMutableArray *portrait = [NSMutableArray new];
    NSDictionary *metrics = @{
                              @"side" : @(side),
                              @"width" : @(textFieldWidth),
                              @"logoWidth" : @(textFieldHeight * 4.02),
                              @"height" : @(textFieldHeight)
                              };
    
    // Vertically
    [portrait addObject:[NSLayoutConstraint constraintViewFromTop:self.loginButton amount:(fmax([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) / 2.0 + textFieldHeight + 2 * 10.0)]];

    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"V:|-(>=30,<=100)-[logo(height)]-(>=20)-[url(==logo)]-15-[server(==logo)]-15-[user(==logo)]-15-[password(==logo)]-15-[login(==logo)]-15-[notSecure]-(>=30)-[by1][by2]-3-[usu]-20-|"
                               options:kNilOptions metrics:metrics views:views]];

    // Horizontally
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoLogo]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[logo(logoWidth)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoButton]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"H:|-(>=side)-[url(width)]-(>=side)-|"
                                   options:kNilOptions metrics:metrics views:views]];
    
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.serverTextField]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[server(width)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.userTextField]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[user(width)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.passwordTextField]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[password(width)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.loginButton]];
    [portrait addObjectsFromArray:[NSLayoutConstraint
          constraintsWithVisualFormat:@"H:|-(>=side)-[login(width)]-(>=side)-|"
                              options:kNilOptions metrics:metrics views:views]];

    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.websiteNotSecure]];
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel1]];
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel2]];
    [portrait addObject:[NSLayoutConstraint constraintCenterVerticalView:self.versionLabel]];

    self.portraitConstraints = [NSArray arrayWithArray:portrait];

    
    // ==> Landscape
    CGFloat logoHeight = textFieldHeight + 36.0;
    CGFloat logoWidth = floorf(logoHeight * 4.02);
    CGFloat landscapeSide = floorf([UIScreen mainScreen].bounds.size.width - logoWidth - side - textFieldWidth) / 2.0;
    metrics = @{
                @"side" : @(landscapeSide),
                @"gap"  : @(side),
                @"width" : @(textFieldWidth),
                @"logoWidth" : @(logoWidth),
                @"logoHeight" : @(logoHeight),
                @"height" : @(textFieldHeight)
                };

    NSMutableArray *landscape = [NSMutableArray new];

    // Vertically
    [landscape addObject:[NSLayoutConstraint constraintViewFromTop:self.loginButton amount:(fmin([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) / 2.0 + textFieldHeight + 2 * 10.0)]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
                                    constraintsWithVisualFormat:@"V:[server(height)]-15-[user(height)]-15-[password(height)]-15-[login(height)]-15-[notSecure]"
                                    options:kNilOptions metrics:metrics views:views]];

    [landscape addObject:[NSLayoutConstraint constraintView:self.piwigoLogo toHeight:logoHeight]];
    [landscape addObject:[NSLayoutConstraint constraintView:self.piwigoLogo toWidth:logoWidth]];

    [landscape addObject:[NSLayoutConstraint constraintWithItem:self.byLabel1
                                                      attribute:NSLayoutAttributeTop
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:self.loginButton
                                                      attribute:NSLayoutAttributeTop
                                                     multiplier:1.0
                                                       constant:0]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"V:[by1][by2]-3-[usu]"
                               options:kNilOptions metrics:metrics views:views]];

    // Horizontally
    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-gap-[server(width)]-(>=side)-|"
                               options:NSLayoutFormatAlignAllTop metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-gap-[user(==server)]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-gap-[password(==server)]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-gap-[login(==server)]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[logo]-gap-[notSecure(==server)]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[url(==logo)]-gap-[user]-(>=side)-|"
                               options:NSLayoutFormatAlignAllBottom metrics:metrics views:views]];
    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[by1]-gap-[login]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];
    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[by2]-gap-[login]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];
    [landscape addObjectsFromArray:[NSLayoutConstraint
           constraintsWithVisualFormat:@"H:|-(>=side)-[usu]-gap-[login]-(>=side)-|"
                               options:kNilOptions metrics:metrics views:views]];

    self.landscapeConstraints = [NSArray arrayWithArray:landscape];
}

-(void)updateViewConstraints {
    [self.view removeConstraints:self.portraitConstraints];
    [self.view removeConstraints:self.landscapeConstraints];
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
    {
        [self.view addConstraints:self.landscapeConstraints];
    }
    else {
        [self.view addConstraints:self.portraitConstraints];
    }
    [super updateViewConstraints];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    
    // Update constraints
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.view removeConstraints:self.portraitConstraints];
        [self.view removeConstraints:self.landscapeConstraints];
        if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        {
            [self.view addConstraints:self.landscapeConstraints];
        }
        else {
            [self.view addConstraints:self.portraitConstraints];
        }
    } completion:nil];

    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

@end
