//
//  ViewMinerRelationDataCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewMinerRelationDataCell : UITableViewCellBase

@property (nonatomic, strong) NSDictionary* item;
@property (nonatomic, assign) BOOL is_miner;

@end
