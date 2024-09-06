//
//  WalletManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>
#import "AppCacheManager.h"
#import "GraphenePrivateKey.h"

/**
 *  钱包中存在的私钥对指定权限状态枚举。
 */
typedef enum EAccountPermissionStatus
{
    EAPS_NO_PERMISSION = 0,         //  无任何权限
    EAPS_PARTIAL_PERMISSION,        //  有部分权限
    EAPS_ENOUGH_PERMISSION,         //  有足够的权限
    EAPS_FULL_PERMISSION,           //  有所有权限
} EAccountPermissionStatus;

/**
 *  导入钱包结果
 */
typedef enum EImportToWalletStatus
{
    EITWS_OK = 0,                   //  导入成功
    EITWS_NO_PERMISSION,            //  无任何权限
    EITWS_PARTIAL_PERMISSION,       //  有部分权限
} EImportToWalletStatus;

@interface WalletManager : NSObject

/**
 *  创建安全的随机字节(16进制返回，结果为64字节。)
 */
+ (NSString*)secureRandomByte32Hex;

/**
 *  (public) 创建安全的随机字节
 */
+ (NSData*)secureRandomByte32;

/**
 *  (public) 随机生成私钥
 */
+ (NSString*)randomPrivateKeyWIF;

/**
 *  (public) 【静态方法】判断给定私钥列表对于指定权限的状态（足够、部分、完整、无权限）。（active权限、owner权限）
 */
+ (EAccountPermissionStatus)calcPermissionStatus:(NSDictionary*)raw_permission_json privateKeysHash:(NSDictionary*)privateKeyHash;

/**
 *  (public)【静态方法】判断给定的密钥列表是否足够授权指定权限（active权限、owner权限）
 */
+ (BOOL)canAuthorizeThePermission:(NSDictionary*)raw_permission_json privateKeysHash:(NSDictionary*)privateKeyHash;

+ (WalletManager*)sharedWalletManager;

/**
 *  (public) 判断指定帐号是否是登录帐号自身。自己的帐号返回 YES，他人的帐号返回 NO。
 */
- (BOOL)isMyselfAccount:(NSString*)account_name;
- (BOOL)isWalletExist;
/**
 *  (public) 是否缺少完整的帐号信息，在注册的时候低概率注册成功，但获取帐号信息失败了。
 */
- (BOOL)isMissFullAccountData;
/**
 *  (public) 获取本地钱包信息
 */
- (NSDictionary*)getWalletInfo;

- (EWalletMode)getWalletMode;
/**
 *  (public) 导入的帐号是否是密码模式导入的
 */
- (BOOL)isPasswordMode;
/**
 *  (public) 获取钱包中当前活跃账号名和账号信息。
 */
- (NSDictionary*)getWalletAccountInfo;
- (NSString*)getWalletAccountName;
- (BOOL)isLocked;

/**
 *  (public) 创建新钱包。
 *  current_full_account_data   - 钱包当前账号  REMARK：创建后的当前账号，需要有完整的active权限。
 *  pub_pri_keys_hash           - 需要导入的私钥Hash
 *  append_memory_key           - 导入内存中已经存在的私钥 REMARK：需要钱包已解锁。
 *  extra_account_name_list     - 除了当前账号外的其他需要同时导入的账号名。
 *  pWalletPassword             - 新钱包的密码。
 *  login_mode                  - 模式。
 *  login_desc                  - 描述信息。
 */
- (EImportToWalletStatus)createNewWallet:(NSDictionary*)current_full_account_data
                             import_keys:(NSDictionary*)pub_pri_keys_hash
                       append_memory_key:(BOOL)append_memory_key
                 extra_account_name_list:(NSArray*)extra_account_name_list
                         wallet_password:(NSString*)pWalletPassword
                              login_mode:(EWalletMode)login_mode
                              login_desc:(NSString*)login_desc;

/*
 *  (public) 注销登录逻辑。内存钱包锁定、导入钱包删除。
 */
- (void)processLogout;

/**
 *  (public) 锁定和解锁帐号
 */
- (void)Lock;
- (NSDictionary*)unLock:(NSString*)password;
/**
 *  (public) 刷新解锁信息（仅针对钱包模式）
 */
- (NSDictionary*)reUnlock;

/**
 *  (public) 获取所有账号，并以“name”或者“id“作为KEY构造Hash返回。
 */
- (NSMutableDictionary*)getAllAccountDataHash:(BOOL)hashKeyIsName;

/**
 *  获取钱包中所有账号名字列表。（仅有一个主账号。）
 */
- (NSArray*)getWalletAccountNameList;

/**
 *  (public) 获取当前钱包中有完整"指定"权限的所有账号列表。REMARK：如果列表为空(所有账号都没权限)，则全部返回。
 */
- (NSArray*)getFeePayingAccountList:(BOOL)requireActivePermission;

/*
 *  (public) 获取石墨烯私钥对象。
 */
- (GraphenePrivateKey*)getGraphenePrivateKeyByPublicKey:(NSString*)wif_public_key;

/**
 *  是否存在指定公钥的私钥对象。
 */
- (BOOL)havePrivateKey:(NSString*)publicKey;

/**
 *  (public) 判断指定权限是否需要多签。
 */
+ (BOOL)isMultiSignPermission:(id)raw_permission_json;

/**
 *  (public) 判断指定账号否需要多签。
 */
+ (BOOL)isMultiSignAccount:(NSDictionary*)account_data;

/**
 *  (public) 提取账号数据中所有公钥数据。
 */
+ (NSMutableDictionary*)getAllPublicKeyFromAccountData:(NSDictionary*)account_data result:(NSMutableDictionary*)result;

/*
 *  (public) 获取本地钱包中需要参与【指定权限、active或owner等】签名的必须的 公钥列表。
 *  assert_enough_permission - 是否检查拥有完整私钥权限。
 */
- (NSArray*)getSignKeys:(NSDictionary*)raw_permission_json assert_enough_permission:(BOOL)assert_enough_permission;
- (NSArray*)getSignKeys:(NSDictionary*)raw_permission_json;

/**
 *  根据手续费支付账号ID获取本地钱包中需要参与签名的 公钥列表。
 */
- (NSArray*)getSignKeysFromFeePayingAccount:(NSString*)fee_paying_account;
- (NSArray*)getSignKeysFromFeePayingAccount:(NSString*)fee_paying_account requireOwnerPermission:(BOOL)requireOwnerPermission;

/**
 *  是否有足够的权限状态判断。（本地钱包中的私钥是否足够签署交易，否则视为提案交易。）
 */
- (EAccountPermissionStatus)calcPermissionStatus:(NSDictionary*)raw_permission_json;

/**
 *  本地钱包的密钥是否足够授权指定权限（active权限、owner权限）
 */
- (BOOL)canAuthorizeThePermission:(NSDictionary*)raw_permission_json;

/**
 *  (public) 用一组私钥签名交易。成功返回签名数据的数组，失败返回 nil。
 */
- (NSArray*)signTransaction:(NSData*)sign_buffer signKeys:(NSArray*)pubKeyList;
- (NSArray*)signTransaction:(NSData*)sign_buffer signKeys:(NSArray*)pubKeyList extra_keys:(NSDictionary*)extra_keys_hash;

/*
 *  (public) 解密memo数据，失败返回nil。
 */
- (NSString*)decryptMemoObject:(NSDictionary*)memo_object;

/**
 *  (public) 加密并生成 memo 信息结构体，失败返回 nil。
 */
- (NSDictionary*)genMemoObject:(NSString*)memo_string from_public:(NSString*)from_public to_public:(NSString*)to_public;
- (NSDictionary*)genMemoObject:(NSString*)memo_string
                   from_public:(NSString*)from_public
                     to_public:(NSString*)to_public
                    extra_keys:(NSDictionary*)extra_keys_hash;

#pragma mark- for wallet manager

/**
 *  (public) 加载完成钱包文件
 */
- (NSDictionary*)loadFullWalletFromHex:(NSString*)hex_wallet_bin wallet_password:(NSString*)wallet_password;
- (NSDictionary*)loadFullWallet:(NSData*)wallet_bin wallet_password:(NSString*)wallet_password;

/**
 *  (public) 在当前“已解锁”的钱包中移除账号和私钥数据。
 */
- (NSData*)walletBinRemoveAccount:(NSString*)accountName pubkeyList:(NSArray*)pubkeyList;

/**
 *  (public) 在当前“已解锁”的钱包中导入账号or私钥数据。REMARK：如果导入的账号名已经存在则设置为当前账号。
 */
- (NSData*)walletBinImportAccount:(NSString*)accountName privateKeyWifList:(NSArray*)privateKeyWifList;

/**
 *  创建完整钱包对象。
 *  直接返回二进制bin。
 */
- (NSData*)genFullWalletData:(id)account_name_or_namelist
            private_wif_keys:(NSArray*)private_wif_keys
             wallet_password:(NSString*)wallet_password;

/**
 *  (public) 创建完整钱包对象。
 */
- (NSDictionary*)genFullWalletObject:(NSArray*)account_name_list
                    private_wif_keys:(NSArray*)private_wif_keys
                     wallet_password:(NSString*)wallet_password;

/**
 *  (public) 格式化时间戳为BTS官方钱包中的日期格式。格式：2018-07-15T01:45:19.731Z。
 */
- (NSString*)genWalletTimeString:(NSTimeInterval)time_secs;

/**
 *  (public) 根据脑密钥单词字符串生成对应的WIF格式私钥（脑密钥字符串作为seed）。
 */
- (NSString*)genBrainKeyPrivateWIF:(NSString*)brainKeyPlainText;

/**
 *  (public) 根据脑密钥单词字符串 和 HD子密钥索引编号 生成WIF格式私钥。REMARK：sha512(brainKey + " " + seq)作为seed。
 */
+ (NSString*)genPrivateKeyFromBrainKey:(NSString*)brainKeyPlainText sequence:(NSInteger)sequence;

/**
 *  (public) 随机生成脑密钥
 */
- (NSString*)suggestBrainKey;

/**
 *  (public) 归一化脑密钥，按照不可见字符切分字符串，然后用标准空格连接。
 */
+ (NSString*)normalizeBrainKey:(NSString*)brainKey;

/**
 *  (public) 辅助 - Aes256加密，并返回16进制字符串，密钥 seed。
 */
- (NSString*)auxAesEncryptToHex:(NSData*)seed data:(NSData*)data;

/**
 *  (public) 辅助 - Aes256解密，输入16进制字符串，密钥 seed。
 */
- (NSData*)auxAesDecryptFromHex:(NSData*)seed data:(NSString*)hexdata;

/*
 *  (public) 随机生成 32 个英文字符列表
 *  check_sum_prefix - 可在助记词中添加4个字符的校验码（check_sum_prefix会参与校验码计算。用于区分不同用途的助记词，比如密码用，隐私账户用。）
 */
+ (NSArray*)randomGenerateEnglishWord_N32:(NSString*)check_sum_prefix;

/*
 *  (public) 随机生成 16 个中文汉字列表
 *  check_sum_prefix - 可在助记词中添加2个汉字的校验码（check_sum_prefix会参与校验码计算。用于区分不同用途的助记词，比如密码用，隐私账户用。）
 */
+ (NSArray*)randomGenerateChineseWord_N16:(NSString*)check_sum_prefix;

/*
 *  (public) 是否是有效的隐私交易（隐私账户）助记词。
 */
+ (BOOL)isValidStealthTransferBrainKey:(NSString*)brain_key check_sum_prefix:(NSString*)check_sum_prefix;

@end
