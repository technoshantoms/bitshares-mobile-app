//
//  bts_chain_config.h
//  oplayer
//
//  Created by Aonichan on 16/1/15.
//
//

#ifndef __bts_chain_config__
#define __bts_chain_config__

/*
 *  石墨烯 custom OP 中数据子类型定义
 */
typedef enum EBitsharesCustomDataType
{
    ebcdt_account_map = 0,      //  账号自定义数据存储（插件）
} EBitsharesCustomOPDataType;

/*
 *  账号模式，密码语言枚举。
 */
typedef enum EBitsharesAccountPasswordLang
{
    ebap_lang_zh = 0,   //  中文密码（16个汉字）
    ebap_lang_en,       //  英文密码（32个字符 A-Za-z0-9）
    
} EBitsharesAccountPasswordLang;

/**
 *  石墨烯网络HTLC支持的Hash类型。
 */
typedef enum EBitsharesHtlcHashType
{
    EBHHT_RMD160 = 0,
    EBHHT_SHA1,
    EBHHT_SHA256
} EBitsharesHtlcHashType;

/*
 *  资产各种操作类型枚举 TODO:4.0 预测市场暂不考虑
 */
typedef enum EBitsharesAssetOpKind
{
    //  管理员的操作
    ebaok_view = 0,             //  资产详情
    ebaok_edit,                 //  资产编辑（基本信息）
    ebaok_issue,                //  资产发行（仅UIA资产）
    ebaok_override_transfer,    //  强制回收（需要开启对应权限标记）
    ebaok_global_settle,        //  全局清算（仅Smart资产，并且需要开启对应权限标记）
    ebaok_claim_pool,           //  提取手续费池（除Core外的所有资产）
    ebaok_claim_fees,           //  提取交易手续费（除Core外的所有资产）
    ebaok_fund_fee_pool,        //  注资手续费池（除Core外的所有资产）
    ebaok_update_issuer,        //  变更所有者（需要owner权限，且UIA不能转移给理事会）
    ebaok_publish_feed,         //  发布喂价（仅Smart资产）
    ebaok_update_feed_producers,//  更新喂价人员（仅Smart资产）
    ebaok_update_bitasset,      //  编辑智能币相关信息（仅Smart资产）
    ebaok_claim_collateral_fees,//  提取清算手续费和爆仓手续费（仅Smart资产）
    
    //  资产持有者的操作
    ebaok_transfer,             //  转账（所有资产）
    ebaok_trade,                //  交易（所有资产）
    ebaok_miner,                //  参与挖矿（仅针对NBS和CNY）
    ebaok_fast_swap,            //  退出挖矿（仅针对MINER和SCNY）
    ebaok_gateway_deposit,      //  充币（仅针对任意网关资产）
    ebaok_gateway_withdrawal,   //  提币（仅针对任意网关资产）
    ebaok_reserve,              //  资产销毁（仅UIA资产）
    ebaok_settle,               //  资产清算（仅Smart资产）
    ebaok_call_order_update,    //  调整债仓（仅Smart资产）
    ebaok_stake_vote,           //  锁仓投票（仅BTS）
    ebaok_more,                 //  虚拟按钮：更多
} EBitsharesAssetOpKind;

/**
 石墨烯网络资产的各种标记。
 */
typedef enum EBitsharesAssetFlags
{
    ebat_charge_market_fee    = 0x01,   //  收取交易手续费
    ebat_white_list           = 0x02,   //  要求资产持有人预先加入白名单
    ebat_override_authority   = 0x04,   //  发行人可将资产收回
    ebat_transfer_restricted  = 0x08,   //  所有转账必须通过发行人审核同意
    ebat_disable_force_settle = 0x10,   //  禁止强制清算
    ebat_global_settle        = 0x20,   //  允许发行人进行全局强制清算（仅可设置permission，不可设置flags）
    ebat_disable_confidential = 0x40,   //  禁止隐私交易
    ebat_witness_fed_asset    = 0x80,   //  允许见证人提供喂价（和理事会喂价不可同时激活）
    ebat_committee_fed_asset  = 0x100,  //  允许理事会成员提供喂价（和见证人喂价不可同时激活）
    
    ///@}
    /// @note If one of these bits is set in asset issuer permissions,
    ///       it means the asset issuer (or owner for bitassets) does NOT have the permission to update
    ///       the corresponding flag, parameters or perform certain actions.
    ///       This is to be compatible with old client software.
    ///@{
    ebat_lock_max_supply      = 0x200, ///< the max supply of the asset can not be updated
    ebat_disable_new_supply   = 0x400, ///< unable to create new supply for the asset
    /// @note These parameters are for issuer permission only.
    ///       For each parameter, if it is set in issuer permission,
    ///       it means the bitasset owner can not update the corresponding parameter.
    ///       In this case, if the value of the parameter was set by the bitasset owner, it can not be updated;
    ///       if no value was set by the owner, the value can still be updated by the feed producers.
    ///@{
    ebat_disable_mcr_update   = 0x800,  ///< the bitasset owner can not update MCR, permisison only
    ebat_disable_icr_update   = 0x1000, ///< the bitasset owner can not update ICR, permisison only
    ebat_disable_mssr_update  = 0x2000, ///< the bitasset owner can not update MSSR, permisison only
    ///@}
    ///@}
    
    //  UIA资产默认权限mask
    ebat_issuer_permission_mask_uia = ebat_charge_market_fee | ebat_white_list | ebat_override_authority | ebat_transfer_restricted | ebat_disable_confidential,
    //  Smart资产扩展的权限mask
    ebat_issuer_permission_mask_smart_only = ebat_disable_force_settle | ebat_global_settle | ebat_witness_fed_asset | ebat_committee_fed_asset,
    //  Smart资产默认权限mask
    ebat_issuer_permission_mask_smart = ebat_issuer_permission_mask_uia | ebat_issuer_permission_mask_smart_only,
} EBitsharesAssetFlags;

/**
 *  石墨烯账号黑白名单标记
 */
typedef enum EBitsharesWhiteListFlag
{
    ebwlf_no_listing = 0x0,                                                 //  无
    ebwlf_white_listed = 0x1,                                               //  在白名单，不在黑名单中。
    ebwlf_black_listed = 0x2,                                               //  在黑名单，不在白名单中。
    ebwlf_white_and_black_listed = ebwlf_white_listed | ebwlf_black_listed  //  同时在黑白名单中
} EBitsharesWhiteListFlag;

/**
 *  待解冻金额解禁策略
 */
typedef enum EBitsharesVestingPolicy
{
    ebvp_linear_vesting_policy = 0,         //  线性解禁
    ebvp_cdd_vesting_policy,                //  按币龄解禁
    ebvp_instant_vesting_policy             //  立即解禁
} EBitsharesVestingPolicy;

/**
 *  石墨烯网络投票类型定义
 */
typedef enum EBitsharesVoteType
{
    ebvt_committee = 0,             //  理事会
    ebvt_witness,                   //  见证人
    ebvt_worker                     //  预算项目
} EBitsharesVoteType;

/**
 *  石墨烯预算项目类型
 */
typedef enum EBitsharesWorkType
{
    ebwt_refund = 0,                //  refund
    ebwt_vesting,                   //  vesting
    ebwt_burn                       //  burn
} EBitsharesWorkType;

/**
 *  石墨烯权限类型
 */
typedef enum EBitsharesPermissionType
{
    ebpt_owner = 0,                 //  账号权限
    ebpt_active,                    //  资金权限
    ebpt_memo,                      //  备注权限
    ebpt_custom                     //  BSIP40自定义权限
} EBitsharesPermissionType;

/*
 *  石墨烯提案创建者所属安全等级（仅APP客户端存在）
 */
typedef enum EBitsharesProposalSecurityLevel
{
    ebpsl_whitelist = 0,                //  白名单成员发起（TODO:2.8暂时不支持白名单。）
    ebpsl_multi_sign_member_lv0,        //  待授权账号的直接多签成员发起的提案
    ebpsl_multi_sign_member_lv1,        //  多签自身也是多签管理（则由子账号发起，最多支持2级。）
    ebpsl_unknown                       //  陌生账号发起
} EBitsharesProposalSecurityLevel;

/*
 *  喂价者类型
 */
typedef enum EBitsharesFeedPublisherType
{
    ebfpt_witness = 0,              //  由见证人喂价
    ebfpt_committee,                //  由理事会喂价
    ebfpt_custom                    //  指定喂价者
} EBitsharesFeedPublisherType;

/**
 *  区块数据对象类型ID号定义
 */
typedef enum EBitsharesObjectType
{
    ebot_null = 0,
    ebot_base,
    ebot_account,
    ebot_asset,
    ebot_force_settlement,
    ebot_committee_member,          //  5
    ebot_witness,
    ebot_limit_order,               //  7
    ebot_call_order,                //  8
    ebot_custom,
    ebot_proposal,                  //  10
    ebot_operation_history,         //  11
    ebot_withdraw_permission,
    ebot_vesting_balance,
    ebot_worker,
    ebot_balance,
    ebot_htlc,                      //  16
    ebot_custom_authority,          //  17
    ebot_ticket,                    //  18
    
    ebot_max                        //  max_value
} EBitsharesObjectType;

/**
 *  各种交易操作枚举定义
 */
typedef enum EBitsharesOperations
{
    ebo_transfer = 0,
    ebo_limit_order_create = 1,
    ebo_limit_order_cancel = 2,
    ebo_call_order_update = 3,
    ebo_fill_order = 4,
    ebo_account_create = 5,
    ebo_account_update = 6,
    ebo_account_whitelist = 7,
    ebo_account_upgrade = 8,
    ebo_account_transfer = 9,
    ebo_asset_create = 10,
    ebo_asset_update = 11,
    ebo_asset_update_bitasset = 12,
    ebo_asset_update_feed_producers = 13,
    ebo_asset_issue = 14,
    ebo_asset_reserve = 15,
    ebo_asset_fund_fee_pool = 16,
    ebo_asset_settle = 17,
    ebo_asset_global_settle = 18,
    ebo_asset_publish_feed = 19,
    ebo_witness_create = 20,
    ebo_witness_update = 21,
    ebo_proposal_create = 22,
    ebo_proposal_update = 23,
    ebo_proposal_delete = 24,
    ebo_withdraw_permission_create = 25,
    ebo_withdraw_permission_update = 26,
    ebo_withdraw_permission_claim = 27,
    ebo_withdraw_permission_delete = 28,
    ebo_committee_member_create = 29,
    ebo_committee_member_update = 30,
    ebo_committee_member_update_global_parameters = 31,
    ebo_vesting_balance_create = 32,
    ebo_vesting_balance_withdraw = 33,
    ebo_worker_create = 34,
    ebo_custom = 35,
    ebo_assert = 36,
    ebo_balance_claim = 37,
    ebo_override_transfer = 38,
    ebo_transfer_to_blind = 39,
    ebo_blind_transfer = 40,
    ebo_transfer_from_blind = 41,
    ebo_asset_settle_cancel = 42,
    ebo_asset_claim_fees = 43,
    ebo_fba_distribute = 44,        // VIRTUAL
    ebo_bid_collateral = 45,
    ebo_execute_bid = 46,           // VIRTUAL
    ebo_asset_claim_pool = 47,
    ebo_asset_update_issuer = 48,
    ebo_htlc_create = 49,
    ebo_htlc_redeem = 50,
    ebo_htlc_redeemed = 51,         // VIRTUAL
    ebo_htlc_extend = 52,
    ebo_htlc_refund = 53,           // VIRTUAL
    ebo_custom_authority_create = 54,
    ebo_custom_authority_update = 55,
    ebo_custom_authority_delete = 56,
    ebo_ticket_create = 57,
    ebo_ticket_update = 58,
} EBitsharesOperations;

//  BTS公钥地址前缀
#define BTS_ADDRESS_PREFIX                  "ACB"

//  BTS公钥地址前缀长度 = strlen(BTS_ADDRESS_PREFIX)
//#define BTS_ADDRESS_PREFIX_LENGTH           3

//  交易过期时间？
#define BTS_CHAIN_EXPIRE_IN_SECS            15

//  TODO:4.0 大部分参数可通过 get_config 接口返回。

//  BTS主网公链ID（正式网络）
#define BTS_NETWORK_CHAIN_ID                "f4eb7a6b2955e5bad3a5b55d263eae76d94e5118c5f46ec9f37c556000ca9ac1"

//  BTS主网核心资产名称（正式网络）
#define BTS_NETWORK_CORE_ASSET              "ACB"

//  BTS主网核心资产ID号
#define BTS_NETWORK_CORE_ASSET_ID           @"1.3.0"

//  BTS网络全局属性对象ID号
#define BTS_GLOBAL_PROPERTIES_ID            @"2.0.0"

//  BTS石墨烯特殊账号
//  0:理事会账号
#define BTS_GRAPHENE_COMMITTEE_ACCOUNT      @"1.2.0"
#define BTS_GRAPHENE_WITNESS_ACCOUNT        @"1.2.1"

//  4:空账号（隐私交易可能需要由该账号支付手续费等）
#define BTS_GRAPHENE_TEMP_ACCOUNT           @"1.2.4"

//  5:代理给自己
#define BTS_GRAPHENE_PROXY_TO_SELF          @"1.2.5"

//  黑名单意见账号：committee-account
#define BTS_GRAPHENE_ACCOUNT_BTSPP_TEAM     @"1.2.0"

//  资产最大供应量
#define GRAPHENE_MAX_SHARE_SUPPLY           1000000000000000ll
#define GRAPHENE_100_PERCENT                10000
#define GRAPHENE_1_PERCENT                  (GRAPHENE_100_PERCENT/100)

#define GRAPHENE_COLLATERAL_RATIO_DENOM                 1000
#define GRAPHENE_MIN_COLLATERAL_RATIO                   1001  ///< lower than this could result in divide by 0
#define GRAPHENE_MAX_COLLATERAL_RATIO                   32000 ///< higher than this is unnecessary and may exceed int16 storage
#define GRAPHENE_DEFAULT_MAINTENANCE_COLLATERAL_RATIO   1750  ///< Call when collateral only pays off 175% the debt
#define GRAPHENE_DEFAULT_MAX_SHORT_SQUEEZE_RATIO        1500  ///< Stop calling when collateral only pays off 150% of the debt

//  BTS网络动态全局信息对象ID号
//  格式：
//    {"id"=>"2.1.0",
//        "head_block_number"=>28508814,
//        "head_block_id"=>"01b3028ec48c120a4f856cc8b931f2ccfb41ec79",
//        "time"=>"2018-07-07T06:16:57",
//        "current_witness"=>"1.6.22",
//        "next_maintenance_time"=>"2018-07-07T07:00:00",
//        "last_budget_time"=>"2018-07-07T06:00:00",
//        "witness_budget"=>86500000,
//        "accounts_registered_this_interval"=>5,
//        "recently_missed_count"=>0,
//        "current_aslot"=>28662531,
//        "recent_slots_filled"=>"340282366920938463463374607431768211455",
//        "dynamic_flags"=>0,
//        "last_irreversible_block_num"=>28508796}}
#define BTS_DYNAMIC_GLOBAL_PROPERTIES_ID    @"2.1.0"

/*
 *  链端数据存在KEY和类别定义
 */

//  类别：APP设置
#define kAppStorageCatalogAppSetings                        @"app.settings"

//  类别：网格机器人的类别
#define kAppStorageCatalogBotsGridBots                      @"system.bots.grid_bots"
#define kAppStorageCatalogBotsGridBotsRunning               @"system.bots.grid_bots.running"

//  KEY：APP设置 > 流动性池默认列表
#define kAppStorageKeyAppSetings_LpMainList                 @"liquidity.pool.mainlist"

//  KEY：APP设置 > 通用配置
#define kAppStorageKeyAppSetings_CommonVer01                @"common.settings.ver.1"

#endif /* __bts_chain_config__ */
