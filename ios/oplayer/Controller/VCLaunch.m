//
//  VCLaunch.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCLaunch.h"
#import "OrgUtils.h"
#import "MySecurityFileMgr.h"
#import "ScheduleManager.h"
#import "OtcManager.h"

@interface VCLaunch ()
{
}

@end

@implementation VCLaunch

- (void)dealloc
{
}

- (id)init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

/**
 *  (private) 获取启动界面的图片名
 */
- (NSString*)getLaunchImageName
{
    NSString* viewOrientation = @"Portrait";
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
    {
        viewOrientation = @"Landscape";
    }
    
    CGSize viewSize = [[UIScreen mainScreen] bounds].size;
    for (NSDictionary* dict in [[[NSBundle mainBundle] infoDictionary] valueForKey:@"UILaunchImages"])
    {
        CGSize imageSize = CGSizeFromString(dict[@"UILaunchImageSize"]);
        
        if (CGSizeEqualToSize(imageSize, viewSize) && [viewOrientation isEqualToString:dict[@"UILaunchImageOrientation"]])
        {
            return dict[@"UILaunchImageName"];
        }
    }
    
    return nil;
}

/**
 *  (private) 获取启动界面的图片
 */
- (UIImage*)getLaunchImage
{
    NSString* name = [self getLaunchImageName];
    if (!name){
        return nil;
    }
    return [UIImage imageNamed:name];
}

/**
 *  (private) 裁剪图像
 */
- (UIImage*)clipImage:(CGImageRef)src rect:(CGRect)rect scale:(CGFloat)scale
{
    CGImageRef imageRef = CGImageCreateWithImageInRect(src, rect);
    UIImage* newImage = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(imageRef);
    return newImage;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //  启动界面背景图
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    UIImage* launchImage = [self getLaunchImage] ?: [UIImage imageNamed:@"LaunchImage"];
    UIImageView* launchFullScreenView = [[UIImageView alloc] initWithImage:launchImage];
    launchFullScreenView.frame = screenRect;
    [self.view addSubview:launchFullScreenView];
    
    //  启动初始化
    [self startInit:YES];
}

/**
 *  启动初始化
 */
- (void)startInit:(BOOL)first_init
{
    [[[[self class] checkAppUpdate] then:(^id(id pVersionConfig) {
        [SettingManager sharedSettingManager].serverConfig = [NSDictionary dictionaryWithDictionary:pVersionConfig];
        return [[self asyncInitBitshares:first_init] then:(^id(id data) {
            [self _onLoadVersionJsonFinish:pVersionConfig];
            return nil;
        })];
    })] catch:(^id(id error) {
        [self onFirstInitFailed];
        return nil;
    })];
}

- (void)onFirstInitFailed
{
    [[UIAlertViewManager sharedUIAlertViewManager] showMessageEx:NSLocalizedString(@"kAppFirstInitNetworkFailed", @"APP网络初始化异常了，请按照以下步骤处理：\n1、如果是首次启动，请允许应用使用无线数据。\n2、其他情况请检查您的设备网络是否正常。")
                                                       withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                    cancelButton:nil
                                                    otherButtons:@[NSLocalizedString(@"kAppBtnReInit", @"重试")]
                                                      completion:^(NSInteger buttonIndex)
     {
        [OrgUtils logEvents:@"appReInitNetwork" params:@{}];
        [self startInit:NO];
    }];
}

/*
 *  (public) 检测APP更新数据。
 */
+ (WsPromise*)checkAppUpdate
{
#if kAppCheckUpdate
    
    //  检测更新
    return [WsPromise promise:(^(WsResolveHandler resolve, WsRejectHandler reject) {
#ifdef DEBUG
        //  调试模式：直接加载本地version.json
        NSDictionary* pVersionJson = [self loadBundleVersionJson];
        resolve(pVersionJson);
#else
        //  正式环境 or 测试更新模式下 从服务器加载。
        NSString* pNativeVersion = [NativeAppDelegate appShortVersion];
        NSString* flags = @"0";
        id version_url = [NSString stringWithFormat:@"https://www.nbs...com/app/ios/%@_%@/version.json?f=%@", @(kAppChannelID), pNativeVersion, flags];
        [OrgUtils asyncFetchJson:version_url
                         timeout:[[NativeAppDelegate sharedAppDelegate] getRequestTimeout]
                 completionBlock:^(id pVersionJson)
         {
            if (!pVersionJson)
            {
                pVersionJson = [self loadNativeVersionJson];
            }
            resolve(pVersionJson);
        }];
#endif
    })];
#else
    
    //  不检测更新
    return [WsPromise resolve:@{}];
#endif  //  kAppCheckUpdate
}

//  从bundle加载version.json
+ (NSDictionary*)loadBundleVersionJson
{
    NSString* bundlePath = [NSBundle mainBundle].resourcePath;
    NSString* fullPathInApp = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, kAppStaticDir, kAppCacheNameVersionJsonByVer];
    NSData* data = [NSData dataWithContentsOfFile:fullPathInApp];
    if (!data){
        return nil;
    }
    NSString* rawdatajson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!rawdatajson){
        return nil;
    }
    NSDictionary* pCacheVersionJson = [NSJSONSerialization JSONObjectWithData:[rawdatajson dataUsingEncoding:NSUTF8StringEncoding]
                                                                      options:NSJSONReadingAllowFragments error:nil];
    return pCacheVersionJson;
}

//  从服务器加载version.json失败后则加载本地等version.json（app内部或cache缓存内）
+ (NSDictionary*)loadNativeVersionJson
{
    NSString* pCacheVersionFilename = [OrgUtils makeFullPathByVerStorage:kAppCacheNameVersionJsonByVer];
    NSDictionary* pCacheVersionJson = [MySecurityFileMgr loadDicSecFile:pCacheVersionFilename];
    if (pCacheVersionJson){
        return pCacheVersionJson;
    }
    return [self loadBundleVersionJson];
}

- (void)_onLoadVersionJsonFinish:(NSDictionary*)pConfig
{
    BOOL bFoundNewVersion = [VcUtils processCheckAppVersionResponsed:pConfig remind_later_callback:^{
        //  有新版本，但稍后提醒。则直接启动。
        [self _enterToMain];
    }];
    if (!bFoundNewVersion) {
        //  无新版本，直接启动。
        [self _enterToMain];
    }
}

/**
 *  (private) 进入主界面。
 */
- (void)_enterToMain
{
    //  进入主界面
    [[NativeAppDelegate sharedAppDelegate] closeLaunchWindow];
}

/**
 *  (private) 初始化APP核心逻辑
 */
- (WsPromise*)asyncInitBitshares:(BOOL)first_init
{
    return [WsPromise promise:(^(WsResolveHandler resolve, WsRejectHandler reject) {
        GrapheneConnectionManager* connMgr = [GrapheneConnectionManager sharedGrapheneConnectionManager];
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        WalletManager* walletMgr = [WalletManager sharedWalletManager];
        AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
        BOOL force_use_random_node = first_init ? NO : YES;
        [[[connMgr Start:force_use_random_node] then:(^id(id success) {
            //  初始化石墨烯网络状态
            [[[chainMgr grapheneNetworkInit] then:(^id(id data) {
                //  初始化依赖资产（内置资产 + 自定义交易对等）
                id dependence_syms = [chainMgr getConfigDependenceAssetSymbols];
                id custom_asset_ids = [pAppCache get_fav_markets_asset_ids];
                return [[chainMgr queryAssetsBySymbols:dependence_syms ids:custom_asset_ids] then:^id(id data) {
#ifdef DEBUG
                    //  确保查询成功。
                    for (id sym in dependence_syms) {

                        assert([chainMgr getAssetBySymbol:sym]);
                    }
                    for (id oid in custom_asset_ids) {
                        assert([chainMgr getChainObjectByID:oid]);
                    }
#endif  //  DEBUG
                    //  生成市场数据结构
                    [chainMgr buildAllMarketsInfos];
                    //  初始化数据
                    WsPromise* initTickerData = [chainMgr marketsInitAllTickerData];
                    WsPromise* initGlobalProperties = [[connMgr last_connection].api_db exec:@"get_global_properties" params:@[]];
                    WsPromise* initFeeAssetInfo = [chainMgr queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
                    //  每次启动都刷新当前账号信息
                    id initFullUserData = [NSNull null];
                    if ([walletMgr isWalletExist]){
                        initFullUserData = [chainMgr queryFullAccountInfo:[[walletMgr getWalletInfo] objectForKey:@"kAccountName"]];
                    }
                    WsPromise* initOtc = [[OtcManager sharedOtcManager] queryConfig];
                    WsPromise* initAppAnnouncement = [[ScheduleManager sharedScheduleManager] queryAppAnnouncement];
                    return [[WsPromise all:@[initTickerData,
                                             initGlobalProperties,
                                             initFeeAssetInfo,
                                             initFullUserData,
                                             initOtc,
                                             initAppAnnouncement]] then:(^id(id data_array) {
                        [self hideBlockView];
                        //  更新全局属性
                        [chainMgr updateObjectGlobalProperties:[data_array objectAtIndex:1]];
                        //  更新帐号完整数据
                        id full_account_data = [data_array objectAtIndex:3];
                        if (full_account_data && ![full_account_data isKindOfClass:[NSNull class]]){
                            [pAppCache updateWalletAccountInfo:full_account_data];
                        }
                        //  启动完毕备份钱包
                        [pAppCache autoBackupWalletToWebdir:NO];
                        //  添加ticker更新任务
                        [[ScheduleManager sharedScheduleManager] autoRefreshTickerScheduleByMergedMarketInfos];
                        //  初始化网络成功
                        [OrgUtils logEvents:@"appInitNetworkDone" params:@{}];
                        resolve(@YES);
                        return nil;
                    })];
                }];
            })] catch:(^id(id error) {
                reject(NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。"));
                return nil;
            })];
            return nil;
        })] catch:(^id(id error) {
            reject(NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。"));
            return nil;
        })];
    })];
}

@end
