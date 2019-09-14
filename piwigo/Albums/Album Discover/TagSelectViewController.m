//
//  TagSelectViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

CGFloat const kTagSelectViewWidth = 368.0;      // TagSelect view width

#import "AppDelegate.h"
#import "Model.h"
#import "PiwigoTagData.h"
#import "TaggedImagesViewController.h"
#import "TagSelectViewController.h"
#import "TagsData.h"

@interface TagSelectViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tagsTableView;
@property (nonatomic, strong) NSArray *letterIndex;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;

@end

@implementation TagSelectViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.tagsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.tagsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.tagsTableView.backgroundColor = [UIColor clearColor];
        self.tagsTableView.sectionIndexColor = [UIColor piwigoOrange];
        self.tagsTableView.alwaysBounceVertical = YES;
        self.tagsTableView.showsVerticalScrollIndicator = YES;
        self.tagsTableView.delegate = self;
        self.tagsTableView.dataSource = self;
        [self.view addSubview:self.tagsTableView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.tagsTableView]];

        // Button for returning to albums/images
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(quitTagSelect)];
        
        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyPaletteSettings) name:kPiwigoNotificationPaletteChanged object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)applyPaletteSettings
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    // Table view
    self.tagsTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.tagsTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Set colors, fonts, etc.
    [self applyPaletteSettings];

    // Title
    self.title = NSLocalizedString(@"tagsTitle_selectOne", @"Select a Tag");

    // Add Cancel button
    [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];

    // Load tags and build ABC index
    [[TagsData sharedInstance] getTagsForAdmin:NO onCompletion:^(NSArray *tags) {
        
        // Build ABC index
        NSMutableSet *firstCharacters = [NSMutableSet setWithCapacity:0];
        for( NSString *string in [[TagsData sharedInstance].tagList valueForKey:@"tagName"] )
            [firstCharacters addObject:[[string substringToIndex:1] uppercaseString]];
        
        self.letterIndex = [[firstCharacters allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        [self.tagsTableView reloadData];
    }];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // On iPad, the TagSelect view is presented attached to the Discover button
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
            self.preferredContentSize = CGSizeMake(kTagSelectViewWidth, ceil(CGRectGetHeight(mainScreenBounds)*2/3));
        }
        
        // Reload table view
        [self.tagsTableView reloadData];
    } completion:nil];
}

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Should we update user interface based on the appearance?
    if (@available(iOS 13.0, *)) {
        BOOL hasUserInterfaceStyleChanged = [previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:self.traitCollection];
        if (hasUserInterfaceStyleChanged) {
            NSLog(@"AlbumImages => did change, previous was %@", previousTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? @"Dark" :  @"Light");
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate setColorPalette];
        }
    } else {
        // Fallback on earlier versions
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Do not show album title in backButtonItem of child view to provide enough space for image title
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
        self.title = @"";
    }
}

-(void)quitTagSelect
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ABC index

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.letterIndex;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    
    NSInteger newRow = [self indexForFirstChar:title inArray:[[TagsData sharedInstance].tagList valueForKey:@"tagName"]];
    NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:newRow inSection:0];
    [tableView scrollToRowAtIndexPath:newIndexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
    
    return index;
}

// Return the index of the first occurence of an item that begins with the supplied character
- (NSInteger)indexForFirstChar:(NSString *)character inArray:(NSArray *)array
{
    NSUInteger count = 0;
    for (NSString *aString in array) {
        if ([aString hasPrefix:character]) {
            return count;
        }
        count++;
    }
    return 0;
}


#pragma mark - UITableView - Rows

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[TagsData sharedInstance].tagList count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if(!cell)
    {
        cell = [UITableViewCell new];
    }
    
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];

    PiwigoTagData *currentTag;
    currentTag = [TagsData sharedInstance].tagList[indexPath.row];
        
    // => pwg.tags.getList returns in addition: counter, url
    NSInteger nber = currentTag.numberOfImagesUnderTag;
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%ld %@)", currentTag.tagName, (long)nber, nber > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
    
    return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // Dismiss tag select
    [self dismissViewControllerAnimated:YES completion:^{
        // Push tagged images view
        if([self.tagSelectDelegate respondsToSelector:@selector(pushTaggedImagesView:)])
        {
            PiwigoTagData *currentTag = [TagsData sharedInstance].tagList[indexPath.row];
            TaggedImagesViewController *taggedImagesVC = [[TaggedImagesViewController alloc] initWithTagId:currentTag.tagId andTagName:currentTag.tagName];
            [self.tagSelectDelegate pushTaggedImagesView:taggedImagesVC];
        }
    }];
}


#pragma mark - UITableView - Footer

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    // Footer height?
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setPositiveFormat:@"#,##0"];
    NSString *footer = [NSString stringWithFormat:@"%@ %@", [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[TagsData sharedInstance].tagList.count]], [TagsData sharedInstance].tagList.count > 1 ? NSLocalizedString(@"tags", @"Tags").lowercaseString : NSLocalizedString(@"tag" , @"Tag").lowercaseString];
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontLight]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:context];
    
    return fmax(44.0, ceil(footerRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    // Footer label
    UILabel *footerLabel = [UILabel new];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.font = [UIFont piwigoFontLight];
    footerLabel.textColor = [UIColor piwigoHeaderColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 1;
    
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setPositiveFormat:@"#,##0"];
    footerLabel.text = [NSString stringWithFormat:@"%@ %@", [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[TagsData sharedInstance].tagList.count]], [TagsData sharedInstance].tagList.count > 1 ? NSLocalizedString(@"tags", @"Tags").lowercaseString : NSLocalizedString(@"tag" , @"Tag").lowercaseString];
    footerLabel.adjustsFontSizeToFitWidth = NO;
    
    // Footer view
    UIView *footer = [[UIView alloc] init];
    footer.backgroundColor = [UIColor clearColor];
    [footer addSubview:footerLabel];
    [footer addConstraint:[NSLayoutConstraint constraintViewFromTop:footerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[footer]-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"footer" : footerLabel}]];
    } else {
        [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[footer]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"footer" : footerLabel}]];
    }
    
    return footer;
}

@end
