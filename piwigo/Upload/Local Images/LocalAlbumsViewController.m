//
//  LocalAlbumsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "LocalAlbumsViewController.h"
#import "CategoryTableViewCell.h"
#import "Model.h"
#import "PhotosFetch.h"
#import "UploadViewController.h"

@interface LocalAlbumsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *localAlbumsTableView;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) NSArray *groups;

@end

@implementation LocalAlbumsViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.categoryId = categoryId;
		
		self.title = NSLocalizedString(@"localAlbums", @"Local Albums");
		
		self.groups = [NSArray new];
		[[PhotosFetch sharedInstance] getLocalGroupsOnCompletion:^(id responseObject) {
			if([responseObject isKindOfClass:[NSNumber class]])
			{	// make view disappear
				[self.navigationController popToRootViewControllerAnimated:YES];
			}
			else if(responseObject == nil)
			{
                UIAlertController* alert = [UIAlertController
                            alertControllerWithTitle:NSLocalizedString(@"localAlbums_photosNiltitle", @"Problem Reading Photos")
                            message:NSLocalizedString(@"localAlbums_photosNnil_msg", @"There is a problem reading your local photo library.")
                            preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction* dismissAction = [UIAlertAction
                                                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                                style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction * action) {
                                                    // make view disappear
                                                    [self.navigationController popViewControllerAnimated:YES];
                                                }];
                
                [alert addAction:dismissAction];
                [self presentViewController:alert animated:YES completion:nil];
            }
			else
			{
				self.groups = responseObject;
				[self.localAlbumsTableView reloadData];
			}
		}];
		
		self.localAlbumsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.localAlbumsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.localAlbumsTableView.backgroundColor = [UIColor piwigoGray];
		self.localAlbumsTableView.delegate = self;
		self.localAlbumsTableView.dataSource = self;
		[self.localAlbumsTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.localAlbumsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localAlbumsTableView]];
		
	}
	return self;
}


#pragma mark UITableView Methods

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 64.0;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
    
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoOrange];
    headerLabel.text = NSLocalizedString(@"categoryUpload_chooseLocalAlbum", @"Select an album to get images from");
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
    [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    
    return header;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.groups.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	PHAssetCollection *groupAsset = [self.groups objectAtIndex:indexPath.row];
    NSString *name = [groupAsset localizedTitle];
    NSUInteger nberAssets = [[PHAsset fetchAssetsInAssetCollection:groupAsset options:nil] count];
    [cell setCellLeftLabel:[NSString stringWithFormat:@"%@ (%@ %@)", name, @(nberAssets), (nberAssets > 1) ?NSLocalizedString(@"severalImages", @"Images") : NSLocalizedString(@"singleImage", @"Image")]];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	UploadViewController *uploadVC = [[UploadViewController alloc] initWithCategoryId:self.categoryId andGroupAsset:[self.groups objectAtIndex:indexPath.row]];
	[self.navigationController pushViewController:uploadVC animated:YES];
	
}

@end
