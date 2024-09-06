//
//  VCMarketContainer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCMarketContainer.h"
#import "BitsharesClientManager.h"
#import "GrapheneConnectionManager.h"
#import "ScheduleManager.h"
#import "GrapheneApi.h"
#import "ViewVerticalScrollText.h"

#import "VCTradingPairMgr.h"
#import "VCMarketInfo.h"

#import <SocketRocket/SocketRocket.h>

#import "VCTest.h"

#import "VCSearchNetwork.h"

#import "AppCacheManager.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "OrgUtils.h"
#import "MBProgressHUDSingleton.h"

#import "OrgUtils.h"

@interface VCMarketContainer ()
{
    BOOL                        _selfShowing;                       //  首页自身是否显示中
    BOOL                        _grapheneInitDone;                  //  石墨烯网络是否初始化完毕
    NSTimer*                    _tickerRefreshTimer;                //  ticker 数据定时刷新计时器
    
    ViewVerticalScrollText*     _viewAppNotice;
}

@end

@implementation VCMarketContainer

-(void)dealloc
{
    //  移除前后台事件
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kBtsSubAppAnnouncementNewData object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    _viewAppNotice = nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _selfShowing = YES;
        _grapheneInitDone = NO;
        _tickerRefreshTimer = nil;
    }
    return self;
}

#pragma mark- ticker ui refresh timer

- (void)startTimerTickerRefresh
{
    if (!_grapheneInitDone){
        return;
    }
    if (!_tickerRefreshTimer){
        _tickerRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               target:self
                                                             selector:@selector(onTimerTickerRefresh:)
                                                             userInfo:nil
                                                              repeats:YES];
        [_tickerRefreshTimer fire];
    }
}

- (void)onTimerTickerRefresh:(NSTimer*)timer
{
    if ([TempManager sharedTempManager].tickerDataDirty){
        //  清除标记
        [TempManager sharedTempManager].tickerDataDirty = NO;
        //  刷新
        if (_subvcArrays){
            for (VCMarketInfo* vc in _subvcArrays) {
                [vc onRefreshTickerData];
            }
        }
    }
}

- (void)stopTimerTickerRefresh
{
    if (_tickerRefreshTimer){
        [_tickerRefreshTimer invalidate];
        _tickerRefreshTimer = nil;
    }
}

#pragma mark- foreground & background event notification

//  事件：已经进入前台
- (void)onUIApplicationDidBecomeActiveNotification
{    
    //  检测语言是否发生变化，变化后重新初始化jsb。并删除之前多config缓存。
    BOOL langChanged = NO;
    NSString* lang = [NativeAppDelegate getSystemLanguage];
    if (![lang isEqualToString:[NativeAppDelegate sharedAppDelegate].currLanguage]){
        langChanged = YES;
        //  重新初始化语言
        [[NativeAppDelegate sharedAppDelegate] initLanguageInfo];
        NSLog(@"system language changed...");
    }
    //  回到前台检测是否需要重新连接。
    if (_grapheneInitDone){        
        [[GrapheneConnectionManager sharedGrapheneConnectionManager] reconnect_all];
    }
}

//  事件：将要进入后台
- (void)onUIApplicationWillResignActiveNotification
{
    //  [统计]
    [OrgUtils logEvents:@"enterBackground" params:@{}];
    //  处理逻辑
    [[AppCacheManager sharedAppCacheManager] saveToFile];
    //  记录即将进入后台的时间
    [TempManager sharedTempManager].lastEnterBackgroundTs = [[NSDate date] timeIntervalSince1970];
    //  记录当前http代理标记
    [TempManager sharedTempManager].lastUseHttpProxy = [[SettingManager sharedSettingManager] useHttpProxy];
}

//  事件：已经进入后台
- (void)onUIApplicationDidEnterBackgroundNotification
{
    //  ...
}

//  事件：将要进入前台
- (void)onUIApplicationWillEnterForegroundNotification
{
    //  [统计]
    [OrgUtils logEvents:@"enterForeground" params:@{}];
}

- (void)_onAppInitDone
{
    //  初始化完毕
    _grapheneInitDone = YES;
    
    //  初始化完成：刷新各市场ticker数据
    if (_subvcArrays) {
        for (VCMarketInfo* vc in _subvcArrays) {
            [vc marketTickerDataInitDone];
        }
    }
}

/**
 *  事件 - 添加交易对
 */
- (void)onAddMarketInfos
{
    VCTradingPairMgr* vc = [[VCTradingPairMgr alloc] init];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleMyPairsMgr", @"交易对管理") backtitle:kVcDefaultBackTitleName];
}

- (NSInteger)getTitleDefaultSelectedIndex
{
    //  REMARK：默认选中第二个市场（第一个是自选市场）
    return 2;
}

- (NSArray*)getTitleStringArray
{
    NSMutableArray* ary = [NSMutableArray arrayWithObject:NSLocalizedString(@"kLabelMarketFavorites", @"自选")];
    [ary addObjectsFromArray:[[[ChainObjectManager sharedChainObjectManager] getMergedMarketInfos] ruby_map:(^id(id market) {
        id name_key = [market objectForKey:@"name_key"];
        return name_key && ![name_key isEqualToString:@""] ? NSLocalizedString(name_key, @"market name") : [[market objectForKey:@"base"] objectForKey:@"name"];
    })]];
    return [ary copy];
}

- (NSArray*)getSubPageVCArray
{
    //  REMARK：marketInfo 参数为 nil，说明为自选市场。
    NSMutableArray* ary = [NSMutableArray arrayWithObject:[[VCMarketInfo alloc] initWithOwner:self marketInfo:nil]];
    NSArray* base = [[[ChainObjectManager sharedChainObjectManager] getMergedMarketInfos] ruby_map:(^id(id market) {
        return [[VCMarketInfo alloc] initWithOwner:self marketInfo:market];
    })];
    [ary addObjectsFromArray:base];
    return [ary copy];
}

- (CGFloat)getMainViewOffsetY
{
    id latestAppAnnouncement = [ScheduleManager sharedScheduleManager].latestAppAnnouncement;
    if (latestAppAnnouncement && [latestAppAnnouncement count] > 0) {
        //  公告栏
        return 32;
    } else {
        return 0;
    }
}

- (void)onSubAppAnnouncementNewData:(NSNotification*)notification
{
    if (!notification){
        return;
    }
    id userinfo = notification.userInfo;
    if (!userinfo){
        return;
    }
    id data = [userinfo objectForKey:@"data"];
    if (!data || [data count] <= 0) {
        return;
    }
    if (_viewAppNotice) {
        _viewAppNotice.textArray = [data copy];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右边➕按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onAddMarketInfos)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  UI - 广告
    id latestAppAnnouncement = [ScheduleManager sharedScheduleManager].latestAppAnnouncement;
    if (latestAppAnnouncement && [latestAppAnnouncement count] > 0) {
        _viewAppNotice = [[ViewVerticalScrollText alloc] init];
        _viewAppNotice.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [self getMainViewOffsetY]);
        [self.view addSubview:_viewAppNotice];
        _viewAppNotice.textArray = [latestAppAnnouncement copy];
    } else {
        _viewAppNotice = nil;
    }
    
	// Do any additional setup after loading the view.
    
    //  注册前后台事件
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUIApplicationDidBecomeActiveNotification)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUIApplicationWillResignActiveNotification)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUIApplicationDidEnterBackgroundNotification)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUIApplicationWillEnterForegroundNotification)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    //  APP公告事件
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSubAppAnnouncementNewData:)
                                                 name:kBtsSubAppAnnouncementNewData
                                               object:nil];
    
    //  初始化完毕
    [self _onAppInitDone];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //  自选市场可能发生变化，重新加载。
    [self onRefreshFavoritesMarket];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _selfShowing = YES;
    //  启动UI刷新定时器
    [self startTimerTickerRefresh];
}

- (void)viewDidDisappear:(BOOL)animated
{
    //  停止UI刷新计时器
    [self stopTimerTickerRefresh];
    
    _selfShowing = NO;
    [super viewDidDisappear:animated];
}

/**
 *  (private) 事件 - 刷新自选(关注、收藏、自定义交易对)市场
 */
- (void)onRefreshFavoritesMarket
{
    if ([TempManager sharedTempManager].favoritesMarketDirty){
        //  重新构建各市场分组信息
        [[ChainObjectManager sharedChainObjectManager] buildAllMarketsInfos];
        //  清除标记
        [TempManager sharedTempManager].favoritesMarketDirty = NO;
        //  刷新
        if (_subvcArrays){
            for (VCMarketInfo* vc in _subvcArrays) {
                [vc onRefreshFavoritesMarket];
            }
        }
        //  自定义交易对发生变化，重新刷新ticker更新任务。
        [[ScheduleManager sharedScheduleManager] autoRefreshTickerScheduleByMergedMarketInfos];
    }
}

#pragma mark- switch theme
- (void)switchTheme
{
    [super switchTheme];
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    self.navigationItem.rightBarButtonItem.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
}

#pragma mark- switch language
- (void)switchLanguage
{
    [[self buttonWithTag:1] setTitle:NSLocalizedString(@"kLabelMarketFavorites", @"自选") forState:UIControlStateNormal];
    self.title = NSLocalizedString(@"kTabBarNameMarkets", @"行情");
    self.tabBarItem.title = NSLocalizedString(@"kTabBarNameMarkets", @"行情");
    if (_subvcArrays){
        for (VCMarketInfo* vc in _subvcArrays) {
            [vc switchLanguage];
        }
    }
}

@end
