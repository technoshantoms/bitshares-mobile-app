//
//  SettingManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//	服务器version文件设置、用户设置相关处理

#import <Foundation/Foundation.h>
#import "WsPromise.h"

#define kSettingKey_EstimateAssetSymbol @"kEstimateAssetSymbol" //  计价单位符号 CNY、USD等
#define kSettingKey_ThemeInfo           @"kThemeInfo"           //  主题风格信息
#define kSettingKey_KLineIndexInfo      @"kKLineIndexInfo_v2"   //  K线指标参数信息    REMARK：如果新增指标需要更新下参数版本
#define kSettingKey_EnableHorTradeUI    @"kEnableHorTradeUI_v1" //  启用横版交易界面
#define kSettingKey_ApiNode             @"kApiNode_v1"          //  API节点设置信息
#define kSettingKey_ApiNode_Current     @"current_node"         //  API节点设置信息 - 子KEY（当前选择节点，为空则随机选择）
#define kSettingKey_ApiNode_CustomList  @"custom_list"          //  API节点设置信息 - 子KEY（自定义列表）

@interface SettingManager : NSObject

+ (SettingManager*)sharedSettingManager;

@property (retain, nonatomic) NSDictionary* serverConfig;   //  所有服务器配置(version.json)

//  链上配置数据
@property (assign, nonatomic) BOOL haveOnChainAppSettings;              //  是否存在链上配置数据 默认: false
@property (strong, nonatomic) NSMutableDictionary* onChainAppSettings;  //  链上设置数据

//  是否使用了代理检测
- (BOOL)useHttpProxy;

- (BOOL)isDebuggerAttached;

/**
 *  获取记账单位 CNY、USD 等
 */
- (NSString*)getEstimateAssetSymbol;

/**
 *  获取当前主题风格
 */
- (NSDictionary*)getThemeInfo;

/**
 *  获取K线指标参数配置信息
 */
- (NSDictionary*)getKLineIndexInfos;

/*
 *  (public) 是否启用横版交易界面。
 */
- (BOOL)isEnableHorTradeUI;

/*
 *  (public) 获取当前用户节点，为空则随机选择。
 */
- (NSDictionary*)getApiNodeCurrentSelect;

//  保存用户配置  kSettingKey_***
- (void)setUseConfig:(NSString*)key value:(BOOL)value;
- (void)setUseConfig:(NSString*)key obj:(id)value;

- (id)getUseConfig:(NSString*)key;

- (NSDictionary*)getAllSetting;

#pragma mark app settings on chain

// ------- 链端数据存储部分 ---------------

/*
 *  (public) 查询所有链上配置信息
 */
- (WsPromise*)queryAppSettingsOnChain;

/*
 *  (public) 获取APP链上设置数据
 */
- (id)getOnChainAppSetting:(NSString*)key;

#pragma mark- final settings

/*
 *  (public) 获取设置 - 智能币配置列表
 */
- (id)getAppMainSmartAssetList;

/*
 *  (public) 获取设置 - 网关列表信息
 */
- (id)getAppKnownGatewayList;

/*
 *  (public) 获取设置 - 已知网关资产发行账号列表
 */
- (id)getAppKnownGatewayAccounts;

/*
 *  (public) 获取设置 - 已知交易所充值账号列表
 */
- (id)getAppKnownCexDepositAccounts;

/*
 *  (public) 获取设置 - 是否启用网格机器人模块
 */
- (BOOL)isAppEnableModuleGridBots;

/*
 *  (public) 获取设置 - 获取网格机器人授权账号
 */
- (NSString*)getAppGridBotsTraderAccount;

/*
 *  (public) 获取设置 - 获取真锁仓挖矿的资产列表
 */
- (id)getAppLockAssetList;

/*
 *  (public) 获取设置 - 真锁仓挖矿条目
 */
- (id)getAppAssetLockItem:(id)asset_id;

/*
 *  (public) 获取设置 - 挖矿资产列表（快速兑换列表）
 */
- (id)getAppAssetMinerList;

/*
 *  (public) 获取设置 - 挖矿配置条目
 */
- (id)getAppAssetMinerItem:(id)asset_id;

/*
 *  (public) 获取设置 - 资产作为 base 的优先级
 */
- (id)getAppAssetBasePriority;

/*
 *  (public) 获取设置 - 读取通用配置
 */
- (id)getAppCommonSettings:(NSString*)common_key;

/*
 *  (public) 获取设置 - 读取URL配置
 */
- (id)getAppUrls:(NSString*)url_key;

/*
 *  (public) 获取设置 - 读取部分特殊ID号
 */
- (id)getAppParameters:(NSString*)parameter_key;

@end
