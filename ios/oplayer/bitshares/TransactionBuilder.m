//
//  TransactionBuilder.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "TransactionBuilder.h"
#import "GrapheneWebSocket.h"
#import "ChainObjectManager.h"
#import "BitsharesClientManager.h"
#import "GrapheneSerializer.h"
#import "GrapheneConnectionManager.h"
#import "OrgUtils.h"
#import "WalletManager.h"
#import "WsPromise.h"

@interface TransactionBuilder()
{
    uint16_t                _ref_block_num;         //  [序列化]
    uint32_t                _ref_block_prefix;      //  [序列化]
    time_point_sec          _expiration;            //  [序列化]
    NSMutableArray*         _operations;            //  [序列化]   operation
    NSMutableArray*         _extensions;            //  [序列化]   REMARK:未来扩展用
    
    NSMutableArray*         _signatures;            //  [序列化]   签名
    
    NSMutableDictionary*    _signPubKeys;           //  该交易需要参与签名的公钥列表。REMARK：大部分都是手续费支付账号的资金公钥。
    NSMutableDictionary*    _pubPriKeysHash;        //  特殊私钥列表，部分交易需要（隐私转账等）。KEY -> public key  VALUE -> WIF private key
    
    BOOL                    _signed;                //  是否签名过了
    NSData*                 _tr_buffer;
}
@end

@implementation TransactionBuilder

- (id)init
{
    self = [super init];
    if (self)
    {
        _ref_block_num = 0;
        _ref_block_prefix = 0;
        _expiration = 0;
        _operations = [NSMutableArray array];
        _extensions = [NSMutableArray array];
        
        _signatures = [NSMutableArray array];
        
        _signPubKeys = [NSMutableDictionary dictionary];
        _pubPriKeysHash = [NSMutableDictionary dictionary];
        
        _signed = NO;
        _tr_buffer = nil;
    }
    
    return self;
}

/**
 *  交易ID：取 tr_buffer 的 sha256 摘要的16进制编码后字符串的前40字节。
 */
- (NSString*)transaction_id
{
    unsigned char digest32[32];
    sha256([_tr_buffer bytes], [_tr_buffer length], digest32);
    
    unsigned char hexdigest32[64];
    hex_encode(digest32, sizeof(digest32), hexdigest32);
    
    return [[NSString alloc] initWithBytes:hexdigest32 length:40 encoding:NSUTF8StringEncoding];
}

- (void)addSignKey:(NSString*)pubKey
{
    assert(pubKey);
    [_signPubKeys setObject:@YES forKey:pubKey];
}

- (void)addSignKeys:(NSArray*)pubKeyList
{
    assert(pubKeyList);
    for (id pubKey in pubKeyList) {
        [_signPubKeys setObject:@YES forKey:pubKey];
    }
}

/*
 *  (public) 添加签名用私钥，部分交易可能需要非钱包中的额外的私钥进行签名。
 */
- (void)addSignPrivateKey:(NSString*)wifPrivateKey
{
    assert(wifPrivateKey);
    id pubKey = [OrgUtils genBtsAddressFromWifPrivateKey:wifPrivateKey];
    if (pubKey) {
        [_pubPriKeysHash setObject:wifPrivateKey forKey:pubKey];
    }
}

- (void)add_operation:(EBitsharesOperations)opcode opdata:(id)opdata
{
    [_operations addObject:@[@(opcode), [opdata mutableCopy]]];
}

- (WsPromise*)set_required_fees:(NSString*)asset_id removeDuplicates:(BOOL)removeDuplicates
{
    NSMutableArray* feeAssets = [NSMutableArray array];
    for (NSArray* op_pair in _operations) {
        id fee = [[op_pair objectAtIndex:1] objectForKey:@"fee"];
        //  REMARK：手动设置了fee则跳过了 不用查询了。
        if ([[fee objectForKey:@"amount"] unsignedLongLongValue] != 0) {
            continue;
        }
        id fee_asset_id = [fee objectForKey:@"asset_id"];
        if (![feeAssets containsObject:fee_asset_id]){
            [feeAssets addObject:fee_asset_id];
        }
    }
    if ([feeAssets count] <= 0) {
        //  直接跳过
        return [WsPromise resolve:nil];
    }
    
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] last_connection].api_db;
    
    //  1、获取allfees的promise
    id first_fee_asset_id = [feeAssets firstObject];
    return [[api exec:@"get_required_fees" params:@[[self operations_to_object], first_fee_asset_id]] then:^id(id all_op_fee_array) {
        assert([all_op_fee_array isKindOfClass:[NSArray class]]);
        
        //  更新所有OP的手续费
        [all_op_fee_array ruby_each_with_index:^(id op_fee_item, NSInteger idx) {
            //  REMARK：如果OP为提案类型，这里会把提案的手续费以及提案中对应的所有实际OP的手续费全部返回。（因此需要判断。）
            if ([op_fee_item isKindOfClass:[NSArray class]]){
                //  仅第一个手续费对象是提案本身的的手续。
                op_fee_item = [op_fee_item firstObject];
            }
            assert([op_fee_item isKindOfClass:[NSDictionary class]]);
            //  更新 first: opcode last: opdata
            [[[_operations objectAtIndex:idx] lastObject] setObject:op_fee_item forKey:@"fee"];
        }];
        
        //  返回所有OP的手续费
        return all_op_fee_array;
    }];
}

/**
 *  (privage) 交易签名
 */
- (void)sign
{
    if (_signed){
        return;
    }
    
    //  检查数据有效性
    if (!_tr_buffer){
        [WsPromiseException throwException:@"not finalized"];
    }
    
    //  没有签名KEY
    if (_signPubKeys.count == 0){
        [WsPromiseException throwException:@"Transaction was not signed. Do you have a private key? [no_signers]"];
    }
    
    //  TODO:动态判断该交易需要哪些签名。
    
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    
    unsigned char output[32];
    
    hex_decode((unsigned char*)[[ChainObjectManager sharedChainObjectManager].grapheneChainID UTF8String], sizeof(output)*2, output);
    
    NSMutableData* sign_buffer = [NSMutableData data];
    [sign_buffer appendBytes:output length:sizeof(output)];
    [sign_buffer appendData:_tr_buffer];
    
    id sig_array = [walletMgr signTransaction:sign_buffer signKeys:[_signPubKeys allKeys] extra_keys:_pubPriKeysHash];
    if (!sig_array){
        //  TODO:fowallet 在提交请求的瞬间 钱包锁定了？？请求中，禁止锁定钱包功能添加。
        assert(![walletMgr isLocked]);
        
        [WsPromiseException throwException:@"sign failed"];
    }
    [_signatures addObjectsFromArray:sig_array];
    
    //  设置标记
    _signed = YES;
}
/**
 *  (private) 冻结交易数据，准备广播。
 */
- (WsPromise*)finalize
{
    if (_tr_buffer){
        [WsPromiseException throwException:@"already finalized"];
    }
    
    //  获取区块链数据
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] last_connection].api_db;
    id p = [api exec:@"get_objects" params:@[@[BTS_DYNAMIC_GLOBAL_PROPERTIES_ID]]];
    return [p then:(^id(id data) {
        data = [data firstObject];
        NSLog(@"%@", data);
        //{
        //    "accounts_registered_this_interval" = 7;
        //    "current_aslot" = 27722626;
        //    "current_witness" = "1.6.101";
        //    "dynamic_flags" = 0;
        //    "head_block_id" = 01a4b8178efe734b80a1f356e3a479a137bfab16;
        //    "head_block_number" = 27572247;
        //    id = "2.1.0";
        //    "last_budget_time" = "2018-06-04T13:00:00";
        //    "last_irreversible_block_num" = 27572230;
        //    "next_maintenance_time" = "2018-06-04T14:00:00";
        //    "recent_slots_filled" = 340282366920938444573908675953187356671;
        //    "recently_missed_count" = 0;
        //    time = "2018-06-04T13:03:57";
        //    "witness_budget" = 112500000;
        //}
        //  1、过期时间戳设置
        NSTimeInterval head_block_sec = [OrgUtils parseBitsharesTimeString:[data objectForKey:@"time"]];
        NSTimeInterval now_sec = ceil([[NSDate date] timeIntervalSince1970]);
        
        NSTimeInterval base_expiration_sec;
        // The head block time should be updated every 3 seconds.  If it isn't
        // then help the transaction to expire (use head_block_sec)
        if (now_sec - head_block_sec > 30) {
            base_expiration_sec = head_block_sec;
        }else{
            //  If the user's clock is very far behind, use the head block time.
            //  max(now_sec, head_block_sec)
            base_expiration_sec = now_sec > head_block_sec ? now_sec : head_block_sec;
        }
        
        _expiration = (uint32_t)(base_expiration_sec + BTS_CHAIN_EXPIRE_IN_SECS);
        
        //  2、更新 _ref_block_num
        _ref_block_num = [[data objectForKey:@"head_block_number"] integerValue] & 0xffff;
        
        //  3、更新 _ref_block_prefix
        id head_block_id = [data objectForKey:@"head_block_id"];
        unsigned char output[20];   //  20=len/2
        hex_decode((const unsigned char*)[head_block_id UTF8String], (size_t)[head_block_id length], output);
        _ref_block_prefix = *(uint32_t*)&output[4];  //  REMARK：偏移4字节。   readUInt32LE(4)
        
        //  4、序列化
        id opdata = @{
            @"ref_block_num":@(_ref_block_num),
            @"ref_block_prefix":@(_ref_block_prefix),
            @"expiration":@(_expiration),
            @"operations":_operations,
            @"extensions":_extensions
        };
        _tr_buffer = [T_transaction encode_to_bytes:opdata];
        
        return data;
    })];
}

/**
 *  (private) 广播交易 核心
 */
- (WsPromise*)broadcast_core:(BOOL)broadcast_to_blockchain
{
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        //  1、签名
        [self sign];
        
        //  检测各种参数有效性
        assert(_tr_buffer);
        if (!_tr_buffer){
            [WsPromiseException throwException:@"not finalized"];
        }
        
        assert([_signatures count] > 0);
        if ([_signatures count] == 0){
            [WsPromiseException throwException:@"not signed"];
        }
        
        assert([_operations count] > 0);
        if ([_operations count] == 0){
            [WsPromiseException throwException:@"no operations"];
        }
        
        //  2、获取需要广播的json对象（包含签名信息）
        id opdata = @{
            @"ref_block_num":@(_ref_block_num),
            @"ref_block_prefix":@(_ref_block_prefix),
            @"expiration":@(_expiration),
            @"operations":_operations,
            @"extensions":_extensions,
            @"signatures":_signatures,
        };
        id obj = [T_signed_transaction encode_to_object:opdata];
        
        if (broadcast_to_blockchain) {
            //  3、执行广播请求
            WsNotifyCallback cc = ^(BOOL success, id data){
                if (success){
                    //  TODO:fowallet 一定要确保在网络异常的情况下也要回调该callback，否则这里会卡死。
                    NSLog(@"broadcast_transaction_with_callback submit callback = %@", data);
                    resolve(data);
                }else{
                    reject(@"websocket error.");
                }
                //  回调之后删除 callback
                return YES;
            };
            GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] last_connection].api_net;
            [[[api exec:@"broadcast_transaction_with_callback" params:@[cc, obj]] then:(^id(id data) {
                //  广播成功，等待网络通知执行 cc 回调。
                NSLog(@"broadcast_transaction_with_callback response: %@", data);
                return data;
            })] catch:(^id(id error) {
                //  TODO:fowallet error
                reject(error);
                return nil;
            })];
        } else {
            //  直接返回待广播的数据
            resolve(obj);
        }
    }];
}

/**
 *  广播交易到区块链网络
 */
- (WsPromise*)broadcast:(BOOL)broadcast_to_blockchain
{
    if (_tr_buffer){
        return [self broadcast_core:broadcast_to_blockchain];
    }else{
        return [[self finalize] then:(^id(id data) {
            return [self broadcast_core:broadcast_to_blockchain];
        })];
    }
}

/**
 *  (private) 所有 operation 转换为 object 对象。
 */
- (id)operations_to_object
{
    NSMutableArray* ary = [NSMutableArray array];
    for (id ops in _operations) {
        [ary addObject:[T_operation encode_to_object:ops]];
    }
    return [ary copy];
}

@end
