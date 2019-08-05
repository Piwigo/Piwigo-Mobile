//
//  TagSelectViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "AppDelegate.h"
#import "Model.h"
#import "PiwigoTagData.h"
#import "TaggedImagesViewController.h"
#import "TagSelectViewController.h"
#import "TagsData.h"

@interface TagSelectViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tagsTableView;
@property (nonatomic, strong) NSArray *letterIndex;

@end

@implementation TagSelectViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.view.backgroundColor = [UIColor piwigoBackgroundColor];
                
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
        
        // ABC index
        [[TagsData sharedInstance] getTagsOnCompletion:^(NSArray *tags) {
            
            // Build ABC index
            NSMutableSet *firstCharacters = [NSMutableSet setWithCapacity:0];
            for( NSString *string in [[TagsData sharedInstance].tagList valueForKey:@"tagName"] )
                [firstCharacters addObject:[[string substringToIndex:1] uppercaseString]];
            
            self.letterIndex = [[firstCharacters allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
            [self.tagsTableView reloadData];
        }];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)paletteChanged
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    
    // Table view
    self.tagsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    self.tagsTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.tagsTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Title
    self.title = NSLocalizedString(@"tagsTitle_selectOne", @"Select a Tag");

    // Set colors, fonts, etc.
    [self paletteChanged];
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
    cell.textLabel.text = [Model sharedInstance].hasAdminRights ? currentTag.tagName : [NSString stringWithFormat:@"%@ (%ld)", currentTag.tagName, (long)currentTag.numberOfImagesUnderTag];
    
    return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // Push tagged images view
    if([self.tagSelectDelegate respondsToSelector:@selector(pushTaggedImagesView:)])
    {
        PiwigoTagData *currentTag = [TagsData sharedInstance].tagList[indexPath.row];
        TaggedImagesViewController *taggedImagesVC = [[TaggedImagesViewController alloc] initWithTagId:currentTag.tagId andTagName:currentTag.tagName];
        [self.tagSelectDelegate pushTaggedImagesView:taggedImagesVC];
    }

    // Dismiss tag select
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
