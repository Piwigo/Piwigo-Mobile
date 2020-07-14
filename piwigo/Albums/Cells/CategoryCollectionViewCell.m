//
//  CategoryCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController.h"
#import "AlbumTableViewCell.h"
#import "CategoriesData.h"
#import "CategoryCollectionViewCell.h"
#import "ImagesCollection.h"

@interface CategoryCollectionViewCell() <UITableViewDataSource, UITableViewDelegate, AlbumTableViewCellDelegate>

@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation CategoryCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.tableView = [UITableView new];
		self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.tableView.backgroundColor = [UIColor clearColor];
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [self.tableView registerNib:[UINib nibWithNibName:@"AlbumTableViewCell" bundle:nil] forCellReuseIdentifier:kAlbumTableCell_ID];
		self.tableView.delegate = self;
		self.tableView.dataSource = self;
		[self.contentView addSubview:self.tableView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.tableView]];
    
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated:) name:kPiwigoNotificationChangedAlbumData object:nil];
	}
	return self;
}

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
	self.albumData = albumData;
	[self.tableView reloadData];
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
	self.albumData = nil;
}

-(void)categoriesUpdated:(NSNotification *)notification
{
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;

        // Right category Id?
        NSInteger catId = [[userInfo objectForKey:@"albumId"] integerValue];
        if (catId != self.albumData.albumId) return;

        // Add or remove thumbnail image?
        NSString *thumbnailUrl = [userInfo objectForKey:@"thumbnailUrl"];
        if (thumbnailUrl.length == 0) {
            self.albumData.categoryImage = nil;
            self.albumData.albumThumbnailId = 0;
            self.albumData.albumThumbnailUrl = nil;
        } else {
            NSInteger thumbnailId = [[userInfo objectForKey:@"thumbnailId"] intValue];
            self.albumData.albumThumbnailId = thumbnailId;
            self.albumData.albumThumbnailUrl = thumbnailUrl;
        }
        [self.tableView reloadData];
    }
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 156.5;                    // see XIB file
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AlbumTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAlbumTableCell_ID forIndexPath:indexPath];
    if (!cell) {
        [tableView registerNib:[UINib nibWithNibName:@"AlbumTableViewCell" bundle:nil] forCellReuseIdentifier:kAlbumTableCell_ID];
        cell = [tableView dequeueReusableCellWithIdentifier:kAlbumTableCell_ID forIndexPath:indexPath];
    }

    cell.cellDelegate = self;
	[cell setupWithAlbumData:self.albumData];
	
    cell.isAccessibilityElement = YES;
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
    // Push new album view
    if([self.categoryDelegate respondsToSelector:@selector(pushView:)])
	{
		AlbumImagesViewController *albumView = [[AlbumImagesViewController alloc] initWithAlbumId:self.albumData.albumId inCache:YES];
		[self.categoryDelegate pushView:albumView];
	}
}

#pragma mark AlbumTableViewCellDelegate Methods

-(void)pushView:(UIViewController *)viewController
{
	if([self.categoryDelegate respondsToSelector:@selector(pushView:)])
	{
		[self.categoryDelegate pushView:viewController];
	}
}

@end
