//
//  VCDebt.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCDebt.h"

#import "VCSearchNetwork.h"
#import "VCImportAccount.h"
#import "VCCallOrderRanking.h"
#import "VCBtsaiWebView.h"
#import "ViewTipsInfoCell.h"
#import "ViewAutoresizeContailerHor.h"

#import "MySlider.h"
#import "TradingPair.h"
#import "WalletManager.h"
#import "OrgUtils.h"

enum
{
    kTailerButtonPayMax = 0,    //  最大还款
    kTailerButtonCollMax,       //  全部抵押
};

enum
{
    kVcFormData = 0,            //  表单数据部分
    kVcFormAction,              //  表单提交行为
    kVcFromTips,                //  提示信息
    
    kVcFormMax
};

enum
{
    kVcSubDebtAvailable = 0,    //  借款金额：标题&余额
    kVcSubDebtValue,            //  借款金额：输入框
    kVcSubCollAvailable,        //  抵押物：标题&余额
    kVcSubCollValue,            //  抵押数：入框
    
    kVcSubRateValue,            //  抵押率
    kVcSubRateSlider,           //  抵押率滑动输入
    
    kVcSubTargetRateValue,      //  目标抵押率
    kVcSubTargetRateSlider,     //  目标抵押率滑动输入
    
    kVcSubFormDataMax
};

@interface VCDebt ()
{
    UILabel*                _currFeedPriceTitle;
    UILabel*                _triggerSettlementPriceTitle;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _rowTypeArray;
    
    BOOL                    _bReadyToUpdateUserData;    //  准备更新用户数据（每次切换 tab 的时候考虑更新）
    BOOL                    _bLoginedOnDisappear;       //  记录界面消失事件触发时帐号是否已经登录。
    
    BOOL                    _bLockDebt;                 //  是否锁定负债字段。
    MyTextField*            _tfDebtValue;
    MyTextField*            _tfCollateralValue;
    
    UITableViewCellBase*    _cellLabelRate;
    UITableViewCellBase*    _cellLabelTargetRate;
    UITableViewCellBase*    _cellDebtAvailable;
    UITableViewCellBase*    _cellCollAvailable;
    MySlider*               _collRateSlider;
    MySlider*               _collTargetRateSlider;
    CurveSlider*            _curve_ratio;
    CurveSlider*            _curve_target_ratio;
    ViewBlockLabel*         _btnOk;
    ViewTipsInfoCell*       _cellTips;
    
    NSMutableDictionary*    _callOrderHash;                 //  各种资产的债仓信息（未登录该Hash为空。）
    TradingPair*            _debtPair;                      //  抵押借款资产和背书资产交易对（借款资产是 BASE、背书资产是 QUOTE）
    NSDecimalNumber*        _nMaintenanceCollateralRatio;   //  抵押维持率（默认1750）
    NSDecimalNumber*        _nCurrFeedPrice;                //  当前喂价（如果查询数据失败，则可能为 nil。）
    BOOL                    _currAssetIsPredictionmarket;   //  当前借款资产是否是预测市场（默认NO）
    NSDecimalNumber*        _nCurrMortgageRate;             //  当前抵押率
    NSDictionary*           _collateralBalance;             //  抵押物可用余额
    
    NSDictionary*           _fee_item;                      //  手续费对象
}

@end

@implementation VCDebt

- (void)dealloc
{
    _cellTips = nil;
    _currFeedPriceTitle = nil;
    _triggerSettlementPriceTitle = nil;
    if (_curve_ratio){
        _curve_ratio.delegate = nil;
        _curve_ratio = nil;
    }
    if (_curve_target_ratio){
        _curve_target_ratio.delegate = nil;
        _curve_target_ratio = nil;
    }
    if (_tfDebtValue){
        _tfDebtValue.delegate = nil;
        _tfDebtValue = nil;
    }
    if (_tfCollateralValue){
        _tfCollateralValue.delegate = nil;
        _tfCollateralValue = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cellLabelRate = nil;
    _cellLabelTargetRate = nil;
    _btnOk = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        _rowTypeArray = [NSMutableArray array];
        _bReadyToUpdateUserData = NO;
        _bLoginedOnDisappear = NO;
        _callOrderHash = nil;
        _fee_item = nil;
        _collateralBalance = nil;
        _debtPair = nil;
        _nCurrFeedPrice = nil;
        _currAssetIsPredictionmarket = NO;
        _nCurrMortgageRate = nil;
        _nMaintenanceCollateralRatio = nil;
    }
    return self;
}

- (void)onResetCLicked
{
    //  重置 - 锁定状态
    [self setNewLockStatus:YES];
    
    //  重置 - 借款数量、抵押数量、抵押率、目标抵押率
    id debt_callorder = [self _getCallOrder];
    if (debt_callorder){
        id n_debt = [NSDecimalNumber decimalNumberWithMantissa:[debt_callorder[@"debt"] unsignedLongLongValue]
                                                      exponent:-_debtPair.basePrecision isNegative:NO];
        id n_coll = [NSDecimalNumber decimalNumberWithMantissa:[debt_callorder[@"collateral"] unsignedLongLongValue]
                                                      exponent:-_debtPair.quotePrecision isNegative:NO];
        _tfDebtValue.text = [OrgUtils formatFloatValue:n_debt usesGroupingSeparator:NO];
        _tfCollateralValue.text = [OrgUtils formatFloatValue:n_coll usesGroupingSeparator:NO];
        
        //  计算抵押率（这里有债仓，debt不为0。）
        if (_nCurrFeedPrice){
            _nCurrMortgageRate = [self _calcCollRate:n_debt coll:n_coll percent_result:NO];
        }else{
            _nCurrMortgageRate = nil;
        }
        
        id target_collateral_ratio = [debt_callorder objectForKey:@"target_collateral_ratio"];
        if (target_collateral_ratio){
            id n_target_collateral_ratio = [NSDecimalNumber decimalNumberWithMantissa:[target_collateral_ratio unsignedLongLongValue]
                                                                             exponent:-3 isNegative:NO];
            [self _refreshUI_target_ratio:n_target_collateral_ratio reset_slider:YES];
        }else{
            [self _refreshUI_target_ratio:nil reset_slider:YES];    //  未设置 target_collateral_ratio
        }
        
        [self _refreshUI_coll_available:n_coll update_textfield:YES];
        [self _refreshUI_debt_available:n_debt update_textfield:YES];
    }else{
        _tfDebtValue.text = @"";
        _tfCollateralValue.text = @"";
        [self _refreshUI_target_ratio:nil reset_slider:YES];        //  默认不设置 target_collateral_ratio
        [self _refreshUI_coll_available:[NSDecimalNumber zero] update_textfield:YES];
        [self _refreshUI_debt_available:[NSDecimalNumber zero] update_textfield:YES];
        id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
        assert(parameters);
        _nCurrMortgageRate = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", parameters[@"collateral_ratio_default"]]];
    }
    
    //  重置 - 你的强平触发价
    [self _refreshUI_SettlementTriggerPrice];
    
    //  重置 - 抵押率
    [self _refreshUI_ratio:YES];
}

- (void)onSelectDebtAssetClicked
{
    NSMutableArray* asset_list = [NSMutableArray array];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    for (id symbol in [[SettingManager sharedSettingManager] getAppMainSmartAssetList]) {
        [asset_list addObject:[chainMgr getAssetBySymbol:symbol]];
    }
    [asset_list addObject:@{@"symbol":NSLocalizedString(@"kVcAssetMgrCellValueSmartBackingAssetCustom", @"自定义"), @"is_custom":@YES}];
    [VcUtils showPicker:self selectAsset:asset_list title:NSLocalizedString(@"kDebtTipSelectDebtAsset", @"请选择要借入的资产")
               callback:^(id selectItem) {
        if ([[selectItem objectForKey:@"is_custom"] boolValue]) {
            VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetSmart callback:^(id asset_info) {
                if (asset_info){
                    [self processSelectNewDebtAsset:asset_info];
                }
            }];
            [self pushViewController:vc
                             vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
                           backtitle:kVcDefaultBackTitleName];
        } else {
            [self processSelectNewDebtAsset:selectItem];
        }
    }];
}

- (void)processSelectNewDebtAsset:(id)newDebtAsset
{
    //  选择的就是当前资产，直接返回。
    if ([[newDebtAsset objectForKey:@"id"] isEqualToString:_debtPair.baseAsset[@"id"]]){
        return;
    }
    
    //  更新缓存
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [chainMgr appendAssetCore:newDebtAsset];
    
    //  查询喂价、查询背书资产信息
    id p1 = [self asyncQueryFeedPrice:newDebtAsset];
    id p2 = [chainMgr queryBackingAsset:newDebtAsset];
    [VcUtils simpleRequest:self request:[WsPromise all:@[p1, p2]] callback:^(id data_array) {
        id feed_data = [data_array objectAtIndex:0];
        id backing_asset = [data_array objectAtIndex:1];
        _debtPair = [[TradingPair alloc] initWithBaseAsset:newDebtAsset quoteAsset:backing_asset];
        [self refreshUI:[self isUserLogined] new_feed_price_data:feed_data];
    }];
}

/**
 *  (private) 辅助生成帮助按钮
 */
- (UIButton*)_genHelpButton:(NSInteger)tag
{
    UIButton* btnTips = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
    CGSize btn_size = btn_image.size;
    [btnTips setBackgroundImage:btn_image forState:UIControlStateNormal];
    btnTips.userInteractionEnabled = YES;
    [btnTips addTarget:self action:@selector(onTipButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnTips.frame = CGRectMake(0, (44 - btn_size.height) / 2, btn_size.width, btn_size.height);
    btnTips.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
    btnTips.tag = tag;
    return btnTips;
}

- (void)_genRowTypeArray
{
    [_rowTypeArray removeAllObjects];
    
    [_rowTypeArray addObject:@(kVcSubDebtAvailable)];
    [_rowTypeArray addObject:@(kVcSubDebtValue)];
    [_rowTypeArray addObject:@(kVcSubCollAvailable)];
    [_rowTypeArray addObject:@(kVcSubCollValue)];
    
    //  预测市场不显示以下字段
    if (!_currAssetIsPredictionmarket) {
        [_rowTypeArray addObject:@(kVcSubRateValue)];
        [_rowTypeArray addObject:@(kVcSubRateSlider)];
        [_rowTypeArray addObject:@(kVcSubTargetRateValue)];
        [_rowTypeArray addObject:@(kVcSubTargetRateSlider)];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self showLeftButton:NSLocalizedString(@"kDebtLableReset", @"重置") action:@selector(onResetCLicked)];
    [self showRightButton:NSLocalizedString(@"kDebtLableSelectAsset", @"选择资产") action:@selector(onSelectDebtAssetClicked)];
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  背景颜色
    self.view.backgroundColor = theme.appBackColor;
    
    //  初始化默认 maintenance_collateral_ratio 值
    id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
    assert(parameters);
    _nMaintenanceCollateralRatio = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", parameters[@"mcr_default"]]];
    
    //  初始化默认抵押率
    _nCurrMortgageRate = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", parameters[@"collateral_ratio_default"]]];
    
    //  初始化默认操作债仓
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id debt_asset_list = [[SettingManager sharedSettingManager] getAppMainSmartAssetList];
    assert(debt_asset_list && [debt_asset_list count] > 0);
    id currDebtAsset = [chainMgr getAssetBySymbol:[debt_asset_list firstObject]];
    //  TODO:fowallet 考虑动态获取背书资产，目前版本只支持 bts作为背书。
    id collateralAsset = [chainMgr getChainObjectByID:chainMgr.grapheneCoreAssetID];
    assert(currDebtAsset);
    assert(collateralAsset);
    _debtPair = [[TradingPair alloc] initWithBaseAsset:currDebtAsset quoteAsset:collateralAsset];
    
    NSString* debtPlaceHolder = NSLocalizedString(@"kDebtTipInputDebtValue", @"请输入借款金额");
    NSString* collateralPlaceHolder = NSLocalizedString(@"kDebtTipInputCollAmount", @"请输入抵押物数量");
    
    CGRect tfrect = [self makeTextFieldRectFull];
    _tfDebtValue = [self createTfWithRect:tfrect keyboard:UIKeyboardTypeDecimalPad placeholder:debtPlaceHolder];
    _tfCollateralValue = [self createTfWithRect:tfrect keyboard:UIKeyboardTypeDecimalPad placeholder:collateralPlaceHolder];
    _tfDebtValue.textColor = theme.textColorMain;
    _tfCollateralValue.textColor = theme.textColorMain;
    
    _tfDebtValue.attributedPlaceholder = [ViewUtils placeholderAttrString:_tfDebtValue.placeholder];
    _tfCollateralValue.attributedPlaceholder = [ViewUtils placeholderAttrString:_tfCollateralValue.placeholder];
    //  绑定输入事件（限制输入）
    [_tfDebtValue addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_tfCollateralValue addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 借款数量尾部辅助按钮
    _tfDebtValue.rightView = [[TailerViewAssetAndButtons alloc] initWithHeight:31
                                                                    asset_name:_debtPair.baseAsset[@"symbol"]
                                                                  button_names:@[NSLocalizedString(@"kDebtLablePayMaxDebt", @"还款")]
                                                                        target:self
                                                                        action:@selector(onDebtTailerButtonClicked:)];
    
    _tfDebtValue.rightViewMode = UITextFieldViewModeAlways;
    //  UI - 抵押物数量尾部辅助按钮
    _tfCollateralValue.rightView = [[TailerViewAssetAndButtons alloc] initWithHeight:31
                                                                          asset_name:_debtPair.quoteAsset[@"symbol"]
                                                                        button_names:@[NSLocalizedString(@"kDebtLableUseMax", @"全部")]
                                                                              target:self
                                                                              action:@selector(onCollTailerButtonClicked:)];
    _tfCollateralValue.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 输入框标题
    _tfCollateralValue.showBottomLine = YES;
    _tfDebtValue.showBottomLine = YES;
    
    //  UI - 顶部喂价和强平触发价格 REMARK：这两个标签使用等宽字体
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    _currFeedPriceTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, screenRect.size.width, 32)];
    _currFeedPriceTitle.lineBreakMode = NSLineBreakByWordWrapping;
    _currFeedPriceTitle.numberOfLines = 1;
    _currFeedPriceTitle.backgroundColor = [UIColor clearColor];
    _currFeedPriceTitle.textColor = theme.textColorMain;
    _currFeedPriceTitle.textAlignment = NSTextAlignmentCenter;
    _currFeedPriceTitle.font = [UIFont fontWithName:@"Helvetica" size:15.0f];
    _currFeedPriceTitle.text = [NSString stringWithFormat:@"%@ --%@/%@",
                                NSLocalizedString(@"kDebtLableFeedPrice", @"当前喂价"), _debtPair.baseAsset[@"symbol"], _debtPair.quoteAsset[@"symbol"]];
    [self.view addSubview:_currFeedPriceTitle];
    
    _triggerSettlementPriceTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, screenRect.size.width, 66)];
    _triggerSettlementPriceTitle.lineBreakMode = NSLineBreakByWordWrapping;
    _triggerSettlementPriceTitle.numberOfLines = 1;
    _triggerSettlementPriceTitle.backgroundColor = [UIColor clearColor];
    _triggerSettlementPriceTitle.textColor = theme.textColorMain;
    _triggerSettlementPriceTitle.textAlignment = NSTextAlignmentCenter;
    _triggerSettlementPriceTitle.font = [UIFont fontWithName:@"Helvetica" size:15.0f];
    _triggerSettlementPriceTitle.text = [NSString stringWithFormat:@"%@ --%@/%@",
                                         NSLocalizedString(@"kDebtLableCallPrice", @"强平价格"), _debtPair.baseAsset[@"symbol"], _debtPair.quoteAsset[@"symbol"]];
    [self.view addSubview:_triggerSettlementPriceTitle];
    
    //  UI - 喂价帮助按钮
    UIButton* btnTipsFeed = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
    CGSize btn_size = btn_image.size;
    [btnTipsFeed setBackgroundImage:btn_image forState:UIControlStateNormal];
    btnTipsFeed.userInteractionEnabled = YES;
    btnTipsFeed.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [btnTipsFeed addTarget:self action:@selector(onTipFeedPriceButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnTipsFeed.frame = CGRectMake(screenRect.size.width - btn_size.width - 15, (50 - btn_size.height) / 2, btn_size.width, btn_size.height);
    btnTipsFeed.tintColor = theme.textColorHighlight;
    [self.view addSubview:btnTipsFeed];
    
    CGFloat offset = 32 + 56;
    
    //  UI-分隔线
    CGFloat fSepLineHeight = 0.5f;
    UIView* tmpSepLine = [[UIView alloc] initWithFrame:CGRectMake(0, offset-fSepLineHeight, screenRect.size.width, fSepLineHeight)];
    tmpSepLine.backgroundColor = theme.textColorGray;
    [self.view addSubview:tmpSepLine];
    
    //  UI - 下面主表格区域
    [self _genRowTypeArray];
    CGRect rect = CGRectMake(0, offset, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - [self heightForTabBar] - offset - [self heightForBottomSafeArea]);
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.hideAllLines = YES;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  UI - 抵押率
    _cellLabelRate = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellLabelRate.backgroundColor = [UIColor clearColor];
    _cellLabelRate.accessoryType = UITableViewCellAccessoryNone;
    _cellLabelRate.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellLabelRate.textLabel.textColor = theme.textColorMain;
    _cellLabelRate.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellLabelRate.hideBottomLine = YES;
    _cellLabelRate.hideTopLine = YES;
    _cellLabelRate.accessoryView = [self _genHelpButton:kVcSubRateValue];
    
    //  UI - 目标抵押率
    _cellLabelTargetRate = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellLabelTargetRate.backgroundColor = [UIColor clearColor];
    _cellLabelTargetRate.accessoryType = UITableViewCellAccessoryNone;
    _cellLabelTargetRate.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellLabelTargetRate.textLabel.textColor = theme.textColorMain;
    _cellLabelTargetRate.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellLabelTargetRate.hideBottomLine = YES;
    _cellLabelTargetRate.hideTopLine = YES;
    _cellLabelTargetRate.accessoryView = [self _genHelpButton:kVcSubTargetRateValue];
    
    //  UI - 提示信息
    _cellTips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kDebtWarmTips", @"【温馨提示】\n1、当喂价下降到强平触发价时，系统将会自动出售您的抵押资产用于归还借款。请注意调整抵押率控制风险。\n2、当锁定借款金额时，抵押率会随抵押物数量变化而变化。\n3、当锁定抵押率时，借款金额会随抵押物数量变化而变化。")];
    _cellTips.hideBottomLine = YES;
    _cellTips.hideTopLine = YES;
    _cellTips.backgroundColor = [UIColor clearColor];
    
    if ([self isUserLogined]){
        _btnOk = [self createCellLableButton:NSLocalizedString(@"kDebtLableUpdatePosition", @"调整债仓")];
        [self genCallOrderHash:YES];
    }else{
        _btnOk = [self createCellLableButton:NSLocalizedString(@"kDebtLableLogin", @"登录")];
        [self genCallOrderHash:NO];
    }
    
    //  UI - 借贷资产可用余额
    _cellDebtAvailable = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellDebtAvailable.backgroundColor = [UIColor clearColor];
    _cellDebtAvailable.hideBottomLine = YES;
    _cellDebtAvailable.accessoryType = UITableViewCellAccessoryNone;
    _cellDebtAvailable.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellDebtAvailable.textLabel.text = NSLocalizedString(@"kDebtLabelCellTitleDebtValue", @"借款金额");
    if (_callOrderHash){
        _cellDebtAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %@", NSLocalizedString(@"kDebtLableAvailable", @"可用余额"), [OrgUtils formatFloatValue:[self _getDebtBalance]], _debtPair.baseAsset[@"symbol"]];
    }else{
        _cellDebtAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ -- %@", NSLocalizedString(@"kDebtLableAvailable", @"可用余额"), _debtPair.baseAsset[@"symbol"]];
    }
    _cellDebtAvailable.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellDebtAvailable.textLabel.textColor = theme.textColorMain;
    _cellDebtAvailable.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
    
    //  UI - 抵押物可用余额
    _cellCollAvailable = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellCollAvailable.backgroundColor = [UIColor clearColor];
    _cellCollAvailable.hideBottomLine = YES;
    _cellCollAvailable.accessoryType = UITableViewCellAccessoryNone;
    _cellCollAvailable.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellCollAvailable.textLabel.text = NSLocalizedString(@"kDebtLabelCellTitleCollAmount", @"抵押物");
    if (_collateralBalance){
        id n = [NSDecimalNumber decimalNumberWithMantissa:[_collateralBalance[@"amount"] unsignedLongLongValue]
                                                 exponent:-_debtPair.quotePrecision
                                               isNegative:NO];
        _cellCollAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %@", NSLocalizedString(@"kDebtLableAvailable", @"可用余额"), [OrgUtils formatFloatValue:n], _debtPair.quoteAsset[@"symbol"]];
    }else{
        _cellCollAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ -- %@", NSLocalizedString(@"kDebtLableAvailable", @"可用余额"), _debtPair.quoteAsset[@"symbol"]];
    }
    _cellCollAvailable.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellCollAvailable.textLabel.textColor = theme.textColorMain;
    _cellCollAvailable.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
    
    //  UI - 抵押率滑动条
    _collRateSlider = [[MySlider alloc] init];
    _collRateSlider.tintColor = theme.textColorHighlight;
    _collRateSlider.tag = kVcSubRateSlider;
    _curve_ratio = [[CurveSlider alloc] initWithSlider:_collRateSlider max:400.0f mapping_min:0.0f mapping_max:6.0f];
    _curve_ratio.delegate = self;
    //  初始化抵押率文字和滑动条
    [self _refreshUI_ratio:YES];
    
    //  UI - 目标抵押率滑动条
    _collTargetRateSlider = [[MySlider alloc] init];
    _collTargetRateSlider.tintColor = theme.textColorHighlight;
    _collTargetRateSlider.tag = kVcSubTargetRateSlider;
    _curve_target_ratio = [[CurveSlider alloc] initWithSlider:_collTargetRateSlider max:400.0f mapping_min:0.0f mapping_max:4.0f];
    _curve_target_ratio.delegate = self;
    //  初始化属性
    [self _refreshUI_target_ratio:nil reset_slider:YES];
    
    //  初始化 - 锁定状态
    [self setNewLockStatus:YES];
    UITapGestureRecognizer* pDebtIconGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onLockClicked)];
    pDebtIconGesture.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    _cellDebtAvailable.imageView.userInteractionEnabled = YES;
    [_cellDebtAvailable.imageView addGestureRecognizer:pDebtIconGesture];
    UITapGestureRecognizer* pRateIconGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onLockClicked)];
    pRateIconGesture.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    _cellLabelRate.imageView.userInteractionEnabled = YES;
    [_cellLabelRate.imageView addGestureRecognizer:pRateIconGesture];
    
    //  事件 - 空白处点击
    [VcUtils addSpaceTapHandler:self body:^(id weak_self, UITapGestureRecognizer *tap) {
        [weak_self resignAllFirstResponder];
    }];
}

- (void)resignAllFirstResponder
{
    [self.view endEditing:YES];
    [_tfDebtValue safeResignFirstResponder];
    [_tfCollateralValue safeResignFirstResponder];
}

- (void)onTabBarControllerSwitched
{
    _bReadyToUpdateUserData = YES;
}

/**
 *  (private) 辅助方法 - 判断用户是否已经登录
 */
- (BOOL)isUserLogined
{
    return [[WalletManager sharedWalletManager] isWalletExist];
}

/**
 *  (private) 初始化债仓信息
 */
- (void)genCallOrderHash:(BOOL)bLogined
{
    if (bLogined){
        id wallet_account_info = [[WalletManager sharedWalletManager] getWalletAccountInfo];
        id account_id = [[wallet_account_info objectForKey:@"account"] objectForKey:@"id"];
        assert(account_id);
        
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        
        //        id debt_asset_list = [chainMgr getMainSmartAssetList];
        //        assert(debt_asset_list);
        
        //  REMARK：如果没执行 get_full_accounts 请求，则内存缓存不存在，则默认从登录时的帐号信息里获取。
        id full_account_data = [chainMgr getFullAccountDataFromCache:account_id];
        if (!full_account_data){
            full_account_data = wallet_account_info;
        }
        
        //  1、初始化余额Hash(原来的是Array)
        id balances_hash = [NSMutableDictionary dictionary];
        for (id balance_object in [full_account_data objectForKey:@"balances"]) {
            id asset_type = [balance_object objectForKey:@"asset_type"];
            id balance = [balance_object objectForKey:@"balance"];
            [balances_hash setObject:@{@"asset_id":asset_type, @"amount":balance} forKey:asset_type];
        }
        id balances_list = [balances_hash allValues];
        
        //  2、计算手续费对象（更新手续费资产的可用余额，即减去手续费需要的amount）
        _fee_item = [chainMgr estimateFeeObject:ebo_call_order_update balances:balances_list];
        if (_fee_item){
            id fee_asset_id = _fee_item[@"fee_asset_id"];
            id fee_balance = [balances_hash objectForKey:fee_asset_id];
            if (fee_balance){
                unsigned long long fee = [[_fee_item objectForKey:@"amount"] unsignedLongLongValue];
                unsigned long long old = [[fee_balance objectForKey:@"amount"] unsignedLongLongValue];
                id new_balance;
                if (old >= fee){
                    new_balance = @{@"asset_id":fee_asset_id, @"amount":@(old - fee)};
                }else{
                    new_balance = @{@"asset_id":fee_asset_id, @"amount":@0};
                }
                [balances_hash setObject:new_balance forKey:fee_asset_id];
            }
        }
        
        //  3、获取抵押物（BTS）的余额信息
        _collateralBalance = [balances_hash objectForKey:_debtPair.quoteId];
        if (!_collateralBalance){
            _collateralBalance = @{@"asset_id":_debtPair.quoteId, @"amount":@0};
        }
        
        //  4、获取当前持有的债仓
        id call_orders_hash = [NSMutableDictionary dictionary];
        NSArray* call_orders = [full_account_data objectForKey:@"call_orders"];
        if (call_orders){
            for (id call_order in call_orders) {
                [call_orders_hash setObject:call_order forKey:[call_order objectForKey:@"call_price"][@"quote"][@"asset_id"]];
            }
        }
        
        //  5、债仓和余额关联
        _callOrderHash = [NSMutableDictionary dictionary];
        id debt_symbol = _debtPair.baseAsset[@"symbol"];
        id debt_asset = _debtPair.baseAsset;//[chainMgr getAssetBySymbol:debt_symbol];
        id oid = [debt_asset objectForKey:@"id"];
        id balance = [balances_hash objectForKey:oid];
        if (!balance){
            //  默认值
            balance = @{@"asset_id":oid, @"amount":@0};
        }
        //  callorder可能不存在
        id info;
        id callorder = [call_orders_hash objectForKey:oid];
        if (callorder){
            info = @{@"balance":balance, @"callorder":callorder, @"debt_asset":debt_asset};
        }else{
            info = @{@"balance":balance, @"debt_asset":debt_asset};
        }
        //  保存到Hash
        [_callOrderHash setObject:info forKey:debt_symbol];
        [_callOrderHash setObject:info forKey:oid];
    }else{
        if (_callOrderHash){
            [_callOrderHash removeAllObjects];
        }
        _callOrderHash = nil;
        _collateralBalance = nil;
        _fee_item = nil;
    }
}

/**
 *  (private) 查询喂价信息
 */
- (WsPromise*)asyncQueryFeedPrice:(id)debtAsset
{
    if (!debtAsset){
        debtAsset = _debtPair.baseAsset;
    }
    assert(debtAsset);
    NSString* bitasset_data_id = debtAsset[@"bitasset_data_id"];
    assert(bitasset_data_id && ![bitasset_data_id isEqualToString:@""]);
    return [[[ChainObjectManager sharedChainObjectManager] queryAllGrapheneObjectsSkipCache:@[bitasset_data_id]] then:^id(id result_hash) {
        return [result_hash objectForKey:bitasset_data_id];
    }];
}

/**
 *  (private) 获取当前操作资产的债仓信息，债仓不存在则返回 nil。
 */
- (id)_getCallOrder
{
    if (_callOrderHash){
        id debt = [_callOrderHash objectForKey:_debtPair.baseAsset[@"symbol"]];
        assert(debt);
        return [debt objectForKey:@"callorder"];
    }else{
        return nil;
    }
}

/**
 *  (private) 获取总抵押物数量（已抵押的 + 可用的），未登录时候返回 0。
 */
- (id)_getTotalCollateralNumber
{
    NSDecimalNumber* n_coll = [NSDecimalNumber zero];
    NSDecimalNumber* n_balance = [NSDecimalNumber zero];
    id debt_callorder = [self _getCallOrder];
    if (debt_callorder){
        n_coll = [NSDecimalNumber decimalNumberWithMantissa:[debt_callorder[@"collateral"] unsignedLongLongValue]
                                                   exponent:-_debtPair.quotePrecision isNegative:NO];
    }
    if (_collateralBalance){
        n_balance = [NSDecimalNumber decimalNumberWithMantissa:[_collateralBalance[@"amount"] unsignedLongLongValue]
                                                      exponent:-_debtPair.quotePrecision
                                                    isNegative:NO];
    }
    return [n_coll decimalNumberByAdding:n_balance];
}

/**
 *  (private) 获取当前借贷资产可用余额
 */
- (id)_getDebtBalance
{
    if (_callOrderHash){
        id debt = [_callOrderHash objectForKey:_debtPair.baseAsset[@"symbol"]];
        assert(debt);
        id debt_balance = [debt objectForKey:@"balance"];
        id n = [NSDecimalNumber decimalNumberWithMantissa:[debt_balance[@"amount"] unsignedLongLongValue]
                                                 exponent:-_debtPair.basePrecision
                                               isNegative:NO];
        return n;
    }else{
        return [NSDecimalNumber zero];
    }
}

/**
 *  计算抵押率       公式：抵押率 = 抵押物数量 * 喂价 / 负债
 */
- (id)_calcCollRate:(NSDecimalNumber*)n_debt coll:(NSDecimalNumber*)n_coll percent_result:(BOOL)percent_result
{
    //  REMARK：预测市场，抵押物数量和借款数量必须一致，不需要喂价。
    if (_currAssetIsPredictionmarket) {
        return [NSDecimalNumber one];
    }
    assert(_nCurrFeedPrice);
    assert([n_debt compare:[NSDecimalNumber zero]] > 0);
    NSDecimalNumberHandler* ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                 scale:4
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
    NSDecimalNumber* n = [n_coll decimalNumberByMultiplyingBy:_nCurrFeedPrice];
    n = [n decimalNumberByDividingBy:n_debt withBehavior:ceilHandler];
    if (percent_result){
        //  返回百分比结果（精度2位）
        return [n decimalNumberByMultiplyingByPowerOf10:2 withBehavior:ceilHandler];
    }else{
        //  返回4位精度小数
        return n;
    }
}

/**
 *  计算可借款数量  公式：借款 = 抵押物数量 * 喂价 / 抵押率
 */
- (id)_calcDebtNumber:(NSDecimalNumber*)n_coll rate:(NSDecimalNumber*)rate
{
    //  REMARK：预测市场，抵押物数量和借款数量必须一致，不需要喂价。
    if (_currAssetIsPredictionmarket) {
        return n_coll;
    }
    assert(rate);
    assert(_nCurrFeedPrice);
    //  抵押率为0，则债务为0，不随抵押物变化。
    id n_zero = [NSDecimalNumber zero];
    if ([rate compare:n_zero] <= 0) {
        return n_zero;
    }
    NSDecimalNumberHandler* downHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                                 scale:_debtPair.basePrecision
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
    
    NSDecimalNumber* n = [n_coll decimalNumberByMultiplyingBy:_nCurrFeedPrice];
    return [n decimalNumberByDividingBy:rate withBehavior:downHandler];
}

/**
 *  计算抵押物数量  公式：抵押物数量 = 抵押率 * 负债 / 喂价
 */
- (id)_calcCollNumber:(NSDecimalNumber*)n_debt rate:(NSDecimalNumber*)rate
{
    //  REMARK：预测市场，抵押物数量和借款数量必须一致，不需要喂价。
    if (_currAssetIsPredictionmarket) {
        return n_debt;
    }
    assert(rate);
    assert(_nCurrFeedPrice);
    assert([_nCurrFeedPrice compare:[NSDecimalNumber zero]] != NSOrderedSame);
    NSDecimalNumberHandler* ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                 scale:_debtPair.quotePrecision
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
    NSDecimalNumber* n = [n_debt decimalNumberByMultiplyingBy:rate];
    return [n decimalNumberByDividingBy:_nCurrFeedPrice withBehavior:ceilHandler];
}

/**
 *  (private) 刷新用户数据
 */
- (void)refreshUserData
{
    BOOL bLogined = [self isUserLogined];
    if (_bReadyToUpdateUserData){
        //  切换Tab，刷新数据。（喂价信息、用户信息-登录时）
        _bReadyToUpdateUserData = NO;
        id p1 = [self asyncQueryFeedPrice:nil];
        id p2 = [NSNull null];
        if (bLogined){
            id account_id = [[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"id"];
            p2 = [[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_id];
        }
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[WsPromise all:@[p1, p2]] then:(^id(id data_array) {
            [self hideBlockView];
            //  刷新UI
            [self refreshUI:bLogined new_feed_price_data:data_array[0]];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            return nil;
        })];
    }else{
        //  刷新UI
        [self refreshUI:bLogined new_feed_price_data:nil];
    }
}

/**
 *  (private) 刷新界面 - 用户登录 or 用户数据更新了 or 用户选择了新的借款资产。
 */
- (void)refreshUI:(BOOL)bLogined new_feed_price_data:(id)new_feed_price_data
{
    //  更新喂价 和 MCR。
    if (new_feed_price_data){
        _nCurrFeedPrice = [_debtPair calcShowFeedInfo:@[new_feed_price_data]];
        _currAssetIsPredictionmarket = [[new_feed_price_data objectForKey:@"is_prediction_market"] boolValue];
        id mcr = [[new_feed_price_data objectForKey:@"current_feed"] objectForKey:@"maintenance_collateral_ratio"];
        _nMaintenanceCollateralRatio = [NSDecimalNumber decimalNumberWithMantissa:[mcr unsignedLongLongValue] exponent:-3 isNegative:NO];
    }
    
    //  生成新的债仓信息
    [self genCallOrderHash:bLogined];
    
    //  更新UI
    TailerViewAssetAndButtons* debtTailer = (TailerViewAssetAndButtons*)_tfDebtValue.rightView;
    [debtTailer drawAssetName:_debtPair.baseAsset[@"symbol"]];
    TailerViewAssetAndButtons* collTailer = (TailerViewAssetAndButtons*)_tfCollateralValue.rightView;
    [collTailer drawAssetName:_debtPair.quoteAsset[@"symbol"]];
    
    //  UI - 按钮
    if (bLogined){
        _btnOk.text = NSLocalizedString(@"kDebtLableUpdatePosition", @"调整债仓");
    }else{
        _btnOk.text = NSLocalizedString(@"kDebtLableLogin", @"登录");
    }
    
    //  UI - 喂价
    if (!_currAssetIsPredictionmarket && _nCurrFeedPrice){
        _currFeedPriceTitle.text = [NSString stringWithFormat:@"%@ %@%@/%@",
                                    NSLocalizedString(@"kDebtLableFeedPrice", @"当前喂价"), [OrgUtils formatFloatValue:_nCurrFeedPrice], _debtPair.baseAsset[@"symbol"], _debtPair.quoteAsset[@"symbol"]];
    }else{
        _currFeedPriceTitle.text = [NSString stringWithFormat:@"%@ --%@/%@",
                                    NSLocalizedString(@"kDebtLableFeedPrice", @"当前喂价"), _debtPair.baseAsset[@"symbol"], _debtPair.quoteAsset[@"symbol"]];
    }
    
    //  UI - 你的强平触发价
    [self onResetCLicked];
    
    //  UI - 提示信息
    if (_currAssetIsPredictionmarket) {
        [_cellTips updateLabelText:NSLocalizedString(@"kDebtWarmTipsForPM", @"【温馨提示】\n当前资产为预测市场资产。借款金额和抵押物数量恒定为 1:1。")];
    } else {
        [_cellTips updateLabelText:NSLocalizedString(@"kDebtWarmTips", @"【温馨提示】\n1、当喂价下降到强平触发价时，系统将会自动出售您的抵押资产用于归还借款。请注意调整抵押率控制风险。\n2、当锁定借款金额时，抵押率会随抵押物数量变化而变化。\n3、当锁定抵押率时，借款金额会随抵押物数量变化而变化。")];
    }
    
    //  UI - 列表
    [self _genRowTypeArray];
    [_mainTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshUserData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _bLoginedOnDisappear = [self isUserLogined];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (!_currAssetIsPredictionmarket && textField == _tfCollateralValue) {
        NSDecimalNumber* n_debt = [OrgUtils auxGetStringDecimalNumberValue:_tfDebtValue.text];
        if ([n_debt compare:[NSDecimalNumber zero]] <= 0) {
            [self resignAllFirstResponder];
            [OrgUtils makeToast:NSLocalizedString(@"kDebtTipPleaseInputDebtValueFirst", @"请先输入借款金额。")];
            return NO;
        }
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != _tfDebtValue && textField != _tfCollateralValue){
        return YES;
    }
    
    id asset = textField == _tfDebtValue ? _debtPair.baseAsset : _debtPair.quoteAsset;
    return [OrgUtils isValidAmountOrPriceInput:textField.text range:range new_string:string
                                     precision:[[asset objectForKey:@"precision"] integerValue]];
}

/**
 *  (private) 输入框值发生变化
 */
- (void)onTextFieldDidChange:(UITextField*)textField
{
    if (textField != _tfDebtValue && textField != _tfCollateralValue){
        return;
    }
    
    //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
    [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
    
    if (textField == _tfDebtValue){
        [self onTfDebtChanged:textField];
    }else if (textField == _tfCollateralValue){
        [self onTfCollChanged:textField affect_mortgage_rate_changed:_currAssetIsPredictionmarket ? NO : _bLockDebt];
    }else{
        assert(false);
    }
}

/*
 *  (private) 事件 - 锁 or 解锁按钮点击
 */
- (void)onLockClicked
{
    [self setNewLockStatus:!_bLockDebt];
}

- (void)setNewLockStatus:(BOOL)bLockDebt
{
    //  预测市场不用锁
    if (_currAssetIsPredictionmarket) {
        _cellDebtAvailable.imageView.image = nil;
        _cellLabelRate.imageView.image = nil;
        return;
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    _bLockDebt = bLockDebt;
    
    if (_bLockDebt) {
        _cellDebtAvailable.imageView.image = [UIImage templateImageNamed:@"iconLocked"];
        _cellDebtAvailable.imageView.tintColor = theme.textColorNormal;
        
        _cellLabelRate.imageView.image  = [UIImage templateImageNamed:@"iconUnlocked"];
        _cellLabelRate.imageView.tintColor = theme.textColorHighlight;
    } else {
        _cellDebtAvailable.imageView.image = [UIImage templateImageNamed:@"iconUnlocked"];
        _cellDebtAvailable.imageView.tintColor = theme.textColorHighlight;
        
        _cellLabelRate.imageView.image  = [UIImage templateImageNamed:@"iconLocked"];
        _cellLabelRate.imageView.tintColor = theme.textColorNormal;
    }
}

/*
 *  事件 - 还款按钮点击
 */
- (void)onDebtTailerButtonClicked:(UIButton*)sender
{
    NSDecimalNumber* new_debt = nil;
    //  计算执行最大还款之后，剩余的负债信息。
    id debt_callorder = [self _getCallOrder];
    if (debt_callorder){
        id n_curr_debt = [NSDecimalNumber decimalNumberWithMantissa:[debt_callorder[@"debt"] unsignedLongLongValue]
                                                           exponent:-_debtPair.basePrecision isNegative:NO];
        id balance = [self _getDebtBalance];
        //  balance < n_curr_debt
        if ([balance compare:n_curr_debt] == NSOrderedAscending){
            new_debt = [n_curr_debt decimalNumberBySubtracting:balance];
        }else{
            new_debt = [NSDecimalNumber zero];
        }
    }else{
        new_debt = [NSDecimalNumber zero];
    }
    //  赋值
    assert(new_debt);
    if ([new_debt compare:[NSDecimalNumber zero]] == NSOrderedSame){
        _tfDebtValue.text = @"";
    }else{
        _tfDebtValue.text = [OrgUtils formatFloatValue:new_debt usesGroupingSeparator:NO];
    }
    [self onTfDebtChanged:_tfDebtValue];
}

/*
 *  事件 - 全部按钮点击
 */
- (void)onCollTailerButtonClicked:(UIButton*)sender
{
    if (!_currAssetIsPredictionmarket) {
        if (_bLockDebt) {
            NSDecimalNumber* n_debt = [OrgUtils auxGetStringDecimalNumberValue:_tfDebtValue.text];
            if ([n_debt compare:[NSDecimalNumber zero]] <= 0) {
                [OrgUtils makeToast:NSLocalizedString(@"kDebtTipPleaseInputDebtValueFirst", @"请先输入借款金额。")];
                return;
            }
        } else {
            if (!_nCurrMortgageRate || [_nCurrMortgageRate compare:[NSDecimalNumber zero]] <= 0) {
                [OrgUtils makeToast:NSLocalizedString(@"kDebtTipPleaseAdjustRatioFirst", @"请先调整抵押率。")];
                return;
            }
        }
    }
    id n_total = [self _getTotalCollateralNumber];
    if ([n_total compare:[NSDecimalNumber zero]] == NSOrderedSame){
        _tfCollateralValue.text = @"";
    }else{
        _tfCollateralValue.text = [OrgUtils formatFloatValue:n_total usesGroupingSeparator:NO];
    }
    [self onTfCollChanged:_tfCollateralValue affect_mortgage_rate_changed:_currAssetIsPredictionmarket ? NO : _bLockDebt];
}

/**
 *  (private) 帮助按钮点击
 */
- (void)onTipFeedPriceButtonClicked:(UIButton*)sender
{
    [self gotoQaView:@"qa_feed_settlement"
               title:NSLocalizedString(@"kDebtTipTitleFeedAndCallPrice", @"喂价和强平触发价")];
}
- (void)onTipButtonClicked:(UIButton*)sender
{
    switch (sender.tag) {
        case kVcSubRateValue:
        {
            [self gotoQaView:@"qa_ratio"
                       title:NSLocalizedString(@"kDebtTipTitleWhatIsRatio", @"什么是抵押率？")];
        }
            break;
        case kVcSubTargetRateValue:
        {
            [self gotoQaView:@"qa_target_ratio"
                       title:NSLocalizedString(@"kDebtTipTitleWhatIsTargetRatio", @"什么是目标抵押率？")];
        }
            break;
        default:
            break;
    }
}

/**
 *  (private) 输入框值变化 - 借款数量
 */
- (void)onTfDebtChanged:(UITextField*)textField
{
    if (!_currAssetIsPredictionmarket && !_nCurrFeedPrice){
        return;
    }
    if (!textField){
        textField = _tfDebtValue;
    }
    NSDecimalNumber* n_debt = [OrgUtils auxGetStringDecimalNumberValue:textField.text];
    id n_coll = [self _calcCollNumber:n_debt rate:_nCurrMortgageRate];
    [self _refreshUI_debt_available:n_debt update_textfield:NO];
    [self _refreshUI_coll_available:n_coll update_textfield:YES];
    [self _refreshUI_SettlementTriggerPrice];
}
/**
 *  (private) 输入框值变化 - 抵押物数量
 */
- (void)onTfCollChanged:(UITextField*)textField affect_mortgage_rate_changed:(BOOL)affect_mortgage_rate_changed
{
    if (!_currAssetIsPredictionmarket && !_nCurrFeedPrice){
        return;
    }
    if (!textField){
        textField = _tfCollateralValue;
    }
    NSDecimalNumber* n_coll = [OrgUtils auxGetStringDecimalNumberValue:textField.text];
    if (affect_mortgage_rate_changed) {
        //  抵押物变化 - 影响抵押率变化（负债不变）
        //  这里手动输入抵押物or点击全部按钮导致变化，都已经确保了debt不能为0。
        NSDecimalNumber* n_debt = [OrgUtils auxGetStringDecimalNumberValue:_tfDebtValue.text];
        if ([n_debt compare:[NSDecimalNumber zero]] <= 0) {
            return;
        }
        _nCurrMortgageRate = [self _calcCollRate:n_debt coll:n_coll percent_result:NO];
        [self _refreshUI_coll_available:n_coll update_textfield:NO];
        [self _refreshUI_debt_available:n_debt update_textfield:NO];
        [self _refreshUI_ratio:YES];
        [self _refreshUI_SettlementTriggerPrice];
    } else {
        //  抵押物变化 - 影响债务变化（抵押率不变）
        id n_debt = [self _calcDebtNumber:n_coll rate:_nCurrMortgageRate];
        [self _refreshUI_coll_available:n_coll update_textfield:NO];
        [self _refreshUI_debt_available:n_debt update_textfield:YES];
        [self _refreshUI_SettlementTriggerPrice];
    }
}

/**
 *  (private) 滑动条值变化 - 抵押率数量
 */
- (void)onValueChanged:(CurveSlider*)curve_slider slider:(UISlider*)slider value:(CGFloat)value
{
    switch (slider.tag) {
        case kVcSubRateSlider:
        {
            //  抵押率滑动条拖动
            _nCurrMortgageRate = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%.2f", value]];
            [self _refreshUI_ratio:NO];
            if (!_nCurrFeedPrice){
                return;
            }
            assert(_nCurrMortgageRate);
            NSDecimalNumber* n_debt = [OrgUtils auxGetStringDecimalNumberValue:_tfDebtValue.text];
            id n_coll = [self _calcCollNumber:n_debt rate:_nCurrMortgageRate];
            [self _refreshUI_coll_available:n_coll update_textfield:YES];
            [self _refreshUI_SettlementTriggerPrice];
        }
            break;
        case kVcSubTargetRateSlider:
        {
            //  目标抵押率滑动条拖动
            id n = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%.2f", value]];
            [self _refreshUI_target_ratio:n reset_slider:NO];
        }
            break;
        default:
            break;
    }
}

/**
 *  (private) 刷新UI - 抵押物可用余额
 */
- (void)_refreshUI_coll_available:(NSDecimalNumber*)new_tf_value update_textfield:(BOOL)update_textfield
{
    assert(new_tf_value);
    if (update_textfield){
        if ([new_tf_value compare:[NSDecimalNumber zero]] == NSOrderedSame){
            _tfCollateralValue.text = @"";
        }else{
            _tfCollateralValue.text = [OrgUtils formatFloatValue:new_tf_value usesGroupingSeparator:NO];
        }
    }
    
    NSDecimalNumber* n_total = [self _getTotalCollateralNumber];
    id n_available = [n_total decimalNumberBySubtracting:new_tf_value];
    
    _cellCollAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %@",
                                               NSLocalizedString(@"kDebtLableAvailable", @"可用余额"),
                                               [OrgUtils formatFloatValue:n_available], _debtPair.quoteAsset[@"symbol"]];
    
    //  变化量
    //    NSDecimalNumber* n_balance = [NSDecimalNumber zero];
    //    if (_collateralBalance){
    //        n_balance = [NSDecimalNumber decimalNumberWithMantissa:[_collateralBalance[@"amount"] unsignedLongLongValue]
    //                                                      exponent:-_debtPair.quotePrecision
    //                                                    isNegative:NO];
    //    }
    //    id n_diff = [n_available decimalNumberBySubtracting:n_balance];
    //    NSComparisonResult result = [n_diff compare:[NSDecimalNumber zero]];
    //    if (result != NSOrderedSame){
    //        //  n_diff < 0
    //        if (result == NSOrderedAscending){
    //            _cellCollAvailable.detailTextLabel.text = [OrgUtils formatFloatValue:n_diff];
    //            _cellCollAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].sellColor;
    //        }else{
    //            _cellCollAvailable.detailTextLabel.text = [NSString stringWithFormat:@"+%@", [OrgUtils formatFloatValue:n_diff]];
    //            _cellCollAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
    //        }
    //    }else{
    //        _cellCollAvailable.detailTextLabel.text = @"";
    //    }
    
    //  n_available < 0
    if ([n_available compare:[NSDecimalNumber zero]] == NSOrderedAscending){
        _cellCollAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].tintColor;
    }else{
        _cellCollAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    }
}
/**
 *  (private) 刷新UI - 借贷数量可用余额
 */
- (void)_refreshUI_debt_available:(NSDecimalNumber*)new_tf_value update_textfield:(BOOL)update_textfield
{
    assert(new_tf_value);
    if (update_textfield){
        if ([new_tf_value compare:[NSDecimalNumber zero]] == NSOrderedSame){
            _tfDebtValue.text = @"";
        }else{
            _tfDebtValue.text = [OrgUtils formatFloatValue:new_tf_value usesGroupingSeparator:NO];
        }
    }
    
    NSDecimalNumber* n_curr_debt = [NSDecimalNumber zero];
    id debt_callorder = [self _getCallOrder];
    if (debt_callorder){
        n_curr_debt = [NSDecimalNumber decimalNumberWithMantissa:[debt_callorder[@"debt"] unsignedLongLongValue]
                                                        exponent:-_debtPair.basePrecision isNegative:NO];
    }
    //  新增借贷（可以为负。）
    id n_add_debt = [new_tf_value decimalNumberBySubtracting:n_curr_debt];
    
    //  可用余额
    id n_available = [[self _getDebtBalance] decimalNumberByAdding:n_add_debt];
    _cellDebtAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %@",
                                               NSLocalizedString(@"kDebtLableAvailable", @"可用余额"), [OrgUtils formatFloatValue:n_available], _debtPair.baseAsset[@"symbol"]];
    
    //    //  变化量
    //    NSComparisonResult result = [n_add_debt compare:[NSDecimalNumber zero]];
    //    if (result != NSOrderedSame){
    //        //  n_add_debt < 0
    //        if (result == NSOrderedAscending){
    //            _cellDebtAvailable.detailTextLabel.text = [OrgUtils formatFloatValue:n_add_debt];
    //            _cellDebtAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].sellColor;
    //        }else{
    //            _cellDebtAvailable.detailTextLabel.text = [NSString stringWithFormat:@"+%@", [OrgUtils formatFloatValue:n_add_debt]];
    //            _cellDebtAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
    //        }
    //    }else{
    //        _cellDebtAvailable.detailTextLabel.text = @"";
    //    }
    
    //  n_available < 0
    if ([n_available compare:[NSDecimalNumber zero]] == NSOrderedAscending){
        _cellDebtAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].tintColor;
    }else{
        _cellDebtAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    }
}

/**
 *  根据质押率获取对应颜色。
 */
- (UIColor*)_getCollateralRatioColor
{
    //  0 - mcr     黄色（爆仓中）
    //  mcr - 250   红色（危险） - 卖出颜色
    //  250 - 400   白色（普通）
    //  400+        绿色（安全） - 买入颜色
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    if (_nCurrMortgageRate){
        float value = [_nCurrMortgageRate floatValue];
        float mcr = [_nMaintenanceCollateralRatio floatValue];
        if (value < mcr){
            return theme.callOrderColor;
        }else if (value < 2.5){
            return theme.sellColor;
        }else if (value < 4.0){
            return theme.textColorMain;
        }else{
            return theme.buyColor;
        }
    }else{
        return theme.textColorMain;
    }
}

/**
 *  (private) 刷新目标抵押率
 */
- (void)_refreshUI_target_ratio:(NSDecimalNumber*)ratio reset_slider:(BOOL)reset_slider
{
    //  预测市场不显示
    if (_currAssetIsPredictionmarket) {
        return;
    }
    
    if (!ratio){
        ratio = [NSDecimalNumber zero];
    }
    
    if (reset_slider){
        id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
        assert(parameters);
        float value = [ratio floatValue];
        [_curve_target_ratio set_min:fmaxf([_nMaintenanceCollateralRatio floatValue] - 0.3f, 0.0f)];
        [_curve_target_ratio set_max:fmaxf(value, [parameters[@"max_target_ratio"] floatValue])];
        [_curve_target_ratio set_value:value];
    }
    
    //  ratio < _nMaintenanceCollateralRatio
    if ([ratio compare:_nMaintenanceCollateralRatio] == NSOrderedAscending){
        _cellLabelTargetRate.textLabel.textColor = [ThemeManager sharedThemeManager].textColorGray;
        _cellLabelTargetRate.textLabel.text = NSLocalizedString(@"kDebtTipTargetRatioNotSet", @"目标抵押率 未设置");
    }else{
        _cellLabelTargetRate.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _cellLabelTargetRate.textLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kDebtTipTargetRatio", @"目标抵押率"),
                                               [OrgUtils formatFloatValue:ratio usesGroupingSeparator:NO minimumFractionDigits:2]];
    }
}

/**
 *  (private) 刷新抵押率
 */
- (void)_refreshUI_ratio:(BOOL)reset_slider
{
    //  预测市场不显示
    if (_currAssetIsPredictionmarket) {
        return;
    }
    
    assert(_nMaintenanceCollateralRatio);
    _cellLabelRate.textLabel.textColor = [self _getCollateralRatioColor];
    if (_nCurrMortgageRate){
        _cellLabelRate.textLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kDebtLableRatio", @"抵押率"),
                                         [OrgUtils formatFloatValue:_nCurrMortgageRate usesGroupingSeparator:NO minimumFractionDigits:2]];
        if (reset_slider){
            id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
            assert(parameters);
            float value = [_nCurrMortgageRate floatValue];
            [_curve_ratio set_min:0.0f];
            [_curve_ratio set_max:fmaxf(value, [parameters[@"max_ratio"] floatValue])];
            [_curve_ratio set_value:value];
        }
    }else{
        _cellLabelRate.textLabel.text = [NSString stringWithFormat:@"%@ --", NSLocalizedString(@"kDebtLableRatio", @"抵押率")];
        if (reset_slider){
            [_curve_ratio set_min:0.0f];
            [_curve_ratio set_max:6.0f];
            [_curve_ratio set_value:0.0f];
        }
    }
}

/**
 *  (private) 刷新强平触发价
 */
- (void)_refreshUI_SettlementTriggerPrice
{
    id price_title = NSLocalizedString(@"kDebtLableCallPrice", @"强平价格");
    id suffix = [NSString stringWithFormat:@"%@/%@", _debtPair.baseAsset[@"symbol"], _debtPair.quoteAsset[@"symbol"]];
    
    NSDecimalNumber* n_debt = [OrgUtils auxGetStringDecimalNumberValue:_tfDebtValue.text];
    NSDecimalNumber* n_coll = [OrgUtils auxGetStringDecimalNumberValue:_tfCollateralValue.text];
    
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if (_currAssetIsPredictionmarket || [n_debt compare:n_zero] == NSOrderedSame || [n_coll compare:n_zero] == NSOrderedSame){
        _triggerSettlementPriceTitle.text = [NSString stringWithFormat:@"%@ --%@", price_title, suffix];
        _triggerSettlementPriceTitle.textColor = [ThemeManager sharedThemeManager].textColorMain;
    }else{
        //  计算强平触发价 price = debt * 1.75 / coll
        NSDecimalNumberHandler* ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                     scale:_debtPair.basePrecision
                                                                                          raiseOnExactness:NO
                                                                                           raiseOnOverflow:NO
                                                                                          raiseOnUnderflow:NO
                                                                                       raiseOnDivideByZero:NO];
        id n = [n_debt decimalNumberByMultiplyingBy:_nMaintenanceCollateralRatio];
        n = [n decimalNumberByDividingBy:n_coll withBehavior:ceilHandler];
        _triggerSettlementPriceTitle.text = [NSString stringWithFormat:@"%@ %@%@", price_title,
                                             [OrgUtils formatFloatValue:n], suffix];
        _triggerSettlementPriceTitle.textColor = [self _getCollateralRatioColor];
    }
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcFormMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcFormData:
            return [_rowTypeArray count];
        case kVcFormAction:
            return 1;
        case kVcFromTips:
            return 1;
        default:
            break;
    }
    //  not reached...
    return 1;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcFormData:
        {
            switch ([[_rowTypeArray objectAtIndex:indexPath.row] integerValue]) {
                case kVcSubDebtAvailable:
                case kVcSubCollAvailable:
                    return 24.0f;
                case kVcSubRateValue:
                case kVcSubTargetRateValue:
                    return 28.0f;
                case kVcSubRateSlider:
                case kVcSubTargetRateSlider:
                    return 36.0f;
                default:
                    break;
            }
        }
            break;
        case kVcFromTips:
            return [_cellTips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    return tableView.rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcFormData:
        {
            switch ([[_rowTypeArray objectAtIndex:indexPath.row] integerValue]) {
                case kVcSubDebtAvailable:
                {
                    return _cellDebtAvailable;
                }
                    break;
                case kVcSubDebtValue:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    [_mainTableView attachTextfieldToCell:cell tf:_tfDebtValue];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                case kVcSubCollAvailable:
                {
                    return _cellCollAvailable;
                }
                    break;
                case kVcSubCollValue:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    [_mainTableView attachTextfieldToCell:cell tf:_tfCollateralValue];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                case kVcSubRateValue:
                {
                    return _cellLabelRate;
                }
                    break;
                case kVcSubRateSlider:
                {
                    if (_collRateSlider.superview){
                        [_collRateSlider removeFromSuperview];
                    }
                    CGFloat xoffset = _mainTableView.layoutMargins.left;
                    _collRateSlider.frame = CGRectMake(xoffset, 0, self.view.bounds.size.width - xoffset * 2, 36);
                    
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @" ";
                    [cell.contentView addSubview:_collRateSlider];
                    //                    cell.showCustomBottomLine = YES;
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                case kVcSubTargetRateValue:
                {
                    return _cellLabelTargetRate;
                }
                    break;
                case kVcSubTargetRateSlider:
                {
                    if (_collTargetRateSlider.superview){
                        [_collTargetRateSlider removeFromSuperview];
                    }
                    CGFloat xoffset = _mainTableView.layoutMargins.left;
                    _collTargetRateSlider.frame = CGRectMake(xoffset, 0, self.view.bounds.size.width - xoffset * 2, 36);
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @" ";
                    [cell.contentView addSubview:_collTargetRateSlider];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case kVcFormAction:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnOk cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcFromTips:
        {
            return _cellTips;
        }
            break;
        default:
            break;
    }
    //  not reached...
    return nil;
    
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcFormAction){
            [self onFormActionClicked];
        }
    }];
}

/**
 *  (private) 事件 - 调整债仓 or 登录按钮点击
 */
- (void)onFormActionClicked
{
    if ([self isUserLogined]){
        //  执行调整债仓操作
        [self onDebtActionClicked];
    }else{
        //  REMARK：这里不用 GuardWalletExist，仅跳转登录界面，登录后停留在交易界面，而不是登录后执行买卖操作。
        //  如果当前按钮显示的是买卖，那么应该继续处理，但这里按钮显示的就是登录，那么仅执行登录处理。
        VCImportAccount* vc = [[VCImportAccount alloc] init];
        vc.title = NSLocalizedString(@"kVcTitleLogin", @"登录");
        [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
    }
}

/**
 *  (private) 事件 - 调整债仓行为
 */
- (void)onDebtActionClicked
{
    id bitasset_data = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[_debtPair.baseAsset objectForKey:@"bitasset_data_id"]];
    if (!bitasset_data) {
        [OrgUtils makeToast:NSLocalizedString(@"kDebtTipNetworkErrorPleaseRefresh", @"网络异常，请重新刷新界面。")];
        return;
    }
    
    if ([ModelUtils assetHasGlobalSettle:bitasset_data]) {
        [OrgUtils makeToast:NSLocalizedString(@"kDebtTipAssetHasGlobalSettled", @"该资产已经全局清算，不可调整债仓。")];
        return;
    }
    
    //  非预测市场并且没有喂价
    if (!_currAssetIsPredictionmarket && !_nCurrFeedPrice) {
        [OrgUtils makeToast:NSLocalizedString(@"kDebtTipAssetNoValidFeedData", @"该资产没有有效的喂价，不可调整债仓。")];
        return;
    }
    
    //  --- 检查参数有效性 ---
    id zero = [NSDecimalNumber zero];
    
    NSDecimalNumber* n_new_debt = [OrgUtils auxGetStringDecimalNumberValue:_tfDebtValue.text];
    NSDecimalNumber* n_new_coll = [OrgUtils auxGetStringDecimalNumberValue:_tfCollateralValue.text];
    
    NSDecimalNumber* n_old_debt = zero;
    NSDecimalNumber* n_old_coll = zero;
    id debt_callorder = [self _getCallOrder];
    if (debt_callorder){
        n_old_debt = [NSDecimalNumber decimalNumberWithMantissa:[debt_callorder[@"debt"] unsignedLongLongValue]
                                                       exponent:-_debtPair.basePrecision isNegative:NO];
        n_old_coll = [NSDecimalNumber decimalNumberWithMantissa:[debt_callorder[@"collateral"] unsignedLongLongValue]
                                                       exponent:-_debtPair.quotePrecision isNegative:NO];
    }
    
    id n_delta_coll = [n_new_coll decimalNumberBySubtracting:n_old_coll];
    id n_delta_debt = [n_new_debt decimalNumberBySubtracting:n_old_debt];
    
    //  参数无效（两个都为0，没有变化。）
    if ([n_delta_coll compare:zero] == NSOrderedSame && [n_delta_debt compare:zero] == NSOrderedSame){
        [OrgUtils makeToast:NSLocalizedString(@"kDebtTipValueAndAmountNotChange", @"借款数量和抵押物没发生变化。")];
        return;
    }
    
    //  抵押物不足
    id n_balance_coll = [NSDecimalNumber decimalNumberWithMantissa:[_collateralBalance[@"amount"] unsignedLongLongValue]
                                                          exponent:-_debtPair.quotePrecision
                                                        isNegative:NO];
    id n_rest_coll = [n_balance_coll decimalNumberBySubtracting:n_delta_coll];
    //  n_rest_coll < zero
    if ([n_rest_coll compare:zero] == NSOrderedAscending){
        [OrgUtils makeToast:NSLocalizedString(@"kDebtTipCollNotEnough", @"抵押物余额不足，请调整数量。")];
        return;
    }
    
    //  可用余额不足
    id n_balance_debt = [self _getDebtBalance];
    id n_rest_debt = [n_balance_debt decimalNumberByAdding:n_delta_debt];
    //  n_rest_debt < zero
    if ([n_rest_debt compare:zero] == NSOrderedAscending){
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kDebtTipAvailableNotEnough", @"%@余额不足，请调整还款数量。"), _debtPair.baseAsset[@"symbol"]]];
        return;
    }
    
    //  非预测市场：各种情况下的抵押率判断
    if (!_currAssetIsPredictionmarket) {
        if ([n_old_debt compare:zero] > 0) {
            if ([n_new_debt compare:zero] > 0) {
                //  更新债仓：新负债和旧负债都存在。
                id n_new_ratio = [self _calcCollRate:n_new_debt coll:n_new_coll percent_result:NO];
                assert([n_old_debt compare:zero] > 0);
                id n_old_ratio = [self _calcCollRate:n_old_debt coll:n_old_coll percent_result:NO];
                if ([n_old_ratio compare:_nMaintenanceCollateralRatio] < 0) {
                    //  已经处于爆仓中
                    //  【BSIP30】在爆仓状态可以上调抵押率，不再强制要求必须上调到多少，但抵押率不足最低要求时不能增加借款
                    if ([n_new_ratio compare:_nMaintenanceCollateralRatio] < 0 && [n_delta_debt compare:zero] > 0){
                        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kDebtTipRatioTooLow", @"抵押率低于 %@，不能追加借贷。"), _nMaintenanceCollateralRatio]];
                        return;
                    }
                    if ([n_new_ratio compare:n_old_ratio] <= 0) {
                        [OrgUtils makeToast:NSLocalizedString(@"kDebtTipCannotAdjustMoreLowerRatio", @"您已经处于强制平仓状态，不能降低抵押率。")];
                        return;
                    }
                } else {
                    //  尚未爆仓
                    if ([n_new_ratio compare:_nMaintenanceCollateralRatio] < 0) {
                        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kDebtTipCollRatioCannotLessThanMCR", @"抵押率不能低于 %@。"),
                                             _nMaintenanceCollateralRatio]];
                        return;
                    }
                }
            } else {
                //  关闭债仓：旧负债存在，新负债不存在。
            }
        } else {
            //  新开债仓：没有旧的负债
            if ([n_new_debt compare:zero] <= 0) {
                [OrgUtils makeToast:NSLocalizedString(@"kDebtTipPleaseInputDebtValueFirst", @"请先输入借款金额。")];
                return;
            }
            id n_new_ratio = [self _calcCollRate:n_new_debt coll:n_new_coll percent_result:NO];
            if ([n_new_ratio compare:_nMaintenanceCollateralRatio] < 0) {
                [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kDebtTipCollRatioCannotLessThanMCR", @"抵押率不能低于 %@。"),
                                     _nMaintenanceCollateralRatio]];
                return;
            }
        }
    }
    
    //  TODO:fowallet 不足的时候否直接提示显示？？？
    if (![[_fee_item objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }
    
    //  获取目标抵押率（小于MCR时取消设置）
    id n_target_ratio = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%.2f", [_curve_target_ratio get_value]]];
    //  n_target_ratio < _nMaintenanceCollateralRatio
    if ([n_target_ratio compare:_nMaintenanceCollateralRatio] == NSOrderedAscending){
        n_target_ratio = nil;
    }
    
    //  --- 检测合法 执行请求 ---
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self _processDebtActionCore:n_delta_coll delta_debt:n_delta_debt target_ratio:n_target_ratio];
        }
    }];
}

- (void)_processDebtActionCore:(NSDecimalNumber*)n_delta_coll delta_debt:(NSDecimalNumber*)n_delta_debt target_ratio:(NSDecimalNumber*)n_target_ratio
{
    assert(_fee_item);
    id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    id funding_account = [account objectForKey:@"id"];
    assert(funding_account);
    
    //  构造OP
    id coll = [NSString stringWithFormat:@"%@", [n_delta_coll decimalNumberByMultiplyingByPowerOf10:_debtPair.quotePrecision]];
    id debt = [NSString stringWithFormat:@"%@", [n_delta_debt decimalNumberByMultiplyingByPowerOf10:_debtPair.basePrecision]];
    unsigned long long target_ratio = 0;
    if (n_target_ratio){
        id s_target_ratio = [NSString stringWithFormat:@"%@", [n_target_ratio decimalNumberByMultiplyingByPowerOf10:3]];
        target_ratio = [s_target_ratio unsignedLongLongValue];
    }
    id op = @{
        @"fee":@{
                @"amount":@0,
                @"asset_id":[_fee_item objectForKey:@"fee_asset_id"],
        },
        @"funding_account":funding_account,
        @"delta_collateral":@{
                @"amount":@([coll longLongValue]),
                @"asset_id":_debtPair.quoteId,
        },
        @"delta_debt":@{
                @"amount":@([debt longLongValue]),
                @"asset_id":_debtPair.baseId,
        },
        @"extensions":(n_target_ratio ? @{@"target_collateral_ratio":@(target_ratio)} : @{})
    };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_call_order_update
                     using_owner_authority:NO
                  invoke_proposal_callback:NO
                                    opdata:op
                                 opaccount:account
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        //  请求网络广播
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] callOrderUpdate:op] then:(^id(id data) {
            [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:funding_account] then:(^id(id full_data) {
                NSLog(@"callorder_update & refresh: %@", full_data);
                [self hideBlockView];
                //  刷新UI
                [self refreshUI:YES new_feed_price_data:nil];
                [OrgUtils makeToast:NSLocalizedString(@"kDebtTipTxUpdatePositionFullOK", @"债仓调整完毕。")];
                //  [统计]
                [OrgUtils logEvents:@"txCallOrderUpdateFullOK"
                             params:@{@"account":funding_account, @"debt_asset":_debtPair.baseAsset[@"symbol"]}];
                return nil;
            })] catch:(^id(id error) {
                [self hideBlockView];
                [OrgUtils makeToast:NSLocalizedString(@"kDebtTipTxUpdatePositionOK", @"债仓调整完毕，但刷新界面数据失败，请稍后再试。")];
                //  [统计]
                [OrgUtils logEvents:@"txCallOrderUpdateOK"
                             params:@{@"account":funding_account, @"debt_asset":_debtPair.baseAsset[@"symbol"]}];
                return nil;
            })];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txCallOrderUpdateFailed"
                         params:@{@"account":funding_account, @"debt_asset":_debtPair.baseAsset[@"symbol"]}];
            return nil;
        })];
    }];
}

#pragma mark- switch theme
- (void)switchTheme
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    self.view.backgroundColor = theme.appBackColor;
    
    _currFeedPriceTitle.textColor = theme.textColorMain;
    _triggerSettlementPriceTitle.textColor = theme.textColorMain;
    
    _tfDebtValue.textColor = theme.textColorMain;
    _tfCollateralValue.textColor = theme.textColorMain;
    _tfDebtValue.attributedPlaceholder = [ViewUtils placeholderAttrString:_tfDebtValue.placeholder];
    _tfCollateralValue.attributedPlaceholder = [ViewUtils placeholderAttrString:_tfCollateralValue.placeholder];
    _cellLabelRate.textLabel.textColor = theme.textColorMain;
    
    if (_mainTableView){
        [_mainTableView reloadData];
    }
}

#pragma mark- switch language
- (void)switchLanguage
{
    self.title = NSLocalizedString(@"kVcTitleMarginPosition", @"抵押借贷");
    self.tabBarItem.title = NSLocalizedString(@"kTabBarNameCollateral", @"抵押");
    self.navigationItem.leftBarButtonItem.title = NSLocalizedString(@"kDebtLableReset", @"重置");
    self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"kDebtLableSelectAsset", @"选择资产");
    
    _cellDebtAvailable.textLabel.text = NSLocalizedString(@"kDebtLabelCellTitleDebtValue", @"借款金额");
    _cellCollAvailable.textLabel.text = NSLocalizedString(@"kDebtLabelCellTitleCollAmount", @"抵押物");
    
    if (_tfDebtValue && [_tfDebtValue.rightView isKindOfClass:[TailerViewAssetAndButtons class]]) {
        TailerViewAssetAndButtons* debtTailer = (TailerViewAssetAndButtons*)_tfDebtValue.rightView;
        [debtTailer drawButtonNames:@[NSLocalizedString(@"kDebtLablePayMaxDebt", @"还款")]];
    }
    
    if (_tfCollateralValue && [_tfCollateralValue.rightView isKindOfClass:[TailerViewAssetAndButtons class]]) {
        TailerViewAssetAndButtons* collTailer = (TailerViewAssetAndButtons*)_tfCollateralValue.rightView;
        [collTailer drawButtonNames:@[NSLocalizedString(@"kDebtLableUseMax", @"全部")]];
    }
    
    _tfDebtValue.attributedPlaceholder = [ViewUtils placeholderAttrString:NSLocalizedString(@"kDebtTipInputDebtValue", @"请输入借款金额")];
    _tfCollateralValue.attributedPlaceholder = [ViewUtils placeholderAttrString:NSLocalizedString(@"kDebtTipInputCollAmount", @"请输入抵押物数量")];
    
    [_cellTips updateLabelText:NSLocalizedString(@"kDebtWarmTips", @"【温馨提示】\n1、当喂价下降到强平触发价时，系统将会自动出售您的抵押资产用于归还借款。请注意调整抵押率控制风险。\n2、当锁定借款金额时，抵押率会随抵押物数量变化而变化。\n3、当锁定抵押率时，借款金额会随抵押物数量变化而变化。")];
    
    if (_mainTableView){
        [_mainTableView reloadData];
    }
}

@end
