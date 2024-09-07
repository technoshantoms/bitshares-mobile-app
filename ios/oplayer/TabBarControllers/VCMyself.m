//
//  VCMyself.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCMyself.h"
#import "VCUserCenter.h"
#import "WalletManager.h"

#import "BitsharesClientManager.h"

#import "VCProposal.h"
#import "VCAssetManager.h"
#import "VCWalletManager.h"
#import "VCUserAssets.h"
#import "VCUserOrders.h"
#import "VCVestingBalance.h"

#import "VCBtsaiWebView.h"
#import "VCSetting.h"

#import "VCImportAccount.h"
#import "ViewFaceCell.h"
#import "VCConvertToWalletMode.h"

#import "OrgUtils.h"
#import "AppCacheManager.h"

#import "VCNotice.h"

#ifdef DEBUG
#import "VCTest.h"
#endif  //  DEBUG

enum
{
    kVcBanner = 0,              //  账号管理登录部分banner
    kVcAssets,                  //  资产和订单
    kVcFaq,                     //  常见问题
    kVcSetting                  //  设置
};

enum
{
    kVcSubUserAsset = 0,        //  我的资产
    kVcSubUserOrder,            //  订单管理
    kVcSubWalletMgr,            //  钱包管理
    kVcSubProposal,             //  提案管理
    kVcSubAssetMgr,             //  资产管理
};

enum
{
    kVcSubFAQ = 0,              //  常见问题
};

enum
{
//    kVcSubShareLink = 0,        //  分享专属链接
    kVcSubSettingsEx = 0,       //  设置
#ifdef DEBUG
    kVcSubTestPage,             //  测试
#endif  //  DEBUG
};

@interface VCMyself ()
{    
    UITableView*            _mainTableView;
    NSArray*                _dataArray; //  assgin
    
    ViewFaceCell*           _faceView;
}

@end

@implementation VCMyself

- (void)dealloc
{
    if (_faceView){
        if (_faceView.superview){
            [_faceView removeFromSuperview];
        }
        _faceView = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

/*
 *  事件 - 解锁/锁定 按钮点击。
 */
- (void)onLockButtonClicked:(UIButton*)sender
{
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    if (![walletMgr isWalletExist]) {
        return;
    }
    
    if ([walletMgr isLocked]) {
        //  解锁
        [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
            if (unlocked) {
                [_mainTableView reloadData];
                [OrgUtils makeToast:NSLocalizedString(@"kUserLockTipMessageUnlocked", @"已解锁")];
            }
        }];
    } else {
        //  锁定
        [walletMgr Lock];
        [_mainTableView reloadData];
        [OrgUtils makeToast:NSLocalizedString(@"kUserLockTipMessageLocked", @"已锁定")];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    _dataArray = [[[NSMutableArray array] ruby_apply:^(id obj) {
        NSArray* pSection1 = [NSArray arrayWithObjects:
                              @"kAccount",                      //  帐号
                              nil];
        [obj addObject:@{@"type":@(kVcBanner), @"rows":pSection1}];
        
        NSArray* pSection2 = [NSArray arrayWithObjects:
                              @"kLblCellMyBalance",             //  我的资产,
                              @"kLblCellOrderManagement",       //  订单管理,
                              @"kLblCellWalletAndMultiSign",    //  钱包&多签
                              @"kLblCellMyProposal",            //  待处理提案,
                              @"kLblCellAssetMgr",              //  资产管理,
                              nil];
        [obj addObject:@{@"type":@(kVcAssets), @"rows":pSection2}];
        
#if kAppModuleEnableFaq
        NSArray* pSection3 = [NSArray arrayWithObjects:
                              @"faq",                           //  常见问题,
                              nil];
        [obj addObject:@{@"type":@(kVcFaq), @"rows":pSection3}];
#endif  //  kAppModuleEnableFaq
        
        NSArray* pSection4 = [NSArray arrayWithObjects:
//                              @"kLblCellShareLink",             //  分享专属链接
                              @"kSettingEx",                    //  设置,
#ifdef DEBUG
                              @"测试页面",
#endif  //  DEBUG
                              nil];
        [obj addObject:@{@"type":@(kVcSetting), @"rows":pSection4}];
    }] copy];
    
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutTabbar] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  头像view
    _faceView = [[ViewFaceCell alloc] initWithOwner:self];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    //  登录后返回需要重新刷新列表
    [_mainTableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[_dataArray objectAtIndex:section] objectForKey:@"rows"] count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[[_dataArray objectAtIndex:indexPath.section] objectForKey:@"type"] integerValue] == kVcBanner)
    {
        //  头像部分
        if (_faceView){
            return (CGFloat)[_faceView getMaxDragHeight];
        }else{
            return 0.01f;
        }
    }
    else
    {
        return tableView.rowHeight;
    }
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSInteger type = [[[_dataArray objectAtIndex:section] objectForKey:@"type"] integerValue];
    if (type == kVcBanner || type == kVcAssets){
        return 0.01f;
    }
    return 15.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id secinfos = [_dataArray objectAtIndex:indexPath.section];
    NSInteger sectype = [[secinfos objectForKey:@"type"] integerValue];
    if (sectype == kVcBanner)
    {
        return _faceView;
    }
    
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    cell.backgroundColor = [UIColor clearColor];
    
    cell.showCustomBottomLine = YES;
    
    id ary = [secinfos objectForKey:@"rows"];
    
    cell.textLabel.text = NSLocalizedString([ary objectAtIndex:indexPath.row], @"");
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    //  设置图标
    switch (sectype) {
        case kVcAssets:
        {
            switch (indexPath.row) {
                case kVcSubProposal:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconProposal"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                case kVcSubAssetMgr:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconAssetMgr"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                case kVcSubWalletMgr:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconWallet"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                case kVcSubUserAsset:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconAssets"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                case kVcSubUserOrder:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconOrders"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case kVcFaq:
        {
            switch (indexPath.row) {
                case kVcSubFAQ:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconFaq"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
        case kVcSetting:
        {
            switch (indexPath.row) {
                case kVcSubSettingsEx:
                {
                    cell.imageView.image = [UIImage templateImageNamed:@"iconSetting"];
                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
                    break;
//                case kVcSubShareLink:
//                {
//                    cell.imageView.image = [UIImage templateImageNamed:@"iconShare"];
//                    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
//                }
//                    break;
                default:
                    break;
            }
        }
            break;
        default:
            break;
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        UIViewController* vc = nil;
        
        id secinfos = [_dataArray objectAtIndex:indexPath.section];
        NSInteger sectype = [[secinfos objectForKey:@"type"] integerValue];
        
        switch (sectype) {
            case kVcBanner:
            {
                if ([[WalletManager sharedWalletManager] isWalletExist]){
                    vc = [[VCUserCenterPages alloc] init];
                    vc.title = NSLocalizedString(@"kVcTitleAccountInfos", @"帐号信息");
                }else{
                    vc = [[VCImportAccount alloc] init];
                    vc.title = NSLocalizedString(@"kVcTitleLogin", @"登录");
                }
            }
                break;
            case kVcAssets: //  资产和订单
            {
                switch (indexPath.row) {
                    case kVcSubProposal:
                    {
                        [self GuardWalletExist:^{
                            VCProposal* vc = [[VCProposal alloc] init];
                            vc.title = NSLocalizedString(@"kVcTitleMyProposal", @"待处理提案");
                            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                        }];
                    }
                        break;
                    case kVcSubAssetMgr:
                    {
                        [self GuardWalletExist:^{
                            VCAssetManager* vc = [[VCAssetManager alloc] init];
                            vc.title = NSLocalizedString(@"kVcTitleAssetMgr", @"资产管理");
                            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                        }];
                    }
                        break;
                    case kVcSubWalletMgr:
                    {
                        [self GuardWalletExistWithWalletMode:NSLocalizedString(@"kLblTipsPasswordModeNotSupportMultiSign", "多签等功能仅支持钱包模式，是否为当前的账号创建本地钱包文件？")
                                                        body:^{
                            //  转到钱包&多签界面
                            VCWalletManager* vc = [[VCWalletManager alloc] init];
                            vc.title = NSLocalizedString(@"kVcTitleWalletAndMultiSign", @"钱包&多签");
                            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                        }];
                    }
                        break;
                    case kVcSubUserAsset:
                    {
                        [self GuardWalletExist:^{
                            [VcUtils viewUserAssets:self account:[[WalletManager sharedWalletManager] getWalletAccountName]];
                        }];
                    }
                        break;
                    case kVcSubUserOrder:
                    {
                        [self GuardWalletExist:^{
                            id uid = [[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"id"];
                            [VcUtils viewUserLimitOrders:self account:uid tradingPair:nil];
                        }];
                    }
                        break;
                    default:
                        break;
                }
            }
                break;
            case kVcFaq: //  常见问题、反馈、客服部分
            {
                //  TODO:测试代码
                //                id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
                //                id uid = [account objectForKey:@"id"];
                //
                //                NSInteger lock_ts = (NSInteger)[[NSDate date] timeIntervalSince1970] + 3600*5;
                //                id op = @{
                //                          @"fee":@{@"amount":@0, @"asset_id":@"1.3.0"},
                //                          @"creator":uid,
                //                          @"owner":uid,
                //                          @"amount":@{@"amount":@(410000), @"asset_id":@"1.3.0"},
                //                          @"policy":@[@1, @{@"start_claim":@(lock_ts), @"vesting_seconds":@(0)}]
                //                          };
                //                [[[[BitsharesClientManager sharedBitsharesClientManager] vestingBalanceCreate:op] then:(^id(id data) {
                //                    NSLog(@"%@", data);
                //                    return nil;
                //                })] catch:(^id(id error) {
                //                    NSLog(@"%@", error);
                //                    return nil;
                //                })];
                //                return;
                
                id url = [[ChainObjectManager sharedChainObjectManager] getAppEmbeddedUrl:@"qa"
                                                                                 lang_key:NSLocalizedString(@"appEmbeddedUrlLangKey", @"langkey")];
                vc = [[VCBtsaiWebView alloc] initWithUrl:url];
                vc.title = NSLocalizedString(@"kVcTitleFAQ", @"常见问题");
            }
                break;
            case kVcSetting: //  设置
            {
                switch (indexPath.row) {
                    case kVcSubSettingsEx:
                    {
                        vc = [[VCSetting alloc] init];
                        vc.title = NSLocalizedString(@"kVcTitleSetting", @"设置");
                        //  TODO:3.1 test
                        //                        [[MyPopviewManager sharedMyPopviewManager] showWebviewPaymentDialog:self
                        //                                                                        reserve_secure_text:@"我的账号"
                        //                                                                                   paytitle:@"下注"];
                    }
                        break;
//                    case kVcSubShareLink:
//                    {
//                        id value = [VcUtils genShareLink:YES];
//                        [UIPasteboard generalPasteboard].string = [value copy];
//                        [OrgUtils makeToast:NSLocalizedString(@"kShareLinkCopied", @"分享链接已复制。")];
//                    }
//                        break;
#ifdef DEBUG
                    case kVcSubTestPage:
                    {
                        vc = [[VCTest alloc] init];
                        vc.title = @"测试页面";
                    }
                        break;
#endif  //  DEBUG
                    default:
                        break;
                }
            }
                break;
            default:
                break;
        }
        if (vc){
            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
    }];
}

#pragma mark- UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_faceView){
        NSInteger maxDragHeight = [_faceView getMaxDragHeight];
        
        //  REMARK：这里限定可以下拉到范围
        if (scrollView.contentOffset.y <= -maxDragHeight){
            scrollView.contentOffset = CGPointMake(0, -maxDragHeight);
        }
        
        [_faceView refreshBackgroundOffset:scrollView.contentOffset.y];
    }
}

#pragma mark- switch theme
- (void)switchTheme
{
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    if (_mainTableView){
        [_mainTableView reloadData];
    }
    //  REMARK：处理个人中心导航堆栈里的所有 VC 的主题切换。
    if (self.navigationController){
        NSArray* viewControllers = self.navigationController.viewControllers;
        if (viewControllers && [viewControllers count] > 0){
            if ([viewControllers firstObject] == self){
                for (VCBase* vc in viewControllers) {
                    if (vc == self){
                        continue;
                    }
                    [vc switchTheme];
                }
            }
        }
    }
}

#pragma mark- switch language
- (void)switchLanguage
{
    //  required !!!
    [self refreshBackButtonText];
    
    self.title = NSLocalizedString(@"kTabBarNameMy", @"我的");
    self.tabBarItem.title = NSLocalizedString(@"kTabBarNameMy", @"我的");
    
    if (_mainTableView){
        [_mainTableView reloadData];
    }
    //  REMARK：处理个人中心导航堆栈里的所有 VC 的语言切换。
    if (self.navigationController){
        NSArray* viewControllers = self.navigationController.viewControllers;
        if (viewControllers && [viewControllers count] > 0){
            if ([viewControllers firstObject] == self){
                for (VCBase* vc in viewControllers) {
                    if (vc == self){
                        continue;
                    }
                    [vc switchLanguage];
                }
            }
        }
    }
}

@end
