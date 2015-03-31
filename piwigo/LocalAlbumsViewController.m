//
//  LocalAlbumsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LocalAlbumsViewController.h"
#import "CategoryTableViewCell.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "Model.h"
#import "PhotosFetch.h"

@interface LocalAlbumsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *localAlbumsTableView;

@end

@implementation LocalAlbumsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		
		[[PhotosFetch sharedInstance] updateLocalPhotosDictionary:^(id responseObject) {
			[self.localAlbumsTableView reloadData];
		}];
		
		self.localAlbumsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.localAlbumsTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.localAlbumsTableView.delegate = self;
		self.localAlbumsTableView.dataSource = self;
		[self.localAlbumsTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.localAlbumsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localAlbumsTableView]];
		
	}
	return self;
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [PhotosFetch sharedInstance].localImages.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	NSURL *groupURLString = [PhotosFetch sharedInstance].localImages.allKeys[indexPath.row];
	
	[[Model defaultAssetsLibrary] groupForURL:groupURLString resultBlock:^(ALAssetsGroup *group) {
		NSString *name = [group valueForProperty:ALAssetsGroupPropertyName];
		[cell setCellLeftLabel:name];
	} failureBlock:^(NSError *error) {
		NSLog(@"fail %@", [error localizedDescription]);
	}];
	
	
	return cell;
}

@end
