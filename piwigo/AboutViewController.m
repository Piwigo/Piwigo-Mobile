//
//  AboutViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AboutViewController.h"

@interface AboutViewController ()

@property (nonatomic, strong) UILabel *piwigoTitle;
@property (nonatomic, strong) UILabel *byLabel1;
@property (nonatomic, strong) UILabel *byLabel2;
@property (nonatomic, strong) UILabel *versionLabel;

@property (nonatomic, strong) UITextView *textView;

@end

@implementation AboutViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		self.title = NSLocalizedString(@"settingsHeader_about", @"About");
		
		self.piwigoTitle = [UILabel new];
		self.piwigoTitle.translatesAutoresizingMaskIntoConstraints = NO;
		self.piwigoTitle.font = [UIFont piwigoFontNormal];
		self.piwigoTitle.font = [self.piwigoTitle.font fontWithSize:30];
		self.piwigoTitle.textColor = [UIColor piwigoOrange];
		self.piwigoTitle.text = @"Piwigo Mobile";
		[self.view addSubview:self.piwigoTitle];
		
		self.byLabel1 = [UILabel new];
		self.byLabel1.translatesAutoresizingMaskIntoConstraints = NO;
		self.byLabel1.font = [UIFont piwigoFontNormal];
		self.byLabel1.font = [self.byLabel1.font fontWithSize:19];
		self.byLabel1.textColor = [UIColor piwigoGrayLight];
		self.byLabel1.text = @"By Spencer Baker, Olaf Greck,";
		[self.view addSubview:self.byLabel1];
		
        self.byLabel2 = [UILabel new];
        self.byLabel2.translatesAutoresizingMaskIntoConstraints = NO;
        self.byLabel2.font = [UIFont piwigoFontNormal];
        self.byLabel2.font = [self.byLabel2.font fontWithSize:19];
        self.byLabel2.textColor = [UIColor piwigoGrayLight];
        self.byLabel2.text = @"and Eddy Lelièvre-Berna";
        [self.view addSubview:self.byLabel2];

        self.versionLabel = [UILabel new];
		self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.versionLabel.font = [UIFont piwigoFontNormal];
		self.versionLabel.font = [self.versionLabel.font fontWithSize:12];
		self.versionLabel.textColor = [UIColor piwigoGrayLight];
		[self.view addSubview:self.versionLabel];
		
		NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		NSString * appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		self.versionLabel.text = [NSString stringWithFormat:@"%@ %@ (%@)", NSLocalizedString(@"version", nil), appVersionString, appBuildString];
		
		self.textView = [UITextView new];
		self.textView.translatesAutoresizingMaskIntoConstraints = NO;
		self.textView.layer.cornerRadius = 5;
		[self.view addSubview:self.textView];
		
		NSString *aboutString = NSLocalizedStringFromTableInBundle(@"about_text", @"About", [NSBundle mainBundle], @"About text");
		NSMutableAttributedString *aboutAttributedString = [[NSMutableAttributedString alloc] initWithString:aboutString];
		
//		NSRange range = NSMakeRange(0, aboutString.length);
//		[aboutAttributedString addAttribute:NSFontAttributeName
//									  value:[UIFont systemFontOfSize:18]
//									  range:range];
		NSRange afnetworkingRange = [aboutString rangeOfString:@"AFNetworking"];
		NSRange piwigoDescriptionRange = NSMakeRange(0, afnetworkingRange.location);
		[aboutAttributedString addAttribute:NSFontAttributeName
									  value:[UIFont systemFontOfSize:18]
									  range:piwigoDescriptionRange];

        NSRange afnetworkingDescriptionRange = NSMakeRange(afnetworkingRange.location, [@"AFNetworking" length]);
        [aboutAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont systemFontOfSize:14]
                                      range:afnetworkingDescriptionRange];

        NSRange mgSwipeTCRange = [aboutString rangeOfString:@"MGSwipeTableCell"];
        NSRange mgSwipeTCDescriptionRange = NSMakeRange(mgSwipeTCRange.location, [@"MGSwipeTableCell" length]);
        [aboutAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont systemFontOfSize:14]
                                      range:mgSwipeTCDescriptionRange];
        
        NSRange uiCountingLabelRange = [aboutString rangeOfString:@"UICountingLabel"];
        NSRange uiCountingLabelDescriptionRange = NSMakeRange(uiCountingLabelRange.location, [@"UICountingLabel" length]);
        [aboutAttributedString addAttribute:NSFontAttributeName
                                      value:[UIFont systemFontOfSize:14]
                                      range:uiCountingLabelDescriptionRange];
        
        self.textView.attributedText = aboutAttributedString;
		
		[self addConstraints];
	}
	return self;
}

-(void)addConstraints
{
	NSDictionary *views = @{
							@"title" : self.piwigoTitle,
							@"by1" : self.byLabel1,
                            @"by2" : self.byLabel2,
							@"usu" : self.versionLabel,
							@"textView" : self.textView
							};
	
	[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoTitle]];
	[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel1]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel2]];
	[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.versionLabel]];
	
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-80-[title]-15-[by1]-[by2][usu]-20-[textView]-65-|"
																	  options:kNilOptions
																	  metrics:nil
																		views:views]];
	
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[textView]-10-|"
																	  options:kNilOptions
																	  metrics:nil
																		views:views]];
}

@end
