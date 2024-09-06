//
//  AppCacheManager.m
//  oplayer
//
//  Created by SYALON on 13-11-4.
//
//

#import "AppCacheManager.h"
#import "OrgUtils.h"
#import "AppCommon.h"
#import "MySecurityFileMgr.h"
#import "TempManager.h"
#import "NativeAppDelegate.h"
#import "WalletManager.h"

#import "Extension.h"
#import <Crashlytics/Crashlytics.h>

static AppCacheManager* _spInstanceAppCacheMgr = nil;

@interface AppCacheManager()
{
    NSMutableDictionary*    _native_caches;         //  一些本地缓存信息
    NSMutableDictionary*    _wallet_info;           //  钱包信息
    NSMutableDictionary*    _objectinfo_caches;     //  帐号、资产等ID对应的信息缓存（比如 name、precision等）。
    
    NSMutableDictionary*    _favorite_accounts;     //  我收藏的帐号列表（关注的） name => @{@"name":@"name", @"id":@"1.2.xx"}
    NSMutableDictionary*    _favorite_markets;      //  我收藏的市场交易对（关注的）  #{base_id}_#{quote_id} => @{@"quote":quote_id, @"base":base_id}
}

@end

@implementation AppCacheManager

+(AppCacheManager *)sharedAppCacheManager
{
    if(!_spInstanceAppCacheMgr)
    {
        _spInstanceAppCacheMgr = [[AppCacheManager alloc] init];
    }
    return _spInstanceAppCacheMgr;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _native_caches = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NativeAppDelegate appShortVersion], @"__cache_ver", nil];
        _wallet_info = [NSMutableDictionary dictionary];
        _objectinfo_caches = [NSMutableDictionary dictionary];
        _favorite_accounts = [NSMutableDictionary dictionary];
        _favorite_markets = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void)dealloc
{
    _native_caches = nil;
    _wallet_info = nil;
    _objectinfo_caches = nil;
    _favorite_accounts = nil;
    _favorite_markets = nil;
}

-(void)initload
{
    NSString* pFullFileName;
    NSMutableDictionary* pTempObject;
    
    //  TODO:文件的加密方式，待处理。
    pFullFileName = [OrgUtils makeFullPathByAppStorage:kAppCacheNameMemoryInfosByApp];
    pTempObject = [MySecurityFileMgr loadDicSecFile:pFullFileName];
    if (pTempObject)
    {
        _native_caches = pTempObject;
    }
    
    pFullFileName = [OrgUtils makeFullPathByAppStorage:kAppCacheNameWalletInfoByApp];
    pTempObject = [MySecurityFileMgr loadDicSecFile:pFullFileName];
    if (pTempObject){
        _wallet_info = pTempObject;
    }
    
    pFullFileName = [OrgUtils makeFullPathByAppStorage:kAppCacheNameObjectCacheByApp];
    pTempObject = [MySecurityFileMgr loadDicSecFile:pFullFileName];
    if (pTempObject){
        _objectinfo_caches = pTempObject;
    }
    
    pFullFileName = [OrgUtils makeFullPathByAppStorage:kAppCacheNameFavAccountsByApp];
    pTempObject = [MySecurityFileMgr loadDicSecFile:pFullFileName];
    if (pTempObject){
        _favorite_accounts = pTempObject;
    }
    
    pFullFileName = [OrgUtils makeFullPathByAppStorage:kAppCacheNameFavMarketsByApp];
    pTempObject = [MySecurityFileMgr loadDicSecFile:pFullFileName];
    if (pTempObject){
        _favorite_markets = pTempObject;
    }
}

-(void)saveToFile
{
    [self saveCacheToFile];
    [self saveWalletInfoToFile];
    [self saveObjectCacheToFile];
    [self saveFavAccountsToFile];
    [self saveFavMarketsToFile];
}

-(void)saveCacheToFile
{
    NSString* pFilename = [OrgUtils makeFullPathByAppStorage:kAppCacheNameMemoryInfosByApp];
    [MySecurityFileMgr saveSecFile:_native_caches path:pFilename];
}

-(void)saveWalletInfoToFile
{
    NSString* pFilename = [OrgUtils makeFullPathByAppStorage:kAppCacheNameWalletInfoByApp];
    [MySecurityFileMgr saveSecFile:_wallet_info path:pFilename];
}

-(void)saveObjectCacheToFile
{
    NSString* pFilename = [OrgUtils makeFullPathByAppStorage:kAppCacheNameObjectCacheByApp];
    [MySecurityFileMgr saveSecFile:_objectinfo_caches path:pFilename];
}

-(void)saveFavAccountsToFile
{
    NSString* pFilename = [OrgUtils makeFullPathByAppStorage:kAppCacheNameFavAccountsByApp];
    [MySecurityFileMgr saveSecFile:_favorite_accounts path:pFilename];
}

-(void)saveFavMarketsToFile
{
    NSString* pFilename = [OrgUtils makeFullPathByAppStorage:kAppCacheNameFavMarketsByApp];
    [MySecurityFileMgr saveSecFile:_favorite_markets path:pFilename];
}

- (NSMutableDictionary*)_getOrCreateSubFieldForWalletInfo:(NSString*)field_name
{
    assert(field_name);
    assert(_wallet_info);
    id field_hash = [_wallet_info objectForKey:field_name];
    if (!field_hash) {
        field_hash = [NSMutableDictionary dictionary];
        [_wallet_info setObject:field_hash forKey:field_name];
    }
    return field_hash;
}

/*
 *  (public) 管理所有隐私账号：获取、添加、删除
 */
- (NSMutableDictionary*)getAllBlindAccounts
{
    return [self _getOrCreateSubFieldForWalletInfo:@"kBlindAccountHash"];
}

- (AppCacheManager*)appendBlindAccount:(id)blind_account autosave:(BOOL)autosave
{
    //    id blind_account = @{
    //        @"public_key": @"",
    //        @"alias_name": @"",
    //        @"parent_key": @"",
    //        @"child_key_index": @0
    //    };
    assert(blind_account);
    assert([blind_account objectForKey:@"public_key"]);
    //  添加
    [[self getAllBlindAccounts] setObject:blind_account forKey:blind_account[@"public_key"]];
    //  保存
    if (autosave) {
        [self saveWalletInfoToFile];
    }
    return self;
}

- (AppCacheManager*)removeBlindAccount:(id)blind_account autosave:(BOOL)autosave
{
    assert(blind_account);
    assert([blind_account objectForKey:@"public_key"]);
    //  删除
    [[self getAllBlindAccounts] removeObjectForKey:blind_account[@"public_key"]];
    //  保存
    if (autosave) {
        [self saveWalletInfoToFile];
    }
    return self;
}

- (id)queryBlindAccount:(NSString*)public_key
{
    assert(public_key);
    return [[self getAllBlindAccounts] objectForKey:public_key];
}

/*
 *  (public) 管理所有隐私收据：获取、添加、删除。
 */
-(id)getAllBlindBalance
{
    return [self _getOrCreateSubFieldForWalletInfo:@"kBlindBalanceHash"];
}

-(BOOL)isHaveBlindBalance:(id)blind_balance
{
    assert(blind_balance);
    id commitment = [[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"commitment"];
    assert([commitment isKindOfClass:[NSString class]]);
    if ([[self getAllBlindBalance] objectForKey:commitment]) {
        return YES;
    }
    return NO;
}

-(AppCacheManager*)appendBlindBalance:(id)blind_balance
{
    assert(blind_balance);
    //    @"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //    @"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //    @"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //    @"decrypted_memo": @{
    //        @"amount": @{@"asset_id": @"1.3.0", @"amount": @12300000},              //  转账用，显示用。
    //        @"blinding_factor": @"",                                                //  转账用
    //        @"commitment": @"",                                                     //  转账用
    //        @"check": @331,                                                         //  导入check用，显示用。
    //    }
    id commitment = [[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"commitment"];
    assert([commitment isKindOfClass:[NSString class]]);
    [[self getAllBlindBalance] setObject:blind_balance forKey:commitment];
    return self;
}

-(AppCacheManager*)removeBlindBalance:(id)blind_balance
{
    assert(blind_balance);
    id commitment = [[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"commitment"];
    assert([commitment isKindOfClass:[NSString class]]);
    [[self getAllBlindBalance] removeObjectForKey:commitment];
    return self;
}

#pragma mark- garphene object cache
- (NSDictionary*)get_all_object_caches
{
    assert(_objectinfo_caches);
    return _objectinfo_caches;
}

- (AppCacheManager*)update_object_cache:(NSString*)object_id object:(NSDictionary*)object
{
    if (!object_id){
        return self;
    }
    id item = @{@"expire_ts":@([[NSDate date] timeIntervalSince1970] + kBTSObjectCacheExpireTime), @"cache_object":object};
    //  REMARK：格式   object_id => {:expire_ts, :cache_object}
    [_objectinfo_caches setObject:item forKey:object_id];
    return self;
}

/**
 *  获取缓存的区块链对象 REMARK：所有缓存对象默认有个过期日期，如果 now_ts 小于等于0则不判断过期日期。
 */
- (NSDictionary*)get_object_cache:(NSString*)object_id now_ts:(NSTimeInterval)now_ts
{
    if (!object_id){
        return nil;
    }
    //  对象不存在
    id item = [_objectinfo_caches objectForKey:object_id];
    if (!item){
        return nil;
    }
    //  REMARK：now_ts 小于等于0则不判断是否过期。
    if (now_ts > 0){
        //  缓存是否过期判断
        NSTimeInterval expire_ts = (NSTimeInterval)[[item objectForKey:@"expire_ts"] doubleValue];
        if (now_ts >= expire_ts){
            //  REMARK：缓存已经过期了，则删除缓存。
            [_objectinfo_caches removeObjectForKey:object_id];
            return nil;
        }
    }
    //  返回缓存对象
    return [item objectForKey:@"cache_object"];
}

- (NSDictionary*)get_object_cache:(NSString*)object_id
{
    return [self get_object_cache:object_id now_ts:[[NSDate date] timeIntervalSince1970]];
}

#pragma mark- fav accounts
- (NSDictionary*)get_all_fav_accounts
{
    return _favorite_accounts;
}

- (AppCacheManager*)set_fav_account:(NSDictionary*)account_info
{
    if (account_info){
        id account_id = [account_info objectForKey:@"id"];
        id name = [account_info objectForKey:@"name"];
        if (name && account_id){
            [_favorite_accounts setObject:account_info forKey:name];
        }
    }
    return self;
}
- (void)remove_fav_account:(NSString*)account_name
{
    if (!account_name){
        return;
    }
    [_favorite_accounts removeObjectForKey:account_name];
}

#pragma mark- fav markets
- (NSDictionary*)get_all_fav_markets
{
    return _favorite_markets;
}

- (NSArray*)get_fav_markets_asset_ids
{
    if ([_favorite_markets count] <= 0) {
        return @[];
    }
    NSMutableDictionary* ids = [NSMutableDictionary dictionary];
    for (id pair_key in _favorite_markets) {
        id fav_item = [_favorite_markets objectForKey:pair_key];
        assert(fav_item);
        [ids setObject:@YES forKey:[fav_item objectForKey:@"base"]];
        [ids setObject:@YES forKey:[fav_item objectForKey:@"quote"]];
    }
    return [ids allKeys];
}

- (BOOL)is_fav_market:(NSString*)quote_id base:(NSString*)base_id
{
    if (quote_id && base_id){
        id pair = [NSString stringWithFormat:@"%@_%@", base_id, quote_id];
        id fav_item = [_favorite_markets objectForKey:pair];
        if (fav_item){
            return YES;
        }
    }
    return NO;
}
- (AppCacheManager*)set_fav_markets:(NSString*)quote_id base:(NSString*)base_id
{
    if (quote_id && base_id){
        id pair = [NSString stringWithFormat:@"%@_%@", base_id, quote_id];
        [_favorite_markets setObject:@{@"base":base_id, @"quote":quote_id} forKey:pair];
    }
    return self;
}
- (void)remove_fav_markets:(NSString*)quote_id base:(NSString*)base_id
{
    if (quote_id && base_id){
        id pair = [NSString stringWithFormat:@"%@_%@", base_id, quote_id];
        [_favorite_markets removeObjectForKey:pair];
    }
}

#pragma mark- native cache
-(NSObject*)getPref:(NSString*)key
{
    return [self getPref:key defaultValue:nil];
}
-(NSObject*)getPref:(NSString*)key defaultValue:(NSObject*)defaultValue
{
    NSObject *pref = [_native_caches objectForKey:key];
    if (!pref)
    {
        return defaultValue;
    }
    return pref;
}
-(AppCacheManager*)setPref:(NSString*)key value:(NSObject*)value
{
    [_native_caches setObject:value forKey:key];
    return self;
}
-(AppCacheManager*)deletePref:(NSString*)key
{
    [_native_caches removeObjectForKey:key];
    return self;
}

#pragma mark- for wallet info
- (NSDictionary*)getWalletInfo
{
    return _wallet_info;
}

- (void)removeWalletInfo
{
    [_wallet_info removeAllObjects];
    [self saveWalletInfoToFile];
}

/**
 *  (public) 更新本地钱包帐号信息
 *  walletMode      - 帐号模式
 *  accountInfo     - 帐号完整信息（可能为空、注册成但查询失败时则为空。）
 *  accountName     - 帐号名（不能为空）
 *  fullWalletBin   - 钱包二进制bin文件（除了帐号模式以外都存在）
 */
- (void)setWalletInfo:(NSInteger)walletMode
          accountInfo:(id)fullAccountInfo
          accountName:(NSString*)accountName
        fullWalletBin:(NSData*)fullWalletBin
{
    assert(accountName);
    [_wallet_info removeAllObjects];
    //  基本字段（不能为空）
    [_wallet_info setObject:@(walletMode) forKey:@"kWalletMode"];
    //  当前账号信息（活跃账号信息）
    [_wallet_info setObject:accountName forKey:@"kAccountName"];
    //  附加信息（可为空）
    if (fullAccountInfo){
        [_wallet_info setObject:fullAccountInfo forKey:@"kAccountInfo"];
    }
    //  钱包BIN文件信息
    if (fullWalletBin){
        [_wallet_info setObject:@[] forKey:@"kAccountDataList"];
        [_wallet_info setObject:[fullWalletBin hex_encode] forKey:@"kFullWalletBin"];
    }
    //  保存
    [self saveWalletInfoToFile];
}

/**
 *  (public) 设置钱包中当前活跃账号（当前操作的账号）
 */
- (void)setWalletCurrentAccount:(NSString*)currAccountName fullAccountData:(id)fullAccountData
{
    assert(currAccountName);
    assert(fullAccountData);
    assert([[[fullAccountData objectForKey:@"account"] objectForKey:@"name"] isEqualToString:currAccountName]);
    //  设置当前账号信息
    [_wallet_info setObject:currAccountName forKey:@"kAccountName"];
    [_wallet_info setObject:fullAccountData forKey:@"kAccountInfo"];
    //  保存
    [self saveWalletInfoToFile];
}

/**
 *  (public) 保存钱包中的账号信息（和BIN中的账号信息应该同步）
 */
- (void)setWalletAccountDataList:(NSArray*)accountDataList
{
    assert(accountDataList);
    assert([accountDataList isKindOfClass:[NSArray class]]);
    for (id accountData in accountDataList) {
        assert([accountData objectForKey:@"id"]);
        assert([accountData objectForKey:@"active"]);
        assert([accountData objectForKey:@"owner"]);
    }
    //  设置账号信息
    [_wallet_info setObject:accountDataList forKey:@"kAccountDataList"];
    //  保存
    [self saveWalletInfoToFile];
}

/**
 *  更新钱包BIN信息
 */
- (void)updateWalletBin:(NSData*)fullWalletBin
{
    assert(_wallet_info);
    assert([[_wallet_info objectForKey:@"kWalletMode"] integerValue] != kwmNoWallet);
    assert([[_wallet_info objectForKey:@"kWalletMode"] integerValue] != kwmPasswordOnlyMode);
    assert(fullWalletBin);
    [_wallet_info setObject:[fullWalletBin hex_encode] forKey:@"kFullWalletBin"];
    //  保存
    [self saveWalletInfoToFile];
}

/**
 *  (public) 更新本地帐号数据
 */
- (void)updateWalletAccountInfo:(id)accountInfo
{
    assert(accountInfo);
    assert([[_wallet_info objectForKey:@"kWalletMode"] integerValue] != kwmNoWallet);
    if ([[_wallet_info objectForKey:@"kWalletMode"] integerValue] == kwmNoWallet){
        return;
    }
    [_wallet_info setObject:accountInfo forKey:@"kAccountInfo"];
    //  保存
    [self saveWalletInfoToFile];
}

/**
 *  备份钱包bin到web目录供用户下载。（也供 iTunes 备份）
 *  hasDatePrefix - 备份文件是否添加日期前缀（在账号管理处手动备份等则添加，其他自动备份等不用添加）
 */
- (BOOL)autoBackupWalletToWebdir:(BOOL)hasDatePrefix
{
    id hex_wallet_bin = [_wallet_info objectForKey:@"kFullWalletBin"];
    if (!hex_wallet_bin){
        return NO;
    }
    
    id account_name = [_wallet_info objectForKey:@"kAccountName"];
    if (!account_name){
        account_name = @"default";
    }
    
    NSString* final_wallet_name = account_name;
    id account_data_hash = [[WalletManager sharedWalletManager] getAllAccountDataHash:YES];
    if (account_data_hash && [account_data_hash count] >= 2){
        //  REMARK：多账号时钱包默认名字。
        final_wallet_name = @"multi_accounts_wallet";
    }
    
    assert(account_name);
    assert(hex_wallet_bin);
    
    //  备份到文件
    id wallet_bin = [OrgUtils hexDecode:hex_wallet_bin];
    assert(wallet_bin);
    id dir = [OrgUtils getDocumentDirectory];
    NSString* filename = @"";
    if (hasDatePrefix){
        NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"yyyyMMdd"];
        id prefix = [dateFormat stringFromDate:[NSDate date]];
        filename = [NSString stringWithFormat:@"%@_%@.bin", prefix, final_wallet_name];
        //  [统计]
        [OrgUtils logEvents:@"action_backupwallet"
                     params:@{@"prefix":prefix, @"account":final_wallet_name}];
    }else{
        filename = [NSString stringWithFormat:@"%@.bin", final_wallet_name];
        //  [统计]
        [OrgUtils logEvents:@"action_backupwallet"
                     params:@{@"account":final_wallet_name}];
    }
    id fullpath = [dir stringByAppendingPathComponent:filename];
    return [OrgUtils writeFileAny:wallet_bin withFullPath:fullpath withDirPath:nil];
}

#pragma mark- first run
- (double)getFirstRunTime
{
    return [[_native_caches objectForKey:@"_first_launch_time"] doubleValue];
}

- (void)recordFirstRunTime:(void (^)())firstrun_callback
{
    id first_time = [_native_caches objectForKey:@"_first_launch_time"];
    if (!first_time){
        NSLog(@"first launched...");
        [_native_caches setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"_first_launch_time"];
        [self saveCacheToFile];
        if (firstrun_callback){
            firstrun_callback();
        }
    }
}

/**
 *  判断当前版本号是否是第一次运行
 */
- (BOOL)isFirstRunWithVersion:(NSString*)pVersion
{
    //  没有文件：说明是第一次运行
    NSMutableDictionary* versionLaunchedInfo = [_native_caches objectForKey:@"versionLaunchedInfo"];
    if (!versionLaunchedInfo){
        return YES;
    }
    
    //  有对应的版本了：则不是第一次运行
    if ([[versionLaunchedInfo objectForKey:pVersion] boolValue]){
        return NO;
    }
    
    return YES;
}

/**
 *  记录第一次运行
 */
- (void)saveFirstRunWithVersion:(NSString*)pVersion
{
    if (!pVersion)
        return;
    
    NSMutableDictionary* versionLaunchedInfo = [_native_caches objectForKey:@"versionLaunchedInfo"];
    if (!versionLaunchedInfo){
        versionLaunchedInfo = [NSMutableDictionary dictionary];
        [_native_caches setObject:versionLaunchedInfo forKey:@"versionLaunchedInfo"];
    }
    
    [versionLaunchedInfo setObject:@YES forKey:pVersion];
    [self saveCacheToFile];
}

@end
