//
//  BitsharesClientManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"
#import "Extension.h"
#import "BinSerializer.h"
#import "TransactionBuilder.h"

#include "bts_wallet_core.h"

/*
 *  (public) 隐私收据验证结果枚举。
 */
enum
{
    kBlindReceiptVerifyResultOK = 0,                    //  验证通过（收据有效）
    kBlindReceiptVerifyResultUnknownCommitment,         //  验证失败（未知收据）
    kBlindReceiptVerifyResultLoopLimitError,            //  伪造承诺生成达到最大上限
    kBlindReceiptVerifyResultCerError,                  //  非core资产汇率无效
    kBlindReceiptVerifyResultFeePoolBalanceNotEnouth,   //  非core资产手续费池不足
};

@interface BitsharesClientManager : NSObject

+ (BitsharesClientManager*)sharedBitsharesClientManager;

#pragma mark- api

/*
 *  OP - 手动构造 operation 和 添加 sign_key。对于一次性执行多个操作时需要。
 */
- (WsPromise*)buildAndRunTransaction:(void (^)(TransactionBuilder* builder))opration_build_callback;

/*
 *  OP - 执行单个 operation 的交易。（可指定是否需要 owner 权限。）
 */
- (WsPromise*)runSingleTransaction:(NSDictionary*)opdata
                            opcode:(EBitsharesOperations)opcode
                fee_paying_account:(NSString*)fee_paying_account
          require_owner_permission:(BOOL)require_owner_permission;

- (WsPromise*)runSingleTransaction:(NSDictionary*)opdata
                            opcode:(EBitsharesOperations)opcode
                fee_paying_account:(NSString*)fee_paying_account;

/**
 *  创建理事会成员 TODO：未完成
 */
- (WsPromise*)createMemberCommittee:(NSString*)committee_member_account_id url:(NSString*)url;

/**
 *  创建见证人成员 REMARK：需要终身会员权限。    TODO：未完成
 */
- (WsPromise*)createWitness:(NSString*)witness_account_id url:(NSString*)url signkey:(NSString*)block_signing_key;

/*
 *  OP - 转账（简化版）
 */
- (WsPromise*)simpleTransfer:(NSString*)from_name
                          to:(NSString*)to_name
                       asset:(NSString*)asset_name
                      amount:(NSString*)amount
                        memo:(NSString*)memo
             memo_extra_keys:(id)memo_extra_keys
               sign_pub_keys:(NSArray*)sign_pub_keys
                   broadcast:(BOOL)broadcast;

- (WsPromise*)simpleTransfer2:(id)full_from_account
                           to:(id)to_account
                        asset:(id)asset
                       amount:(NSString*)amount
                         memo:(NSString*)memo
              memo_extra_keys:(id)memo_extra_keys
                sign_pub_keys:(NSArray*)sign_pub_keys
                    broadcast:(BOOL)broadcast;

- (WsPromise*)transfer:(NSDictionary*)transfer_op_data;

/**
 *  更新帐号信息（投票 TODO:fowallet 目前仅支持修改new_options)
 */
- (WsPromise*)accountUpdate:(NSDictionary*)account_update_op_data;
/**
 *  OP - 升级帐号
 */
- (WsPromise*)accountUpgrade:(NSDictionary*)op_data;
/*
 *  OP - 转移账号
 */
- (WsPromise*)accountTransfer:(NSDictionary*)op_data;

- (WsPromise*)callOrderUpdate:(NSDictionary*)callorder_update_op;
- (WsPromise*)createLimitOrder:(NSDictionary*)limit_order_op;
- (WsPromise*)cancelLimitOrders:(NSArray*)cancel_limit_order_op_array;

/**
 *  OP - 创建待解冻金额
 */
- (WsPromise*)vestingBalanceCreate:(NSDictionary*)opdata;

/**
 *  OP - 提取待解冻金额
 */
- (WsPromise*)vestingBalanceWithdraw:(NSDictionary*)opdata;

/**
 *  OP - 存储账号自定义数据（REMARK：在 custom OP 的 data 字段中存储数据）
 */
- (WsPromise*)accountStorageMap:(NSString*)account opdata:(NSDictionary*)account_storage_map_opdata;
- (WsPromise*)accountStorageMap:(NSString*)account remove:(BOOL)remove catalog:(NSString*)catalog key_values:(NSArray*)key_values;

/**
 *  OP - 构造存储数据的 opdata
 */
- (id)buildOpData_accountStorageMap:(NSString*)account remove:(BOOL)remove catalog:(NSString*)catalog key_values:(NSArray*)key_values;

/**
 *  计算手续费
 */
- (WsPromise*)calcOperationFee:(EBitsharesOperations)opcode opdata:(id)opdata;

/**
 *  OP - 创建提案
 */
- (WsPromise*)proposalCreate:(NSArray*)opcode_data_object_array
                   opaccount:(id)opaccount
        proposal_create_args:(id)proposal_create_args;

/**
 *  OP - 更新提案（添加授权or移除授权）
 */
- (WsPromise*)proposalUpdate:(NSDictionary*)opdata;

/**
 *  OP -创建资产。
 */
- (WsPromise*)assetCreate:(NSDictionary*)opdata;

/**
 *  OP -全局清算资产。
 */
- (WsPromise*)assetGlobalSettle:(NSDictionary*)opdata;

/**
 *  OP -清算资产。
 */
- (WsPromise*)assetSettle:(NSDictionary*)opdata;

/**
 *  OP -更新资产基本信息。
 */
- (WsPromise*)assetUpdate:(NSDictionary*)opdata;

/**
 *  OP -更新智能币相关信息。
 */
- (WsPromise*)assetUpdateBitasset:(NSDictionary*)opdata;

/**
 *  OP -更新智能币的喂价人员信息。
 */
- (WsPromise*)assetUpdateFeedProducers:(NSDictionary*)opdata;

/**
 *  OP -销毁资产（减少当前供应量）REMARK：不能对智能资产进行操作。
 */
- (WsPromise*)assetReserve:(NSDictionary*)opdata;

/**
 *  OP -发行资产给某人
 */
- (WsPromise*)assetIssue:(NSDictionary*)opdata;

/**
 *  OP -注资资产的手续费池资金
 */
- (WsPromise*)assetFundFeePool:(NSDictionary*)opdata;

/**
 *  OP -提取资产的手续费池资金
 */
- (WsPromise*)assetClaimPool:(NSDictionary*)opdata;

/**
 *  OP -提取资产的市场手续费资金
 */
- (WsPromise*)assetClaimFees:(NSDictionary*)opdata;

/**
 *  OP - 更新资产发行者
 */
- (WsPromise*)assetUpdateIssuer:(NSDictionary*)opdata;

/**
 *  OP - 断言
 */
- (WsPromise*)assert:(NSDictionary*)opdata;

/**
 *  OP - 转入隐私账号
 */
- (WsPromise*)transferToBlind:(NSDictionary*)opdata;

/**
 *  OP - 从隐私账号转出
 */
- (WsPromise*)transferFromBlind:(NSDictionary*)opdata signPriKeyHash:(NSDictionary*)signPriKeyHash;

/**
 *  OP - 隐私转账
 */
- (WsPromise*)blindTransfer:(NSDictionary*)opdata signPriKeyHash:(NSDictionary*)signPriKeyHash;

/**
 *  OP - 验证隐私收据有效性。返回 kBlindReceiptVerify 枚举结果。REMARK：构造一个特殊的 blind_transfer 请求，获取错误信息。
 */
- (WsPromise*)verifyBlindReceipt:(id)check_blind_balance;

/**
 *  OP - 创建HTLC合约
 */
- (WsPromise*)htlcCreate:(NSDictionary*)opdata;

/**
 *  OP - 提取HTLC合约
 */
- (WsPromise*)htlcRedeem:(NSDictionary*)opdata;

/**
 *  OP - 扩展HTLC合约有效期
 */
- (WsPromise*)htlcExtend:(NSDictionary*)opdata;

/**
 *  OP - 创建锁仓（投票）
 */
- (WsPromise*)ticketCreate:(NSDictionary*)opdata;

/**
 *  OP - 更新锁仓（投票）
 */
- (WsPromise*)ticketUpdate:(NSDictionary*)opdata;

@end
