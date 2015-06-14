//
//  CategoryMoveToViewController.m
//  piwigo
//
//  Created by Olaf Greck on 21/05/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryMoveToViewController.h"

#import "CategoriesData.h"
#import "CategoryTableViewCell.h"
#import "PiwigoAlbumData.h"
#import "PiwigoImageData.h"
#import "PiwigoPartialAlbumData.h"
#import "UploadService.h"

@interface CategoryMoveToViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSMutableDictionary *categoriesThatHaveLoadedSubCategories;
@property (nonatomic, strong) NSMutableArray *selectedAlbums;
@property (nonatomic, strong) NSMutableArray *filteredAlbums;

@property (nonatomic, strong) UISearchDisplayController *searchController;

@end

@implementation CategoryMoveToViewController

- (instancetype)init {
    return [self initWithSelectedImages:[NSArray new]];
}

-(instancetype)initWithSelectedImages:(NSArray *)selectedImages {
    self = [super initWithNibName:@"CategoryMoveToView" bundle:nil];
    if(self)
    {
        self.selectedImages = selectedImages;
        self.availableAlbums    = [NSMutableArray new];
        self.selectedAlbums     = [NSMutableArray new];
        self.categoriesThatHaveLoadedSubCategories = [NSMutableDictionary new];
        
        self.albumsTableView.backgroundColor = [UIColor piwigoWhiteCream];
        [self.albumsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
        [self.view addSubview:self.albumsTableView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.albumsTableView]];
        
        UIBarButtonItem *moveButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"keywords_Move", @"Move")
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(doTheMove)];
        [self.navigationItem setRightBarButtonItem:moveButton];
        
    }
    return self;
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.navigationController.navigationBar.translucent = NO;

}

-(void)viewDidLoadUniversal {
    [super viewDidLoad];
    self.navigationController.navigationBar.translucent = NO;
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)])
        self.edgesForExtendedLayout = UIRectEdgeNone;   // iOS 7 specific

    [self buildSelectedAlbumsArray];
    [self buildAllAlbumsArray];
    self.filteredAlbums = [NSMutableArray new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(albumDataUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
    // Hide the search bar until user scrolls up
    CGRect newBounds = self.albumsTableView.bounds;
    newBounds.origin.y = newBounds.origin.y + self.albumSearchBar.bounds.size.height;
    self.albumsTableView.bounds = newBounds;
    self.navigationItem.title = NSLocalizedString(@"linked_Albums", @"Linked albums");
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.albumSearchBar becomeFirstResponder];
    [self.searchDisplayController setActive:NO animated:YES];

}
-(void)albumDataUpdated
{
    [self buildSelectedAlbumsArray];
    [self buildAllAlbumsArray];
    [self.albumsTableView reloadData];
}

-(void)buildSelectedAlbumsArray {
    _selectedAlbums = [NSMutableArray new];
   for (PiwigoImageData *anImage in self.selectedImages) {
        NSArray *albumIds = anImage.categoryIds;
        for (NSNumber *albumId in albumIds) {
            PiwigoAlbumData *hostingAlbum = [[CategoriesData sharedInstance] getCategoryById:[albumId integerValue]];
            NSPredicate *predicateSelection = [NSPredicate predicateWithFormat:@"albumId IN %@",self.selectedAlbums];
            NSArray *selectedAlbums =  [self.selectedAlbums filteredArrayUsingPredicate:predicateSelection];
            if (selectedAlbums.count > 0) {
                PiwigoPartialAlbumData *partialAlbum = selectedAlbums.firstObject;
                [partialAlbum addImageAsMember:anImage];
            } else {
                PiwigoPartialAlbumData *partialAlbum = [[PiwigoPartialAlbumData alloc] initWithAlbum:hostingAlbum];
                [partialAlbum addImageAsMember:anImage];
                [self.selectedAlbums addObject:partialAlbum];
            }
        }
    }
}

-(void)buildAllAlbumsArray {
    _availableAlbums = [NSMutableArray new];
    NSMutableSet *selectedAlbums = [NSMutableSet new];
    for (PiwigoImageData *anImage in self.selectedImages) {
        [selectedAlbums addObjectsFromArray:anImage.categoryIds];
    }
    NSArray *source = [CategoriesData sharedInstance].allCategories;
    for (PiwigoAlbumData *someAlbum in source) {
        PiwigoPartialAlbumData *partialAlbum = [[PiwigoPartialAlbumData alloc] initWithAlbum:someAlbum];
        partialAlbum.isSelected = (nil != [selectedAlbums member:[NSNumber numberWithInteger:someAlbum.albumId]]);
        [self.availableAlbums addObject:partialAlbum];
    }
}

#pragma mark - Content Filtering
-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope {
    // Update the filtered array based on the search text and scope.
    // Remove all objects from the filtered search array
    [self.filteredAlbums removeAllObjects];
    // Filter the array using NSPredicate
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.albumName contains[c] %@",searchText];
    _filteredAlbums = [NSMutableArray arrayWithArray:[self.availableAlbums filteredArrayUsingPredicate:predicate]];
}

#pragma mark  UISearchDisplayController Delegate Methods
-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    // Tells the table data source to reload when text changes
    [self filterContentForSearchText:searchString scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    // Tells the table data source to reload when scope bar selection changes
    [self filterContentForSearchText:self.searchDisplayController.searchBar.text scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

#pragma mark -

-(void)doTheMove {
    // make set from selected album ids
    NSArray *destinationAlbumIds = [self.selectedAlbums valueForKey:@"albumId"];
    // or set with categories in image
    // update image with resulting set
    // remove form old cat
    // add to new cat
    for (PiwigoImageData *anImage in self.selectedImages) {
        NSArray * oldAlbumIds = anImage.categoryIds;
        MyLog(@"Image: %@, old Categories : %@", anImage.name, oldAlbumIds );
        // remove from old album
        [[CategoriesData sharedInstance]removeImage:anImage];
        // tell server
        anImage.categoryIds = destinationAlbumIds; //@[@(category.albumId)];
        [self sendUpdatedImageInfo:anImage];
    }
    for ( NSNumber *anAlbumId in destinationAlbumIds) {
        PiwigoAlbumData *newAlbum = [[CategoriesData sharedInstance] getCategoryById:[anAlbumId integerValue]];
        [newAlbum addImages:self.selectedImages];
    }
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

-(void)sendUpdatedImageInfo: (PiwigoImageData *)imageData {
    [UploadService updateAlbumsWithImageInfo:imageData
                        onProgress:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
                            // progress
                        } onCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
//                            [self performSelectorOnMainThread:@selector(postNotification:)
//                                                   withObject:[NSNotification notificationWithName:kPiwigoNotificationCategoryDataUpdated object:nil]
//                                                waitUntilDone:YES];

                        } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
                            // fail
                            MyLog(@"Fail error %@",error);
                        }];
}

//http://www.cocoawithlove.com/2009/08/safe-threaded-design-and-inter-thread.html
- (void)postNotification:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] postNotification:aNotification];
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 50.0;
}
-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
    
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoGray];
    headerLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    headerLabel.adjustsFontSizeToFitWidth = YES;
    headerLabel.minimumScaleFactor = 0.5;
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
    [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    
    return header;
}

#pragma mark UITableView Methods
-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return @"---- search results ----";
    } else {
        if (section == 0) {
            return NSLocalizedString(@"linked_Albums", @"Linked albums");
        } else {
            return NSLocalizedString(@"available_Album", @"Album");
        }
    }
}
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return 1;
    } else {
        return 2;
    }
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return self.filteredAlbums.count;
    } else {
    if (section == 0) {
        return self.selectedAlbums.count;
    } else {
        return self.availableAlbums.count;
    }
    }
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * aCellIdentifier = @"aCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:aCellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:aCellIdentifier];
    }
    PiwigoPartialAlbumData *albumData;

    if (tableView == self.searchDisplayController.searchResultsTableView) {
        albumData = [self.filteredAlbums objectAtIndex:indexPath.row];
        if (albumData.isSelected) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.textLabel.text = albumData.albumName;
        cell.detailTextLabel.text = albumData.albumPath;
    } else {
        
        if (indexPath.section == 0) {
            albumData = self.selectedAlbums[indexPath.row];
            cell.detailTextLabel.text = albumData.imageNames;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            albumData = [self.availableAlbums objectAtIndex:indexPath.row];
            cell.detailTextLabel.text = albumData.albumPath;
            if (albumData.isSelected) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
        cell.textLabel.text = albumData.albumName;
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PiwigoPartialAlbumData *albumData;
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        albumData = [self.filteredAlbums objectAtIndex:indexPath.row];
    } else {
        if (indexPath.section == 0) {
            albumData = self.selectedAlbums[indexPath.row];
        } else {
            albumData = _availableAlbums[indexPath.row]; // dont go via accessors, we want the object at that row, not a copy if it
        }
    }
    albumData.isSelected = (NO == albumData.isSelected); // toggle status
    if (albumData.isSelected) {         // now is selected, thus add to selection
        for (PiwigoImageData *anImage in self.selectedImages) {
            [albumData addImageAsMember:anImage];
        }
        [self.selectedAlbums addObject:albumData];
    } else {                            // remove selection
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.albumId == %d", albumData.albumId];
        NSArray *selectedAlbum = [NSArray arrayWithArray:[self.selectedAlbums filteredArrayUsingPredicate:predicate]];
        if (selectedAlbum.count >= 1) {
            [self.selectedAlbums removeObject:selectedAlbum.firstObject];
        }
        if (indexPath.section == 0) { // tapped on section 0, need to  update the row in section 1
            PiwigoPartialAlbumData *availAlbumData = _availableAlbums[indexPath.row];
            availAlbumData.isSelected = NO;
        }
    }
    [tableView reloadData];
}

@end
