//
//  ModelUtils.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import "ModelUtils.h"

#import "ChainObjectManager.h"
#import "OrgUtils.h"
#import "TradingPair.h"
#import "SettingManager.h"

@implementation ModelUtils

/*
 *  (public) 资产 - 是否是挖矿相关的资产
 */
+ (BOOL)assetIsMinerAsset:(id)asset_object_or_asset_id
{
    assert(asset_object_or_asset_id);
    
    NSString* oid = [asset_object_or_asset_id isKindOfClass:[NSDictionary class]] ? [asset_object_or_asset_id objectForKey:@"id"] : asset_object_or_asset_id;
    
    for (id miner_item in [[SettingManager sharedSettingManager] getAppAssetMinerList]) {
        if (oid && [oid isEqualToString:[[[miner_item objectForKey:@"price"] objectForKey:@"amount_to_sell"] objectForKey:@"asset_id"]]) {
            return YES;
        }
    }
    
    return NO;
}

/*
 *  (public) 资产 - 是否是参与挖矿的资产
 */
+ (BOOL)assetIsMinerInAsset:(id)asset_object_or_asset_id
{
    assert(asset_object_or_asset_id);
    
    NSString* oid = [asset_object_or_asset_id isKindOfClass:[NSDictionary class]] ? [asset_object_or_asset_id objectForKey:@"id"] : asset_object_or_asset_id;
    
    for (id miner_item in [[SettingManager sharedSettingManager] getAppAssetMinerList]) {
        if (oid && [[miner_item objectForKey:@"miner"] boolValue] && [oid isEqualToString:[[[miner_item objectForKey:@"price"] objectForKey:@"amount_to_sell"] objectForKey:@"asset_id"]]) {
            return YES;
        }
    }
    
    return NO;
}

/*
 *  (public) 资产 - 是否是退出挖矿的资产
 */
+ (BOOL)assetIsMinerOutAsset:(id)asset_object_or_asset_id
{
    assert(asset_object_or_asset_id);
    
    NSString* oid = [asset_object_or_asset_id isKindOfClass:[NSDictionary class]] ? [asset_object_or_asset_id objectForKey:@"id"] : asset_object_or_asset_id;
    
    for (id miner_item in [[SettingManager sharedSettingManager] getAppAssetMinerList]) {
        if (oid && ![[miner_item objectForKey:@"miner"] boolValue] && [oid isEqualToString:[[[miner_item objectForKey:@"price"] objectForKey:@"amount_to_sell"] objectForKey:@"asset_id"]]) {
            return YES;
        }
    }
    
    return NO;
}

/*
 *  (public) 资产 - 资产是否是网关资产判断
 */
+ (BOOL)assetIsGatewayAsset:(NSDictionary*)asset_object
{
    assert(asset_object);
    id issuer = [asset_object objectForKey:@"issuer"];
    if (issuer && ![issuer isEqualToString:@""]) {
        id knownGatewayAccountsList = [[SettingManager sharedSettingManager] getAppKnownGatewayAccounts];
        if (knownGatewayAccountsList && [knownGatewayAccountsList count] > 0) {
            for (NSString* gateway_account in knownGatewayAccountsList) {
                if ([gateway_account isEqualToString:issuer]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

/*
 *  (public) 资产 - 判断资产是否允许强清
 */
+ (BOOL)assetCanForceSettle:(id)asset_object
{
    NSInteger flags = [[[asset_object objectForKey:@"options"] objectForKey:@"flags"] integerValue];
    if ((flags & ebat_disable_force_settle) != 0) {
        return NO;
    }
    return YES;
}

/*
 *  (public) 资产 - 判断资产是否允许发行人全局清算
 */
+ (BOOL)assetCanGlobalSettle:(id)asset_object
{
    NSInteger issuer_permissions = [[[asset_object objectForKey:@"options"] objectForKey:@"issuer_permissions"] integerValue];
    return (issuer_permissions & ebat_global_settle) != 0;
}

/*
 *  (public) 资产 - 判断资产是否允许隐私转账
 */
+ (BOOL)assetAllowConfidential:(id)asset_object
{
    NSInteger flags = [[[asset_object objectForKey:@"options"] objectForKey:@"flags"] integerValue];
    if ((flags & ebat_disable_confidential) != 0) {
        return NO;
    }
    return YES;
}

/*
 *  (public) 资产 - 资产是否允许覆盖转账（强制转账）
 */
+ (BOOL)assetCanOverride:(id)asset_object
{
    NSInteger flags = [[[asset_object objectForKey:@"options"] objectForKey:@"flags"] integerValue];
    return (flags & ebat_override_authority) != 0;
}

/*
 *  (public) 资产 - 是否所有转账都需要发行人审核
 */
+ (BOOL)assetIsTransferRestricted:(id)asset_object
{
    NSInteger flags = [[[asset_object objectForKey:@"options"] objectForKey:@"flags"] integerValue];
    return (flags & ebat_transfer_restricted) != 0;
}

/*
 *  (public) 资产 - 资产是否需要持有人属于白名单判断。
 */
+ (BOOL)assetNeedWhiteList:(id)asset_object
{
    NSInteger flags = [[[asset_object objectForKey:@"options"] objectForKey:@"flags"] integerValue];
    return (flags & ebat_white_list) != 0;
}

/*
 *  (public) 资产 - 是否已经全局清算判断
 */
+ (BOOL)assetHasGlobalSettle:(id)bitasset_object
{
    return ![self isNullPrice:[bitasset_object objectForKey:@"settlement_price"]];
}

/*
 *  (public) 资产 - 是否是智能币判断
 */
+ (BOOL)assetIsSmart:(id)asset
{
    NSString* bitasset_data_id = [asset objectForKey:@"bitasset_data_id"];
    return bitasset_data_id && ![bitasset_data_id isEqualToString:@""];
}

/*
 *  (public) 资产 - 是否是链核心资产判断
 */
+ (BOOL)assetIsCore:(id)asset
{
    return [[asset objectForKey:@"id"] isEqualToString:[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID];
}

/*
 *  （public) 获取智能币扩展参数
 */
+ (NSDecimalNumber*)getBitAssetDataExtargs:(id)bitasset_data arg_name:(NSString*)arg_name precision:(NSInteger)precision
{
    assert(bitasset_data);
    assert(arg_name);
    NSInteger result = 0;
    id ext = [bitasset_data[@"options"] objectForKey:@"extensions"];
    if (ext) {
        id value = [ext objectForKey:arg_name];
        if (value) {
            result = [value integerValue];
        }
    }
    return [NSDecimalNumber decimalNumberWithMantissa:result exponent:-precision isNegative:NO];
}

/*
 *  (public) 判断是否价格无效
 */
+ (BOOL)isNullPrice:(id)price
{
    NSString* core_asset_id = [ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID;
    if ([core_asset_id isEqualToString:[[price objectForKey:@"base"] objectForKey:@"asset_id"]] &&
        [core_asset_id isEqualToString:[[price objectForKey:@"quote"] objectForKey:@"asset_id"]]) {
        return YES;
    }
    return NO;
}

/*
 *  (public) 根据汇率换算手续费。
 */
+ (NSDecimalNumber*)multiplyAndRoundupNetworkFee:(id)core_asset
                                           asset:(id)asset
                                      n_core_fee:(NSDecimalNumber*)n_core_fee
                              core_exchange_rate:(id)core_exchange_rate
{
    assert(core_asset);
    assert(asset);
    assert(n_core_fee);
    assert(core_exchange_rate);
    
    NSString* core_asset_id = [core_asset objectForKey:@"id"];
    NSInteger core_precision = [[core_asset objectForKey:@"precision"] integerValue];
    
    NSString* asset_id = [asset objectForKey:@"id"];
    NSInteger precision = [[asset objectForKey:@"precision"] integerValue];
    
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    NSDecimalNumberHandler* handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                             scale:precision
                                                                                  raiseOnExactness:NO
                                                                                   raiseOnOverflow:NO
                                                                                  raiseOnUnderflow:NO
                                                                               raiseOnDivideByZero:NO];
    
    id base = [core_exchange_rate objectForKey:@"base"];
    id quote = [core_exchange_rate objectForKey:@"quote"];
    if ([core_asset_id isEqualToString:base[@"asset_id"]]) {
        if (![asset_id isEqualToString:quote[@"asset_id"]]) {
            //  null price
            return nil;
        }
        //  quote / base * n_core_fee
        id n_base = [NSDecimalNumber decimalNumberWithMantissa:[[base objectForKey:@"amount"] unsignedLongLongValue]
                                                      exponent:-core_precision
                                                    isNegative:NO];
        if ([n_base compare:n_zero] <= 0) {
            //  error price
            return nil;
        }
        id n_quote = [NSDecimalNumber decimalNumberWithMantissa:[[quote objectForKey:@"amount"] unsignedLongLongValue]
                                                       exponent:-precision
                                                     isNegative:NO];
        return [[n_core_fee decimalNumberByMultiplyingBy:n_quote] decimalNumberByDividingBy:n_base withBehavior:handler];
    } else if ([core_asset_id isEqualToString:quote[@"asset_id"]]) {
        if (![asset_id isEqualToString:base[@"asset_id"]]) {
            //  null price
            return nil;
        }
        //  base / quote * n_core_fee
        id n_quote = [NSDecimalNumber decimalNumberWithMantissa:[[quote objectForKey:@"amount"] unsignedLongLongValue]
                                                       exponent:-core_precision
                                                     isNegative:NO];
        if ([n_quote compare:n_zero] <= 0) {
            //  error price
            return nil;
        }
        id n_base = [NSDecimalNumber decimalNumberWithMantissa:[[base objectForKey:@"amount"] unsignedLongLongValue]
                                                      exponent:-precision
                                                    isNegative:NO];
        return [[n_core_fee decimalNumberByMultiplyingBy:n_base] decimalNumberByDividingBy:n_quote withBehavior:handler];
    } else {
        NSAssert(NO, @"invalid core_exchange_rate");
    }
    return nil;
}

/*
 *  (public) 辅助方法 - 从full account data获取指定资产等余额信息，返回 NSDecimalNumber 对象，没有找到对应资产则返回 ZERO 对象。
 */
+ (NSDecimalNumber*)findAssetBalance:(NSDictionary*)full_account_data asset_id:(NSString*)asset_id asset_precision:(NSInteger)asset_precision
{
    assert(full_account_data);
    assert(asset_id);
    id balances = [full_account_data objectForKey:@"balances"];
    if (balances) {
        for (id balance_object in balances) {
            if ([asset_id isEqualToString:[balance_object objectForKey:@"asset_type"]]) {
                return [NSDecimalNumber decimalNumberWithMantissa:[[balance_object objectForKey:@"balance"] unsignedLongLongValue]
                                                         exponent:-asset_precision
                                                       isNegative:NO];
            }
        }
    }
    return [NSDecimalNumber zero];
}

+ (NSDecimalNumber*)findAssetBalance:(NSDictionary*)full_account_data asset:(NSDictionary*)asset
{
    assert(asset);
    return [self findAssetBalance:full_account_data
                         asset_id:[asset objectForKey:@"id"]
                  asset_precision:[[asset objectForKey:@"precision"] integerValue]];
}

/*
 *  (public) 从石墨烯ID列表获取依赖的ID列表。
 */
+ (NSArray*)collectDependence:(NSArray*)source_oid_list level_keys:(id)keystring_or_keyarray
{
    if ([keystring_or_keyarray isKindOfClass:[NSString class]]) {
        keystring_or_keyarray = @[keystring_or_keyarray];
    }
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    NSMutableDictionary* id_hash = [NSMutableDictionary dictionary];
    for (id oid in source_oid_list) {
        id obj = [chainMgr getChainObjectByID:oid];
        assert(obj);
        id target_obj = obj;
        for (id level_key in keystring_or_keyarray) {
            assert([target_obj isKindOfClass:[NSDictionary class]]);
            target_obj = [target_obj objectForKey:level_key];
            if (!target_obj) {
                break;
            }
        }
        if (target_obj && [target_obj isKindOfClass:[NSString class]]) {
            [id_hash setObject:@YES forKey:target_obj];;
        }
    }
    return [id_hash allKeys];
}

/*
 *  (public) 计算平均数
 */
+ (NSDecimalNumber*)calculateAverage:(NSDecimalNumber*)total n:(NSDecimalNumber*)n result_precision:(NSInteger)result_precision
{
    NSDecimalNumberHandler* handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                             scale:result_precision
                                                                                  raiseOnExactness:NO
                                                                                   raiseOnOverflow:NO
                                                                                  raiseOnUnderflow:NO
                                                                               raiseOnDivideByZero:NO];
    
    return [total decimalNumberByDividingBy:n withBehavior:handler];
}

/*
 *  (public) 计算总数
 */
+ (NSDecimalNumber*)calTotal:(NSDecimalNumber*)avg n:(NSDecimalNumber*)n result_precision:(NSInteger)result_precision
{
    NSDecimalNumberHandler* handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                             scale:result_precision
                                                                                  raiseOnExactness:NO
                                                                                   raiseOnOverflow:NO
                                                                                  raiseOnUnderflow:NO
                                                                               raiseOnDivideByZero:NO];
    
    return [avg decimalNumberByMultiplyingBy:n withBehavior:handler];
}

/*
 *  (public) 处理链上返回的限价单信息，方便UI显示。
 *  filterTradingPair - 筛选当前交易对相关订单，可为nil。
 */
+ (NSMutableArray*)processLimitOrders:(NSArray*)limit_orders filter:(TradingPair*)filterTradingPair
{
    NSMutableArray* dataArray = [NSMutableArray array];
    if (!limit_orders) {
        return dataArray;
    }
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    for (id order in limit_orders) {
        id sell_price = [order objectForKey:@"sell_price"];
        id base = [sell_price objectForKey:@"base"];
        id quote = [sell_price objectForKey:@"quote"];
        id base_id = [base objectForKey:@"asset_id"];
        id quote_id = [quote objectForKey:@"asset_id"];
        
        //  筛选当前交易对相关订单，并根据当前交易对确定买卖方向。
        BOOL issell;
        if (filterTradingPair) {
            if ([base_id isEqualToString:filterTradingPair.baseId] && [quote_id isEqualToString:filterTradingPair.quoteId]){
                //  买单：卖出 CNY
                issell = NO;
            }else if ([base_id isEqualToString:filterTradingPair.quoteId] && [quote_id isEqualToString:filterTradingPair.baseId]){
                //  卖单：卖出 BTS
                issell = YES;
            }else{
                //  其他交易对的订单
                continue;
            }
        }
        
        id base_asset = [chainMgr getChainObjectByID:base_id];
        id quote_asset = [chainMgr getChainObjectByID:quote_id];
        assert(base_asset);
        assert(quote_asset);
        
        NSInteger base_precision = [[base_asset objectForKey:@"precision"] integerValue];
        NSInteger quote_precision = [[quote_asset objectForKey:@"precision"] integerValue];
        double base_value = [OrgUtils calcAssetRealPrice:base[@"amount"] precision:base_precision];
        double quote_value = [OrgUtils calcAssetRealPrice:quote[@"amount"] precision:quote_precision];
        
        //  REMARK：没筛选的情况下，根据资产优先级自动计算买卖方向。
        if (!filterTradingPair) {
            id assetBasePriority = [chainMgr genAssetBasePriorityHash];
            NSInteger base_priority = [[assetBasePriority objectForKey:[base_asset objectForKey:@"symbol"]] integerValue];
            NSInteger quote_priority = [[assetBasePriority objectForKey:[quote_asset objectForKey:@"symbol"]] integerValue];
            if (base_priority > quote_priority) {
                issell = NO;
            } else {
                issell = YES;
            }
        }
        
        double price;
        NSString* price_str;
        NSString* amount_str;
        NSString* total_str;
        NSString* base_sym;
        NSString* quote_sym;
        //  REMARK: base 是卖出的资产，除以 base 则为卖价(每1个 base 资产的价格)。反正 base / quote 则为买入价。
        if (!issell){
            //  buy     price = base / quote
            price = base_value / quote_value;
            price_str = [OrgUtils formatFloatValue:price precision:base_precision];
            double total_real = [OrgUtils calcAssetRealPrice:order[@"for_sale"] precision:base_precision];
            double amount_real = total_real / price;
            amount_str = [OrgUtils formatFloatValue:amount_real precision:quote_precision];
            total_str = [OrgUtils formatAssetString:order[@"for_sale"] precision:base_precision];
            base_sym = [base_asset objectForKey:@"symbol"];
            quote_sym = [quote_asset objectForKey:@"symbol"];
        }else{
            //  sell    price = quote / base
            price = quote_value / base_value;
            price_str = [OrgUtils formatFloatValue:price precision:quote_precision];
            amount_str = [OrgUtils formatAssetString:order[@"for_sale"] precision:base_precision];
            double for_sale_real = [OrgUtils calcAssetRealPrice:order[@"for_sale"] precision:base_precision];
            double total_real = price * for_sale_real;
            total_str = [OrgUtils formatFloatValue:total_real precision:quote_precision];
            base_sym = [quote_asset objectForKey:@"symbol"];
            quote_sym = [base_asset objectForKey:@"symbol"];
        }
        //  REMARK：特殊处理，如果按照 base or quote 的精度格式化出价格为0了，则扩大精度重新格式化。
        if ([price_str isEqualToString:@"0"]){
            price_str = [OrgUtils formatFloatValue:price precision:8];
        }
        
        [dataArray addObject:@{@"time":order[@"expiration"],
                               @"issell":@(issell),
                               @"price":price_str,
                               @"amount":amount_str,
                               @"total":total_str,
                               @"base_symbol":base_sym,
                               @"quote_symbol":quote_sym,
                               @"id": order[@"id"],
                               @"seller": order[@"seller"],
                               @"raw_order": order  //  原始数据
        }];
    }
    
    //  按照ID降序排列
    [dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSDecimalNumber* n1 = [NSDecimalNumber decimalNumberWithString:[[[obj1 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject]];
        NSDecimalNumber* n2 = [NSDecimalNumber decimalNumberWithString:[[[obj2 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject]];
        return [n2 compare:n1];
    })];
    return dataArray;
}

/*
 *  (public) 高精度计算模式控制，控制四舍五入以及小数点精度等。
 */
+ (NSDecimalNumberHandler*)decimalHandler:(NSRoundingMode)round_mode scale:(short)scale
{
    return [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:round_mode
                                                                  scale:scale
                                                       raiseOnExactness:NO
                                                        raiseOnOverflow:NO
                                                       raiseOnUnderflow:NO
                                                    raiseOnDivideByZero:NO];
}

+ (NSDecimalNumberHandler*)decimalHandlerRoundUp:(short)scale
{
    return [self decimalHandler:NSRoundUp scale:scale];
}

+ (NSDecimalNumberHandler*)decimalHandlerRoundDown:(short)scale
{
    return [self decimalHandler:NSRoundDown scale:scale];
}

@end
