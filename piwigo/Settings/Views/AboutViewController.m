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
		self.view.backgroundColor = [UIColor piwigoBackgroundColor];
		self.title = NSLocalizedString(@"settings_acknowledgements", @"Acknowledgements");
		
		self.piwigoTitle = [UILabel new];
		self.piwigoTitle.translatesAutoresizingMaskIntoConstraints = NO;
		self.piwigoTitle.font = [UIFont piwigoFontNormal];
		self.piwigoTitle.font = [self.piwigoTitle.font fontWithSize:30];
		self.piwigoTitle.textColor = [UIColor piwigoOrange];
		self.piwigoTitle.text = NSLocalizedString(@"settings_appName", @"Piwigo Mobile");
		[self.view addSubview:self.piwigoTitle];
		
		self.byLabel1 = [UILabel new];
		self.byLabel1.translatesAutoresizingMaskIntoConstraints = NO;
		self.byLabel1.font = [UIFont piwigoFontNormal];
		self.byLabel1.font = [self.byLabel1.font fontWithSize:16];
		self.byLabel1.textColor = [UIColor piwigoWhiteCream];
		self.byLabel1.text = NSLocalizedStringFromTableInBundle(@"authors1", @"About", [NSBundle mainBundle], @"By Spencer Baker, Olaf Greck,");
		[self.view addSubview:self.byLabel1];
		
        self.byLabel2 = [UILabel new];
        self.byLabel2.translatesAutoresizingMaskIntoConstraints = NO;
        self.byLabel2.font = [UIFont piwigoFontNormal];
        self.byLabel2.font = [self.byLabel2.font fontWithSize:16];
        self.byLabel2.textColor = [UIColor piwigoWhiteCream];
        self.byLabel2.text = NSLocalizedStringFromTableInBundle(@"authors2", @"About", [NSBundle mainBundle], @"and Eddy Lelièvre-Berna");
        [self.view addSubview:self.byLabel2];

        self.versionLabel = [UILabel new];
		self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.versionLabel.font = [UIFont piwigoFontNormal];
		self.versionLabel.font = [self.versionLabel.font fontWithSize:10];
		self.versionLabel.textColor = [UIColor piwigoWhiteCream];
		[self.view addSubview:self.versionLabel];
		
		NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		NSString * appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		self.versionLabel.text = [NSString stringWithFormat:@"— %@ %@ (%@) —", NSLocalizedString(@"Version:", nil), appVersionString, appBuildString];
		
		self.textView = [UITextView new];
        self.textView.restorationIdentifier = @"thanks+licenses";
		self.textView.translatesAutoresizingMaskIntoConstraints = NO;
		self.textView.layer.cornerRadius = 5;
		
        // Release notes attributed string
//        NSMutableAttributedString *aboutAttributedString = [[NSMutableAttributedString alloc] initWithString:@"\n\n\n\n\n"];
        NSMutableAttributedString *aboutAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];

        // Translators — Bundle string
        NSAttributedString *translatorsString = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"translators_text", @"About", [NSBundle mainBundle], @"Translators text")];
        [aboutAttributedString appendAttributedString:translatorsString];

        // About string — Bundle string
        NSAttributedString *introString = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"about_text", @"About", [NSBundle mainBundle], @"Introduction text")];
        [aboutAttributedString appendAttributedString:introString];
        
        // MIT Licence — Bundle string
        NSString *mitString = NSLocalizedStringFromTableInBundle(@"licenceMIT_text", @"About", [NSBundle mainBundle], @"AFNetworking licence text");
        NSRange mitTitleRange = NSMakeRange(0, [mitString rangeOfString:@"\n"].location);
        NSMutableAttributedString *mitAttributedString = [[NSMutableAttributedString alloc] initWithString:mitString];
        [mitAttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:mitTitleRange];
        [aboutAttributedString appendAttributedString:mitAttributedString];

        // AFNetworking Licence — Bundle string
        NSString *afnString = NSLocalizedStringFromTableInBundle(@"licenceAFN_text", @"About", [NSBundle mainBundle], @"AFNetworking licence text");
        NSRange afnTitleRange = NSMakeRange(0, [afnString rangeOfString:@"\n"].location);
        NSMutableAttributedString *afnAttributedString = [[NSMutableAttributedString alloc] initWithString:afnString];
        [afnAttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:afnTitleRange];
        [aboutAttributedString appendAttributedString:afnAttributedString];

        // MBProgressHUD Licence — Bundle string
        NSString *mbpHudString = NSLocalizedStringFromTableInBundle(@"licenceMBProgHUD_text", @"About", [NSBundle mainBundle], @"MBProgressHUD licence text");
        NSRange mbpHudRange = NSMakeRange(0, [mbpHudString rangeOfString:@"\n"].location);
        NSMutableAttributedString *mbpHudAttributedString = [[NSMutableAttributedString alloc] initWithString:mbpHudString];
        [mbpHudAttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:mbpHudRange];
        [aboutAttributedString appendAttributedString:mbpHudAttributedString];

        // MGSwipeTableCell Licence — Bundle string
        NSString *mgstcString = NSLocalizedStringFromTableInBundle(@"licenceMGSTC_text", @"About", [NSBundle mainBundle], @"MGSwipeTableCell licence text");
        NSRange mgstcRange = NSMakeRange(0, [mgstcString rangeOfString:@"\n"].location);
        NSMutableAttributedString *mgstcAttributedString = [[NSMutableAttributedString alloc] initWithString:mgstcString];
        [mgstcAttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:mgstcRange];
        [aboutAttributedString appendAttributedString:mgstcAttributedString];

        // UICountingLabel Licence — Bundle string
        NSString *uiclString = NSLocalizedStringFromTableInBundle(@"licenceUICL_text", @"About", [NSBundle mainBundle], @"UICountingLabel licence text");
        NSRange uiclRange = NSMakeRange(0, [uiclString rangeOfString:@"\n"].location);
        NSMutableAttributedString *uiclAttributedString = [[NSMutableAttributedString alloc] initWithString:uiclString];
        [uiclAttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:uiclRange];
        [aboutAttributedString appendAttributedString:uiclAttributedString];
        
        // SAMKeychain Licence — Bundle string
        NSString *samString = NSLocalizedStringFromTableInBundle(@"licenceSAM_text", @"About", [NSBundle mainBundle], @"SAMKeychain licence text");
        NSRange samRange = NSMakeRange(0, [samString rangeOfString:@"\n"].location);
        NSMutableAttributedString *samAttributedString = [[NSMutableAttributedString alloc] initWithString:samString];
        [samAttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:samRange];
        [aboutAttributedString appendAttributedString:samAttributedString];
        
        self.textView.attributedText = aboutAttributedString;
        self.textView.editable = NO;
        self.textView.allowsEditingTextAttributes = NO;
        self.textView.selectable = YES;
        [self.view addSubview:self.textView];

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
	
    if (@available(iOS 11, *)) {
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-[title]-[by1][by2]-3-[usu]-10-[textView]-|"
                                   options:kNilOptions metrics:nil views:views]];
    } else {
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-80-[title]-[by1][by2]-3-[usu]-10-[textView]-60-|"
                                   options:kNilOptions metrics:nil views:views]];
    }

	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[textView]-|"
																	  options:kNilOptions
																	  metrics:nil
																		views:views]];
}

@end
