//
//  ViewFaceCell.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "ViewFaceCell.h"
#import "WalletManager.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "UIImage+Template.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewFaceCell()
{
    __weak UIViewController*  _owner;       //  REMARK：声明为 weak，否则会导致循环引用。
    
    CGFloat         _bannerImageW;
    CGFloat         _bannerImageH;
    CGFloat         _bannerNormalHeight;    //  REMARK：banner静止时显示的尺寸高度
    CGFloat         _bannerDragHeight;      //  拖拽高度应该是静止显示高度的一半，顶部和底部各移动一半。
    
    UIImageView*    _banner;
    
    UIButton*       _btnLock;               //  锁
    
    UIImageView*    _pFaceIcon;
    UILabel*        _lbName;
    UILabel*        _lbUserName;
    UILabel*        _vipTs;
}

@end

@implementation ViewFaceCell

- (void)dealloc
{
    _owner = nil;
    _banner = nil;
    _btnLock = nil;
}

- (id)initWithOwner:(UIViewController*)vc
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.hideTopLine = YES;
        self.hideBottomLine = YES;
        
        self.backgroundColor = [UIColor clearColor];
        
        _owner = vc;
        
        //  banner
        UIImage* bannerImage = [UIImage imageNamed:@"banner_center"];
        _bannerImageW = [[UIScreen mainScreen] bounds].size.width;
        _bannerImageH = _bannerImageW * bannerImage.size.height / bannerImage.size.width;
        _bannerNormalHeight = _bannerImageH / 3.0f;     //  REMARK：实际显示区域为图片等 三分之一，750的高度的话就是250。
        _bannerDragHeight = _bannerNormalHeight / 2.0f;
        _banner = [[UIImageView alloc] initWithImage:bannerImage];
        _banner.contentMode = UIViewContentModeScaleAspectFill;
        _banner.frame = CGRectMake(0, -_bannerDragHeight, _bannerImageW, _bannerNormalHeight + _bannerDragHeight);
        _banner.clipsToBounds = YES;
        
        _banner.hidden = YES;//TODO:fowallet 图片考虑取消，用背景图。！！！重要
        
        [self.contentView addSubview:_banner];
        
        //  锁&解锁按钮
        _btnLock = [UIButton buttonWithType:UIButtonTypeSystem];
        _btnLock.tintColor = [ThemeManager sharedThemeManager].textColorMain;
        _btnLock.userInteractionEnabled = YES;
        [_btnLock addTarget:self action:@selector(onLockButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_btnLock];
        
        //  头像
        _pFaceIcon = [[UIImageView alloc] initWithImage:[UIImage templateImageNamed:@"iconAvatar"]];
        _pFaceIcon.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
        [self.contentView addSubview:_pFaceIcon];
        
        //  人名 or 未登录
        _lbName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbName.numberOfLines = 1;
        _lbName.backgroundColor = [UIColor clearColor];
        _lbName.font = [UIFont boldSystemFontOfSize:15];
        [self.contentView addSubview:_lbName];
        
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        //  用户名
        _lbUserName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbUserName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbUserName.numberOfLines = 1;
        _lbUserName.backgroundColor = [UIColor clearColor];
        _lbUserName.font = [UIFont systemFontOfSize:13];
        [self.contentView addSubview:_lbUserName];
    }
    return self;
}

- (void)onLockButtonClicked:(UIButton*)sender
{
    if (sender.isHidden) {
        return;
    }
    if (_owner && [_owner respondsToSelector:@selector(onLockButtonClicked:)]){
        [_owner performSelector:@selector(onLockButtonClicked:) withObject:sender];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (NSInteger)getMaxDragHeight
{
    return (NSInteger)_bannerNormalHeight;
}

- (void)refreshBackgroundOffset:(NSInteger)offset
{
    //  REMARK：向上拉banner不产生变化。
    if (offset > 0){
        offset = 0;
    }
    
    CGFloat half_offset = offset / 2;
//    if (-_bannerDragHeight + half_offset > 0){
//        NSLog(@"error");
//    }
    _banner.frame = CGRectMake(0, -_bannerDragHeight + half_offset, _bannerImageW, _bannerNormalHeight + _bannerDragHeight - half_offset);
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    _lbName.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _lbUserName.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    if (![walletMgr isWalletExist])
    {
        _lbName.text = NSLocalizedString(@"kAccountManagement", @"帐号管理");
        _lbUserName.text = NSLocalizedString(@"tip_click_to_login", @"点此登录");
        _btnLock.hidden = YES;
    }
    else
    {
        _btnLock.hidden = NO;
        id wallet_info = [[walletMgr getWalletAccountInfo] objectForKey:@"account"];
        if ([walletMgr isLocked]){
            [_btnLock setImage:[UIImage templateImageNamed:@"iconLocked"] forState:UIControlStateNormal];
        }else{
            [_btnLock setImage:[UIImage templateImageNamed:@"iconUnlocked"] forState:UIControlStateNormal];
        }
        _lbName.text = [walletMgr getWalletAccountName];
        if ([OrgUtils isBitsharesVIP:[wallet_info objectForKey:@"membership_expiration_date"]]){
            _lbUserName.text = [NSString stringWithFormat:@"%@%@",
                                NSLocalizedString(@"kLblMembership", @"状态："), NSLocalizedString(@"kLblMembershipLifetime", @"终身会员")];
        }else{
            _lbUserName.text = [NSString stringWithFormat:@"%@%@",
                                NSLocalizedString(@"kLblMembership", @"状态："), NSLocalizedString(@"kLblMembershipBasic", @"普通会员")];
        }
    }
    
    CGFloat statusBarH      = [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    //  设置frame
    CGSize faceSize         = _pFaceIcon.bounds.size;
    _pFaceIcon.frame        = CGRectMake(self.textLabel.frame.origin.x,
                                         statusBarH + (_bannerNormalHeight - faceSize.height - statusBarH) / 2.0f,
                                         faceSize.width,
                                         faceSize.height);
    
    CGFloat fTextOffsetX    = _pFaceIcon.frame.origin.x + faceSize.width + 12;
    CGFloat fWidth          = self.frame.size.width;
        
    //  44是2行的总高度 64是3行多高度
    CGFloat fTextOffsetY = statusBarH + (_bannerNormalHeight - 44 - statusBarH) / 2.0f;
    _lbName.frame           = CGRectMake(fTextOffsetX, fTextOffsetY, fWidth, 24);
    _lbUserName.frame       = CGRectMake(fTextOffsetX, fTextOffsetY + 24, fWidth, 20);
    
    //  解锁按钮
    if (!_btnLock.isHidden) {
        CGFloat fBtnLockWidth = 22;
        CGSize size = [ViewUtils auxSizeWithLabel:_lbName];
        _btnLock.frame = CGRectMake(fTextOffsetX + size.width + 4, fTextOffsetY + (24 - fBtnLockWidth) / 2, fBtnLockWidth, fBtnLockWidth);
    }
    
}

@end
