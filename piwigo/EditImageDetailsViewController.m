//
//  EditImageDetailsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageDetailsViewController.h"
#import "EditImageTextFieldTableViewCell.h"
#import "ImageUpload.h"

typedef enum {
	EditImageDetailsOrderImageName,
	EditImageDetailsOrderAuthor,
	EditImageDetailsOrderTags,
	EditImageDetailsOrderDescription,
	EditImageDetailsOrderCount
} EditImageDetailsOrder;

@interface EditImageDetailsViewController () <UITableViewDelegate, UITableViewDataSource>


@end

@implementation EditImageDetailsViewController


#pragma mark UITableView methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return EditImageDetailsOrderCount;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [UITableViewCell new];
	
	switch(indexPath.row)
	{
		case EditImageDetailsOrderImageName:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"textField"];
			[((EditImageTextFieldTableViewCell*)cell) setLabel:@"Image Name" andTextField:self.imageDetails.imageUploadName withPlaceholder:@"Image Name"];
			break;
		}
		case EditImageDetailsOrderAuthor:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"textField"];
			[((EditImageTextFieldTableViewCell*)cell) setLabel:@"Author" andTextField:self.imageDetails.author withPlaceholder:@"Author Name"];
			break;
		}
		case EditImageDetailsOrderTags:
		{
			break;
		}
		case EditImageDetailsOrderDescription:
		{
			break;
		}
	}
	
	return cell;
}

@end
