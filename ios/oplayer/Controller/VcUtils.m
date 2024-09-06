//
//  VcUtils.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//
#import "VCBase.h"
#import "VcUtils.h"
#import "VCUserAssets.h"
#import "VCUserOrders.h"
#import "WalletManager.h"
#import "OrgUtils.h"

#import "VCStealthTransferHelper.h"
#import "HDWallet.h"

@interface UITapGestureRecognizer2Block()
{
    __weak id _self;
    UITapGestureRecognizerBlockHandler _body;
}

@end

@implementation UITapGestureRecognizer2Block

- (void)dealloc
{
    _self = nil;
    _body = nil;
}

- (instancetype)initWithWeakSelf:(id)weak_self body:(UITapGestureRecognizerBlockHandler)body
{
    self = [super init];
    if (self) {
        [self addTarget:self action:@selector(onTap:)];
        _body = body;
        _self = weak_self;
    }
    return self;
}

- (void)onTap:(UITapGestureRecognizer*)pTap
{
    if (_body) {
        _body(_self, pTap);
    }
}

@end

@implementation VcUtils

+ (void)viewUserLimitOrders:(VCBase*)this account:(NSString*)account_id tradingPair:(TradingPair*)tradingPair
{
    //  [统计]
    [OrgUtils logEvents:@"event_view_userlimitorders" params:@{@"account":account_id}];
    
    [this showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  1、查帐号数据
    WsPromise* p1 = [[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_id];
    
    //  2、帐号历史
    GrapheneApi* api_history = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_history;
    
    //  !!!! TODO:fowallet可以历史记录，方便继续查询。考虑添加。 if (history && history.size) most_recent = history.first().get("id");
    //  查询最新的 100 条记录。
    id stop = [NSString stringWithFormat:@"1.%@.0", @(ebot_operation_history)];
    id start = [NSString stringWithFormat:@"1.%@.0", @(ebot_operation_history)];
    //  start - 从指定ID号往前查询（包含该ID号），如果指定ID为0，则从最新的历史记录往前查询。结果包含 start。
    //  stop  - 指定停止查询ID号（结果不包含该ID），如果指定为0，则查询到最早的记录位置（or达到limit停止。）结果不包含该 stop ID。
    WsPromise* p2 = [api_history exec:@"get_account_history" params:@[account_id, stop, @100, start]];
    
    //  查询全部
    [[[WsPromise all:@[p1, p2]] then:(^id(id data_array) {
        id full_account_data = [data_array objectAtIndex:0];
        id account_history = [data_array objectAtIndex:1];
        
        NSMutableDictionary* asset_id_hash = [NSMutableDictionary dictionary];
        //  限价单
        id limit_orders = [full_account_data objectForKey:@"limit_orders"];
        if (limit_orders && [limit_orders count] > 0){
            for (id order in limit_orders) {
                id sell_price = [order objectForKey:@"sell_price"];
                [asset_id_hash setObject:@YES forKey:[[sell_price objectForKey:@"base"] objectForKey:@"asset_id"]];
                [asset_id_hash setObject:@YES forKey:[[sell_price objectForKey:@"quote"] objectForKey:@"asset_id"]];
            }
        }
        
        //  成交历史
        NSMutableArray* tradeHistory = [NSMutableArray array];
        if (account_history && [account_history count] > 0){
            for (id history in account_history) {
                id op = [history objectForKey:@"op"];
                if ([[op firstObject] integerValue] == ebo_fill_order){
                    [tradeHistory addObject:history];
                    id fill_info = [op objectAtIndex:1];
                    [asset_id_hash setObject:@YES forKey:[[fill_info objectForKey:@"pays"] objectForKey:@"asset_id"]];
                    [asset_id_hash setObject:@YES forKey:[[fill_info objectForKey:@"receives"] objectForKey:@"asset_id"]];
                }
            }
        }
        
        //  查询 & 缓存
        return [[[ChainObjectManager sharedChainObjectManager] queryAllAssetsInfo:[asset_id_hash allKeys]] then:(^id(id asset_hash) {
            [this hideBlockView];
            //  忽略该参数 asset_hash，因为 ChainObjectManager 已经缓存。
            VCUserOrdersPages* vc = [[VCUserOrdersPages alloc] initWithUserFullInfo:full_account_data
                                                                       tradeHistory:tradeHistory
                                                                        tradingPair:tradingPair];
            vc.title = NSLocalizedString(@"kVcTitleOrderManagement", @"订单管理");
            [this pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
            return nil;
        })];
    })] catch:(^id(id error) {
        [this hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

+ (void)viewUserAssets:(VCBase*)this account:(NSString*)account_name_or_id
{
    //  [统计]
    [OrgUtils logEvents:@"event_view_userassets" params:@{@"account":account_name_or_id}];
    
    [this showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [[[chainMgr queryFullAccountInfo:account_name_or_id] then:(^id(id full_account_data) {
        NSLog(@"%@", full_account_data);
        
        NSDictionary* userAssetDetailInfos = [OrgUtils calcUserAssetDetailInfos:full_account_data];
        NSArray* args = [[userAssetDetailInfos objectForKey:@"validBalancesHash"] allKeys];
        
        //  查询所有资产信息
        return [[chainMgr queryAllAssetsInfo:args] then:(^id(id asset_hash) {
            NSMutableArray* bitasset_data_id_list = [NSMutableArray array];
            for (id asset_id in args) {
                NSString* bitasset_data_id = [chainMgr getChainObjectByID:asset_id][@"bitasset_data_id"];
                if (bitasset_data_id && ![bitasset_data_id isEqualToString:@""]) {
                    [bitasset_data_id_list addObject:bitasset_data_id];
                }
            }
            
            //  查询所有智能资产的喂价和MCR、MSSR等信息
            return [[chainMgr queryAllGrapheneObjects:bitasset_data_id_list] then:(^id(id data) {
                [this hideBlockView];
                
                VCAccountInfoPages* vc = [[VCAccountInfoPages alloc] initWithUserAssetDetailInfos:userAssetDetailInfos
                                                                                        assetHash:asset_hash
                                                                                      accountInfo:full_account_data];
                
                id target_name = [[full_account_data objectForKey:@"account"] objectForKey:@"name"];
                if ([[WalletManager sharedWalletManager] isMyselfAccount:target_name]){
                    vc.title = NSLocalizedString(@"kVcTitleMyBalance", @"我的资产");
                }else{
                    vc.title = target_name;
                }
                
                [this pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                return nil;
            })];
        })];
    })] catch:(^id(id error) {
        [this hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

/**
 *  根据私钥登录（导入）区块链账号。
 */
+ (void)onLoginWithKeysHash:(VCBase*)this
                       keys:(NSDictionary*)pub_pri_keys_hash
      checkActivePermission:(BOOL)checkActivePermission
             trade_password:(NSString*)pTradePassword
                 login_mode:(EWalletMode)login_mode
                 login_desc:(NSString*)login_desc
    errMsgInvalidPrivateKey:(NSString*)errMsgInvalidPrivateKey errMsgActivePermissionNotEnough:(NSString*)errMsgActivePermissionNotEnough
{
    assert([pub_pri_keys_hash count] > 0);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    [this showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[chainMgr queryAccountDataHashFromKeys:[pub_pri_keys_hash allKeys]] then:(^id(id account_data_hash) {
        if ([account_data_hash count] <= 0){
            [this hideBlockView];
            [OrgUtils makeToast:errMsgInvalidPrivateKey];
            return nil;
        }
        id account_data_list = [account_data_hash allValues];
        //  TODO:一个私钥关联多个账号
#ifndef DEBUG
        if ([account_data_list count] >= 2){
            NSString* name_join_strings = [[account_data_list ruby_map:(^id(id src) {
                return [src objectForKey:@"name"];
            })] componentsJoinedByString:@","];
            //            CLS_LOG(@"ONE KEY %@ ACCOUNTS: %@", @([account_data_list count]), name_join_strings);
        }
#endif
        //  默认选择第一个账号 TODO:弹框选择一个
        id account_data = [account_data_list firstObject];
        return [[chainMgr queryFullAccountInfo:account_data[@"id"]] then:(^id(id full_data) {
            [this hideBlockView];
            
            if (!full_data || [full_data isKindOfClass:[NSNull class]])
            {
                //  这里的帐号信息应该存在，因为帐号ID是通过 get_key_references 返回的。
                [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsQueryAccountFailed", @"查询帐号信息失败，请稍后再试。")];
                return nil;
            }
            
            //  获取账号数据
            id account = [full_data objectForKey:@"account"];
            NSString* accountName = account[@"name"];
            
            //  验证Active权限，导入钱包时不验证。
            if (checkActivePermission){
                //  获取active权限数据
                id account_active = [account objectForKey:@"active"];
                assert(account_active);
                
                //  检测权限是否足够签署需要active权限的交易。
                EAccountPermissionStatus status = [WalletManager calcPermissionStatus:account_active
                                                                      privateKeysHash:pub_pri_keys_hash];
                if (status == EAPS_NO_PERMISSION){
                    [OrgUtils makeToast:errMsgInvalidPrivateKey];
                    return nil;
                }else if (status == EAPS_PARTIAL_PERMISSION){
                    [OrgUtils makeToast:errMsgActivePermissionNotEnough];
                    return nil;
                }
            }
            
            //  筛选账号 account 所有公钥对应的私钥。（即：有效私钥）
            NSMutableDictionary* account_all_pubkeys = [WalletManager getAllPublicKeyFromAccountData:account result:nil];
            NSMutableArray* valid_private_wif_keys = [NSMutableArray array];
            for (NSString* pubkey in pub_pri_keys_hash) {
                if ([[account_all_pubkeys objectForKey:pubkey] boolValue]){
                    [valid_private_wif_keys addObject:[pub_pri_keys_hash objectForKey:pubkey]];
                }
            }
            assert([valid_private_wif_keys count] > 0);
            
            if (!checkActivePermission){
                //  导入账号到现有钱包BIN文件中
                id full_wallet_bin = [[WalletManager sharedWalletManager] walletBinImportAccount:accountName
                                                                               privateKeyWifList:[valid_private_wif_keys copy]];
                assert(full_wallet_bin);
                [[AppCacheManager sharedAppCacheManager] updateWalletBin:full_wallet_bin];
                [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                //  重新解锁（即刷新解锁后的账号信息）。
                id unlockInfos = [[WalletManager sharedWalletManager] reUnlock];
                assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
                
                //  返回
                [TempManager sharedTempManager].importToWalletDirty = YES;
                [this showMessageAndClose:NSLocalizedString(@"kWalletImportSuccess", @"导入完成")];
            }else{
                //  创建完整钱包模式
                id full_wallet_bin = [[WalletManager sharedWalletManager] genFullWalletData:accountName
                                                                           private_wif_keys:[valid_private_wif_keys copy]
                                                                            wallet_password:pTradePassword];
                
                //  保存钱包信息
                [[AppCacheManager sharedAppCacheManager] setWalletInfo:login_mode
                                                           accountInfo:full_data
                                                           accountName:accountName
                                                         fullWalletBin:full_wallet_bin];
                [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                //  导入成功 用交易密码 直接解锁。
                id unlockInfos = [[WalletManager sharedWalletManager] unLock:pTradePassword];
                assert(unlockInfos &&
                       [[unlockInfos objectForKey:@"unlockSuccess"] boolValue] &&
                       [[unlockInfos objectForKey:@"haveActivePermission"] boolValue]);
                //  [统计]
                [OrgUtils logEvents:@"loginEvent" params:@{@"mode":@(login_mode), @"desc":login_desc ?: @"unknown"}];
                
                //  返回
                [this showMessageAndClose:NSLocalizedString(@"kLoginTipsLoginOK", @"登录成功。")];
            }
            return nil;
        })];
    })] catch:(^id(id error) {
        [this hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    })];
}

+ (void)showPicker:(VCBase*)this selectAsset:(NSArray*)assets title:(NSString*)title callback:(void (^)(id selectItem))callback
{
    NSArray* itemlist = [assets ruby_map:(^id(id src) {
        return [src objectForKey:@"symbol"];
    })];
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:this
                                                       message:title
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:itemlist
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            callback([assets objectAtIndex:buttonIndex]);
        }
    }];
}

+ (void)showPicker:(VCBase*)this
      object_lists:(NSArray*)object_lists
               key:(NSString*)key
             title:(NSString*)title
          callback:(void (^)(id selectItem))callback
{
    NSArray* itemlist = [object_lists ruby_map:(^id(id src) {
        return [src objectForKey:key];
    })];
    
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:this
                                                       message:title
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:itemlist
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            callback([object_lists objectAtIndex:buttonIndex]);
        }
    }];
}

/*
 *  确保依赖
 */
+ (void)guardGrapheneObjectDependence:(VCBase*)vc object_ids:(id)object_ids body:(void (^)())body
{
    assert(vc);
    assert(object_ids);
    assert(body);
    
    if (![object_ids isKindOfClass:[NSArray class]]) {
        object_ids = @[object_ids];
    }
    
    [self simpleRequest:vc request:[[ChainObjectManager sharedChainObjectManager] queryAllGrapheneObjects:object_ids] callback:^(id data) {
        body();
    }];
}

/*
 *  (public) 封装基本的请求操作。
 */
+ (void)simpleRequest:(VCBase*)vc request:(WsPromise*)request callback:(void (^)(id data))callback
{
    assert(vc);
    assert(request);
    assert(callback);
    
    [vc showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[request then:^id(id data) {
        [vc hideBlockView];
        callback(data);
        return nil;
    }] catch:^id(id error) {
        [vc hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

/*
 *  (public) 判断两个资产哪个作为base资产，返回base资产的symbol。
 */
+ (NSString*)calcBaseAsset:(NSString*)asset_symbol01 asset_symbol02:(NSString*)asset_symbol02
{
    id priorityHash = [[ChainObjectManager sharedChainObjectManager] genAssetBasePriorityHash];
    assert(priorityHash);
    NSInteger priority01 = [[priorityHash objectForKey:asset_symbol01] integerValue];
    NSInteger priority02 = [[priorityHash objectForKey:asset_symbol02] integerValue];
    if (priority01 > priority02) {
        return asset_symbol01;
    } else {
        return asset_symbol02;
    }
}

/*
 *  (public) 添加空白处点击事件
 */
+ (void)addSpaceTapHandler:(VCBase*)vc body:(UITapGestureRecognizerBlockHandler)body
{
    UITapGestureRecognizer2Block* pTap = [[UITapGestureRecognizer2Block alloc] initWithWeakSelf:vc body:body];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [vc.view addGestureRecognizer:pTap];
}

/*
 *  (public) 处理响应 - 检测APP版本信息数据返回。有新版本返回 YES，否新版本返回 NO。
 */
+ (BOOL)processCheckAppVersionResponsed:(NSDictionary*)pConfig remind_later_callback:(void (^)())remind_later_callback
{
    if (pConfig && [pConfig count] > 0) {
        NSString* pNativeVersion = [NativeAppDelegate appShortVersion];
        NSString* pNewestVersion = [pConfig objectForKey:@"version"];
        if (pNewestVersion)
        {
            NSInteger ret = [OrgUtils compareVersion:pNewestVersion other:pNativeVersion];
            if (ret > 0)
            {
                //  提示更新
                NSString* infoKey;
                if ([NativeAppDelegate sharedAppDelegate].isLanguageCN){
                    infoKey = @"newVersionInfo";
                }else{
                    infoKey = @"newVersionInfoEn";
                }
                [self showAppUpdateWindow:[pConfig objectForKey:infoKey]
                                      url:[pConfig objectForKey:@"appURL"]
                              forceUpdate:[[pConfig objectForKey:@"force"] boolValue]
                    remind_later_callback:remind_later_callback];
                //  有新版本
                return YES;
            }
        }
    }
    //  无新版本
    return NO;
}

/*
 *  (private) 询问 - 是否更新版本
 */
+ (void)showAppUpdateWindow:(NSString*)message
                        url:(NSString*)url
                forceUpdate:(BOOL)forceUpdate
      remind_later_callback:(void (^)())remind_later_callback
{
    NSArray* otherButtons = nil;
    if (!forceUpdate){
        otherButtons = [NSArray arrayWithObject:NSLocalizedString(@"kRemindMeLatter", @"稍后提醒")];
    }
    [[UIAlertViewManager sharedUIAlertViewManager] showMessageEx:message
                                                       withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                    cancelButton:NSLocalizedString(@"kUpgradeNow", @"立即升级")
                                                    otherButtons:otherButtons
                                                      completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 0){
            //  立即升级
            [OrgUtils safariOpenURL:url];
        } else {
            //  稍后提醒
            if (remind_later_callback) {
                remind_later_callback();
            }
        }
    }];
}

/*
 *  (public) 生成邀请链接
 */
+ (NSString*)genShareLink:(BOOL)containWelcomeMessage
{
    id invite_link = [[SettingManager sharedSettingManager] getAppUrls:@"invite_link"];
    assert(invite_link && ![invite_link isEqualToString:@""]);
    
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    id value = [NSString stringWithFormat:@"%@?lang=%@",
                invite_link, NSLocalizedString(@"kShareLinkPageDefaultLang", @"share link lang")];
    if ([walletMgr isWalletExist]) {
        value = [NSString stringWithFormat:@"%@&r=%@", value, [walletMgr getWalletAccountName]];
    }
    if (containWelcomeMessage) {
        value = [NSString stringWithFormat:@"%@\n%@",
                 NSLocalizedString(@"kShareWelcomeMessage", @"立即注册 KSH 账号，享受每日高额挖矿收益。（推荐使用系统浏览器打开）"), value];
    }
    
    return value;
}

/*
 *  (public) 处理导入隐私账户。
 */
+ (void)processImportBlindAccount:(VCBase*)vc
                       alias_name:(NSString*)str_alias_name
                         password:(NSString*)str_password
                 success_callback:(void (^)(id blind_account))success_callback
{
    assert(vc);
    
    if (!str_alias_name || [str_alias_name isEqualToString:@""]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrPleaseInputAliasName", @"请输入隐私账户别名。")];
        return;
    }
    
    if (!str_password ||
        [str_password  isEqualToString:@""] ||
        ![WalletManager isValidStealthTransferBrainKey:str_password check_sum_prefix:kAppBlindAccountBrainKeyCheckSumPrefix]) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrPleaseInputBlindAccountBrainKey", @"请输入有效的隐私账户密码。")];
        return;
    }
    
    //  开始导入
    HDWallet* hdk = [HDWallet fromMnemonic:str_password];
    HDWallet* main_key = [hdk deriveBitshares:EHDBPT_STEALTH_MAINKEY];
    id wif_main_pri_key = [main_key toWifPrivateKey];
    id wif_main_pub_key = [OrgUtils genBtsAddressFromWifPrivateKey:wif_main_pri_key];
    
    id blind_account = @{
        @"public_key": wif_main_pub_key,
        @"alias_name": str_alias_name,
        @"parent_key": @""
    };
    
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    assert([walletMgr isWalletExist] && ![walletMgr isPasswordMode]);
    //  解锁钱包
    [vc GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            //  隐私交易主地址导入钱包
            AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
            
            id full_wallet_bin = [walletMgr walletBinImportAccount:nil privateKeyWifList:@[wif_main_pri_key]];
            assert(full_wallet_bin);
            [pAppCache appendBlindAccount:blind_account autosave:NO];
            [pAppCache updateWalletBin:full_wallet_bin];
            [pAppCache autoBackupWalletToWebdir:NO];
            
            //  重新解锁（即刷新解锁后的账号信息）。
            id unlockInfos = [walletMgr reUnlock];
            assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
            
            //  导入成功
            if (success_callback) {
                success_callback(blind_account);
            }
        }
    }];
}

/*
 *  (public) 处理交易对状态变更，收藏 or 取消收藏。变更成功返回 YES，否则返回 NO。
 */
+ (BOOL)processMyFavPairStateChanged:(id)quote base:(id)base associated_view:(UIButton*)associated_view
{
    assert(quote);
    assert(base);
    
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    
    id quote_id = [quote objectForKey:@"id"];
    id base_id = [base objectForKey:@"id"];
    
    if ([pAppCache is_fav_market:quote_id base:base_id]) {
        //  删除的情况
        [pAppCache remove_fav_markets:quote_id base:base_id];
        if (associated_view) {
            associated_view.tintColor = [ThemeManager sharedThemeManager].textColorGray;
        }
        [OrgUtils makeToast:NSLocalizedString(@"kTipsAddFavDelete", @"删除自选成功")];
        //  [统计]
        [OrgUtils logEvents:@"event_market_remove_fav" params:@{@"base":base_id, @"quote":quote_id}];
    } else {
        //  添加的情况，如果是自定义交易对，则需要判断是否达到上限，收藏交易对则不用额外处理。
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        
        //  自定义交易对判断
        if (![chainMgr isDefaultPair:quote base:base]) {
            NSInteger max_custom_pair_num = [[chainMgr getDefaultParameters][@"max_custom_pair_num"] integerValue];
            NSInteger n_custom = 0;
            id favhash = [pAppCache get_all_fav_markets];
            for (id key in favhash) {
                id favitem = [favhash objectForKey:key];
                assert(favitem);
                id q = [chainMgr getChainObjectByID:favitem[@"quote"]];
                id b = [chainMgr getChainObjectByID:favitem[@"base"]];
                if (![chainMgr isDefaultPair:q base:b]) {
                    n_custom += 1;
                }
            }
            if (n_custom >= max_custom_pair_num) {
                [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kSearchTipsMaxCustomParisNumber", @"最多只能自定义 %@ 个交易对。"),
                                     @(max_custom_pair_num)]];
                return NO;
            }
        }
        
        //  不限制：添加收藏。
        [pAppCache set_fav_markets:quote_id base:base_id];
        if (associated_view) {
            associated_view.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
        }
        [OrgUtils makeToast:NSLocalizedString(@"kTipsAddFavSuccess", @"添加自选成功")];
        //  [统计]
        [OrgUtils logEvents:@"event_market_add_fav" params:@{@"base":base_id, @"quote":quote_id}];
    }
    
    //  保存
    [pAppCache saveFavMarketsToFile];
    
    //  标记：自选列表需要更新
    [TempManager sharedTempManager].favoritesMarketDirty = YES;
    
    return YES;
}

/*
 *  (public) UI - 显示数字输入对话框
 */
+ (void)showInputDecimalClicked:(NSString*)args_title
                    placeholder:(NSString*)args_placeholder
                      precision:(NSInteger)precision
                      min_value:(NSDecimalNumber*)n_min_value
                      max_value:(NSDecimalNumber*)n_max_value
                          scale:(NSDecimalNumber*)n_scale
                       callback:(void (^)(NSDecimalNumber* n_value))callback
{
    assert(args_title);
    assert(args_placeholder);
    
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:args_title
                                                      withTitle:nil
                                                    placeholder:args_placeholder
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:(^(SCLTextView *tf) {
        if (precision > 0) {
            tf.keyboardType = UIKeyboardTypeDecimalPad;
            tf.iDecimalPrecision = precision;
        } else {
            tf.keyboardType = UIKeyboardTypeNumberPad;
            tf.iDecimalPrecision = 0;
        }
    })
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue)
                                                                 {
        if (buttonIndex != 0){
            NSDecimalNumber* n_value = [OrgUtils auxGetStringDecimalNumberValue:tfvalue];
            //  最小值
            if (n_min_value && [n_value compare:n_min_value] < 0) {
                n_value = n_min_value;
            }
            //  最大值
            if (n_max_value && [n_value compare:n_max_value] > 0) {
                n_value = n_max_value;
            }
            //  缩放
            if (n_scale) {
                n_value = [n_value decimalNumberByMultiplyingBy:n_scale];
            }
            callback(n_value);
        }
    })];
}

@end
