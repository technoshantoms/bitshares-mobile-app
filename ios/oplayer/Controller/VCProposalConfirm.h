//
//  VCProposalConfirm.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

typedef void (^BtsppConfirmCallback)(BOOL isOk, NSDictionary* proposal_create_args);

@interface VCProposalConfirm : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOpcodedataArray:(NSArray*)opcode_data_object_array
                    opaccount:(NSDictionary*)opaccount
                     callback:(BtsppConfirmCallback)callback;

@end
