//
//  SettingManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "SettingManager.h"
#import "OrgUtils.h"
#import "AppCommon.h"

#import "ChainObjectManager.h"
#import "ThemeManager.h"

#import <sys/sysctl.h>

static SettingManager *_sharedSettingManager = nil;

@interface SettingManager()
{
}
@end

@implementation SettingManager

@synthesize serverConfig;

+(SettingManager *)sharedSettingManager
{
    @synchronized(self)
    {
        if(!_sharedSettingManager)
        {
            _sharedSettingManager = [[SettingManager alloc] init];
        }
        return _sharedSettingManager;
    }
}

- (BOOL)useHttpProxy
{
    SInt32 value;
    
    CFDictionaryRef dicRef = CFNetworkCopySystemProxySettings();
    if (!dicRef){
        return NO;
    }
    
    const CFNumberRef pEnableHttpProxy = (const CFNumberRef)CFDictionaryGetValue(dicRef, (const void*)kCFNetworkProxiesHTTPEnable);
    if (pEnableHttpProxy && CFNumberGetValue(pEnableHttpProxy, kCFNumberSInt32Type, &value)){
        if (value != 0){
            return YES;
        }
    }
    
    const CFStringRef pHttpProxyHostname = (const CFStringRef)CFDictionaryGetValue(dicRef, (const void*)kCFNetworkProxiesHTTPProxy);
    if (pHttpProxyHostname){
        return YES;
    }
    
    return NO;
}
- (BOOL)isDebuggerAttached {
    static BOOL debuggerIsAttached = NO;
    
    static dispatch_once_t debuggerPredicate;
    dispatch_once(&debuggerPredicate, ^{
        struct kinfo_proc info;
        size_t info_size = sizeof(info);
        int name[4];
        
        name[0] = CTL_KERN;
        name[1] = KERN_PROC;
        name[2] = KERN_PROC_PID;
        name[3] = getpid();
        
        if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
            NSLog(@"[HockeySDK] ERROR: Checking for a running debugger via sysctl() failed: %s", strerror(errno));
            debuggerIsAttached = false;
        }
        
        if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0)
            debuggerIsAttached = true;
    });
    
    return debuggerIsAttached;
}
- (id)init
{
    self = [super init];
    if (self)
    {
        self.serverConfig = [NSDictionary dictionary];
        _haveOnChainAppSettings = NO;
        _onChainAppSettings = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
    self.serverConfig = nil;
    [_onChainAppSettings removeAllObjects];
    _onChainAppSettings = nil;
    _haveOnChainAppSettings = NO;
}

- (NSMutableDictionary*)loadSettingHash
{
    NSString* pFullPath = [OrgUtils makeFullPathByAppStorage:kAppCacheNameUserSettingByApp];
    NSMutableDictionary* settings = [NSMutableDictionary dictionaryWithContentsOfFile:pFullPath];
    if (!settings){
        settings = [NSMutableDictionary dictionary];
    }
    return settings;
}

- (void)saveSettingHash:(NSMutableDictionary*)settings
{
    [OrgUtils writeFileAny:settings withFullPath:[OrgUtils makeFullPathByAppStorage:kAppCacheNameUserSettingByApp] withDirPath:nil];
}

/**
 *  获取记账单位 CNY、USD 等
 */
- (NSString*)getEstimateAssetSymbol
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSString* value = [settings objectForKey:kSettingKey_EstimateAssetSymbol];
    
    //  初始化默认值（CNY）
    if (!value || [value isEqualToString:@""]){
        id default_value = [[ChainObjectManager sharedChainObjectManager] getDefaultEstimateUnitSymbol];
        [settings setObject:default_value forKey:kSettingKey_EstimateAssetSymbol];
        [self saveSettingHash:settings];
        return default_value;
    }
    
    //  REMARK：如果设置界面保存的计价货币 symbol 在配置的计价列表移除了，则恢复默认值。
    id currency = [[ChainObjectManager sharedChainObjectManager] getEstimateUnitBySymbol:value];
    if (!currency){
        id default_value = [[ChainObjectManager sharedChainObjectManager] getDefaultEstimateUnitSymbol];
        [settings setObject:default_value forKey:kSettingKey_EstimateAssetSymbol];
        [self saveSettingHash:settings];
        return default_value;
    }
    
    //  返回
    assert([[currency objectForKey:@"symbol"] isEqualToString:value]);
    return value;
}

- (NSDictionary*)getThemeInfo
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSDictionary* value = [settings objectForKey:kSettingKey_ThemeInfo];// kSettingKey_ThemeIndex
    //  初始化默认值
    if (!value){
        id themeInfo = [ThemeManager getDefaultThemeInfos];
        [settings setObject:themeInfo forKey:kSettingKey_ThemeInfo];
        [self saveSettingHash:settings];
        return themeInfo;
    }
    return value;
}

- (NSDictionary*)getKLineIndexInfos
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSDictionary* value = [settings objectForKey:kSettingKey_KLineIndexInfo];
    //  初始化默认值
    if (!value){
        id default_kline_index = [[[ChainObjectManager sharedChainObjectManager] getDefaultParameters] objectForKey:@"default_kline_index"];
        assert(default_kline_index);
        [settings setObject:default_kline_index forKey:kSettingKey_KLineIndexInfo];
        [self saveSettingHash:settings];
        return default_kline_index;
    }
    return value;
}

/*
 *  (public) 是否启用横版交易界面。
 */
- (BOOL)isEnableHorTradeUI
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSString* value = [settings objectForKey:kSettingKey_EnableHorTradeUI];
    //  初始化默认值（NO）
    if (!value || [value isEqualToString:@""]){
        [settings setObject:@"0" forKey:kSettingKey_EnableHorTradeUI];
        [self saveSettingHash:settings];
        return NO;
    }
    return [value boolValue];
}

/*
 *  (public) 获取当前用户节点，为空则随机选择。
 */
- (NSDictionary*)getApiNodeCurrentSelect
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSDictionary* value = [settings objectForKey:kSettingKey_ApiNode];
    if (value) {
        return [value objectForKey:kSettingKey_ApiNode_Current];
    }
    return nil;
}

- (void)setUseConfig:(NSString*)key value:(BOOL)value
{
    NSMutableDictionary* settings = [self loadSettingHash];
    [settings setObject:value ? @"1" : @"0" forKey:key];
    [self saveSettingHash:settings];
}

- (void)setUseConfig:(NSString*)key obj:(id)value
{
    NSMutableDictionary* settings = [self loadSettingHash];
    [settings setObject:value forKey:key];
    [self saveSettingHash:settings];
}

- (id)getUseConfig:(NSString*)key
{
    NSMutableDictionary* settings = [self loadSettingHash];
    return [settings objectForKey:key];
}

- (NSDictionary*)getAllSetting
{
    return [[self loadSettingHash] copy];
}

#pragma mark app settings on chain

/*
 *  (public) 查询所有链上配置信息
 */
- (WsPromise*)queryAppSettingsOnChain
{
#ifdef kAppOnChainSettingsAccount
    if ([kAppOnChainSettingsAccount isEqualToString:@""]) {
        //  链上设置账号为空
        [self _queryAppSettingsOnChainResponsed:nil];
        return [WsPromise resolve:@(_haveOnChainAppSettings)];
    } else {
        //  已定义：链上设置账号，查询链上信息。
        return [[[ChainObjectManager sharedChainObjectManager] queryAccountStorageInfo:kAppOnChainSettingsAccount
                                                                               catalog:kAppStorageCatalogAppSetings] then:^id(id data_array) {
            //  account_storage_object 数组
            [self _queryAppSettingsOnChainResponsed:data_array];
            return @(_haveOnChainAppSettings);
        }];
    }
#else
    //  未定义：链上设置账号
    [self _queryAppSettingsOnChainResponsed:nil];
    return [WsPromise resolve:@(_haveOnChainAppSettings)];
#endif  //  kAppOnChainSettingsAccount
}

- (void)_queryAppSettingsOnChainResponsed:(id)data_array
{
    [_onChainAppSettings removeAllObjects];
    
    if (!data_array || [data_array count] <= 0) {
        _haveOnChainAppSettings = NO;
        return;
    }
    
    _haveOnChainAppSettings = YES;
    for (id item in data_array) {
        id key = [item objectForKey:@"key"];
        assert(key);
        [_onChainAppSettings setObject:item forKey:key];
    }
}

/*
 *  (public) 获取APP链上设置数据
 */
- (id)getOnChainAppSetting:(NSString*)key
{
    assert(key);
    if (_haveOnChainAppSettings) {
        id storage_object = [_onChainAppSettings objectForKey:key];
        if (storage_object) {
            return [storage_object objectForKey:@"value"];
        }
    }
    return nil;
}

#pragma mark- final settings

/*
 *  (public) 获取设置 - 智能币配置列表
 */
- (id)getAppMainSmartAssetList
{
    id list = [self getAppCommonSettings:@"asset_smart_mainlist"];
    if (list && [list count] > 0) {
        return list;
    }
    return [[ChainObjectManager sharedChainObjectManager] getMainSmartAssetList];
}

/*
 *  (public) 获取设置 - 网关列表信息
 */
- (id)getAppKnownGatewayList
{
    id list = [self getAppCommonSettings:@"gateways"];
    if (list && [list count] > 0) {
        return list;
    }
    return @[];
}

/*
 *  (public) 获取设置 - 已知网关资产发行账号列表
 */
- (id)getAppKnownGatewayAccounts
{
    id list = [self getAppCommonSettings:@"known_gateway_accounts"];
    if (list && [list count] > 0) {
        return list;
    }
    return @[];
}

/*
 *  (public) 获取设置 - 已知交易所充值账号列表
 */
- (id)getAppKnownCexDepositAccounts
{
    id list = [self getAppCommonSettings:@"known_cex_deposit_accounts"];
    if (list && [list count] > 0) {
        return list;
    }
    return @[];
}

/*
 *  (public) 获取设置 - 是否启用网格机器人模块
 */
- (BOOL)isAppEnableModuleGridBots
{
    NSString* grid_bots_trader = [self getAppParameters:@"grid_bots_trader"];
    if (!grid_bots_trader || [grid_bots_trader isEqualToString:@""]) {
        return NO;
    }
    return YES;
}

/*
 *  (public) 获取设置 - 获取网格机器人授权账号
 */
- (NSString*)getAppGridBotsTraderAccount
{
    assert([self isAppEnableModuleGridBots]);
    return [self getAppParameters:@"grid_bots_trader"];
}

/*
 *  (public) 获取设置 - 获取真锁仓挖矿的资产列表
 */
- (id)getAppLockAssetList
{
    id list = [self getAppCommonSettings:@"lock_list"];
    if (list && [list count] > 0) {
        return list;
    }
    return @[];
}

/*
 *  (public) 获取设置 - 真锁仓挖矿条目
 */
- (id)getAppAssetLockItem:(id)asset_id
{
    for (id lock_item in [self getAppLockAssetList]) {
        if (asset_id && [asset_id isEqualToString:[lock_item objectForKey:@"asset_id"]]) {
            return lock_item;
        }
    }
    return nil;
}

/*
 *  (public) 获取设置 - 挖矿资产列表（快速兑换列表）
 */
- (id)getAppAssetMinerList
{
    id list = [self getAppCommonSettings:@"miner_list"];
    if (list && [list count] > 0) {
        return list;
    }
    return @[];
}

/*
 *  (public) 获取设置 - 挖矿配置条目
 */
- (id)getAppAssetMinerItem:(id)asset_id
{
    for (id miner_item in [self getAppAssetMinerList]) {
        if (asset_id && [asset_id isEqualToString:[[[miner_item objectForKey:@"price"] objectForKey:@"amount_to_sell"] objectForKey:@"asset_id"]]) {
            return miner_item;
        }
    }
    return nil;
}

/*
 *  (public) 获取设置 - 资产作为 base 的优先级
 */
- (id)getAppAssetBasePriority
{
    id asset_base_priority = [self getAppCommonSettings:@"asset_base_priority"];
    if (asset_base_priority && [asset_base_priority count] > 0) {
        return asset_base_priority;
    }
    return @{};
}

/*
 *  (public) 获取设置 - 读取通用配置
 */
- (id)getAppCommonSettings:(NSString*)common_key
{
    assert(common_key);
    id common_hash = [self getOnChainAppSetting:kAppStorageKeyAppSetings_CommonVer01];
    if (!common_hash || ![common_hash isKindOfClass:[NSDictionary class]] || [common_hash count] <= 0) {
        return nil;
    }
    return [common_hash objectForKey:common_key];
}

/*
 *  (public) 获取设置 - 读取URL配置
 */
- (id)getAppUrls:(NSString*)url_key
{
    assert(url_key);
    id urls = [self getAppCommonSettings:@"urls"];
    if (!urls || [urls count] <= 0) {
        return nil;
    }
    return [urls objectForKey:url_key];
}

/*
 *  (public) 获取设置 - 读取动态参数
 */
- (id)getAppParameters:(NSString*)parameter_key
{
    assert(parameter_key);
    id parameters = [self getAppCommonSettings:@"parameters"];
    if (!parameters || [parameters count] <= 0) {
        return nil;
    }
    return [parameters objectForKey:parameter_key];
}

@end
