import { Constants } from '../common/Constants';
import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { UserInfoData, NotifyUnreadData, UserProfileData } from '../models/DataModels';
import { NovelRepository } from '../repository/NovelRepository';
import { PreferenceManager } from '../utils/PreferenceManager';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ProfileView';
const DOMAIN = 0x0001;

@Component
export struct ProfileView {
  @StorageLink('security_key') securityKey: string = '';
  @StorageLink('userInfo') userInfo: UserInfoData | null = null;
  @State isLoadingProfile: boolean = false;
  @State unreadData: NotifyUnreadData | null = null;
  @State profileData: UserProfileData | null = null;

  private onAuthChanged: (key: string) => void = (key: string) => {
    this.securityKey = key;
    this.loadProfile();
  };

  aboutToAppear() {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      ctx.eventHub.on('auth_state_changed', this.onAuthChanged);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'EventHub registration failed');
    }

    let key = AppStorage.get<string>('security_key');
    if (!this.securityKey && key) {
      this.securityKey = key;
    }

    PreferenceManager.getString('security_key', '').then((diskKey: string) => {
      if (diskKey && diskKey !== '' && !this.securityKey) {
        this.securityKey = diskKey;
        AppStorage.setOrCreate('security_key', diskKey);
      }
      this.loadProfile();
    }).catch(() => {
      this.loadProfile();
    });
  }

  aboutToDisappear() {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      ctx.eventHub.off('auth_state_changed', this.onAuthChanged);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'EventHub unregister failed');
    }
  }

  async loadProfile() {
    if (this.securityKey) {
      
      if (!this.userInfo || !this.profileData) {
        let cachedUserInfoStr = '';
        let cachedProfileStr = '';
        try {
          cachedUserInfoStr = await PreferenceManager.getString('userInfo', '');
          cachedProfileStr = await PreferenceManager.getString('profileData', '');
        } catch (e) {}

        if (!this.userInfo && cachedUserInfoStr) {
          try {
            this.userInfo = JSON.parse(cachedUserInfoStr);
          } catch(e) {}
        }
        if (!this.profileData && cachedProfileStr) {
          try {
            this.profileData = JSON.parse(cachedProfileStr) as UserProfileData;
          } catch(e) {}
        }

        if (!this.userInfo && !cachedUserInfoStr) {
          this.isLoadingProfile = true;
        }
      }

      try {
        let newData = await NovelRepository.getUserInfo();
        this.userInfo = newData;
        PreferenceManager.putString('userInfo', JSON.stringify(newData));
      } catch (e) {
        hilog.error(DOMAIN, TAG, '加载用户信息失败');
      } finally {
        this.isLoadingProfile = false;
      }

      
      this.loadFullProfile();
      
      this.loadUnread();
    } else {
      this.userInfo = null;
      this.unreadData = null;
      this.profileData = null;
      PreferenceManager.putString('userInfo', '');
    }
  }

  async loadFullProfile() {
    try {
      let uid = this.extractUid();
      if (uid > 0) {
        
        
        let freshData = await NovelRepository.getUserProfile(uid);
        this.profileData = freshData;
        
        PreferenceManager.putString('profileData', JSON.stringify(freshData));
      }
    } catch (e) {}
  }

  private extractUid(): number {
    let key = AppStorage.get<string>('security_key') || '';
    let parts = key.split(':');
    if (parts.length >= 2) {
      return parseInt(parts[1]);
    }
    return 0;
  }

  async loadUnread() {
    try {
      this.unreadData = await NovelRepository.getNotifyUnread();
    } catch (e) {}
  }

  private getTotalUnread(): number {
    if (!this.unreadData) return 0;
    return (this.unreadData.reply ? this.unreadData.reply.count : 0)
      + (this.unreadData.sys_msg ? this.unreadData.sys_msg.count : 0)
      + (this.unreadData.guild ? this.unreadData.guild.count : 0);
  }

  
  private extractCoin(user: UserInfoData): number {
    try {
      if (!user.balance) return 0;
      let n = Number(user.balance.coin);
      if (!isNaN(n) && n > 0) return n;
      let str = JSON.stringify(user.balance);
      let marker = '"coin":';
      let idx = str.indexOf(marker);
      if (idx >= 0) {
        let start = idx + marker.length;
        let end = str.indexOf(',', start);
        if (end < 0) end = str.indexOf('}', start);
        if (end > start) {
          let parsed = Number(str.substring(start, end));
          if (!isNaN(parsed)) return parsed;
        }
      }
    } catch (e) {}
    return 0;
  }

  private getExpProgress(): number {
    if (!this.profileData || !this.profileData.level) return 0;
    let currentExp = this.profileData.level.exp;
    let nextExp = this.profileData.level.next_exp;
    let currentLevelExp = 0;
    let levelExps: number[] = [0, 0, 251, 1001, 2001, 4501, 8001, 12501, 18001, 50001];
    let lvl = this.profileData.level.level;
    if (lvl >= 0 && lvl < levelExps.length) {
      currentLevelExp = levelExps[lvl];
    }
    if (nextExp <= currentLevelExp) return 1;
    let progress = (currentExp - currentLevelExp) / (nextExp - currentLevelExp);
    return Math.max(0, Math.min(1, progress));
  }

  private navigateToSelfProfile() {
    let uid = this.extractUid();
    if (uid > 0) {
      router.pushUrl({
        url: 'pages/UserProfileView',
        params: { uid: uid, isSelf: true }
      }).catch(() => {});
    }
  }

  build() {
    Scroll() {
      Column() {
        Text("我的")
          .fontSize(28).fontWeight(FontWeight.Bolder).fontColor(Constants.TEXT_PRIMARY)
          .margin({ top: 88, left: 24, bottom: 24 }).width('100%').textAlign(TextAlign.Start)

        
      Row() {
        Row() {
          if (this.userInfo && this.userInfo.avatar) {
            Image(this.userInfo.avatar).width(64).height(64).borderRadius(32).objectFit(ImageFit.Cover)
          } else {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
              .fontSize(48).fontColor([this.securityKey ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY])
          }
        }
        .width(64).height(64).borderRadius(32)
        .backgroundColor(this.securityKey ? Constants.THEME_TINT_BG : Constants.PLACEHOLDER_BG)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text(this.userInfo ? this.userInfo.nickname : (this.securityKey ? "加载中..." : "点击登录 / 注册"))
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)

          
          if (this.userInfo) {
            Row() {
              if (this.userInfo.uid > 0) {
                Text(`UID: ${this.userInfo.uid}`)
                  .fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(Constants.THEME_TINT_BG).borderRadius(6)
                  .margin({ right: 8 })
              }
              if (this.userInfo.level) {
                Text(`Lv.${this.userInfo.level.level} ${this.userInfo.level.name}`)
                  .fontSize(12).fontColor(Constants.THEME_COLOR)
              }
            }.margin({ top: 4 })
          } else {
            Text("登录后同步阅读历史与书架")
              .fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ top: 6 })
          }

          
          if (this.userInfo && this.userInfo.balance) {
            Row() {
              Row() {
                Text('¥').fontSize(9).fontColor(Color.White).fontWeight(FontWeight.Bold)
              }.width(16).height(16).borderRadius(8)
              .backgroundColor(Constants.THEME_COLOR)
              .justifyContent(FlexAlign.Center)
              .margin({ right: 5 })
              Text(`${this.extractCoin(this.userInfo)} 轻币`)
                .fontSize(12).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
            }.margin({ top: 4 }).alignItems(VerticalAlign.Center)
          }
        }
        .margin({ left: 16 }).alignItems(HorizontalAlign.Start).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
      }
      .width('100%').padding(20).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(20)
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.03)', offsetY: 4 })
      .margin({ left: 16, right: 16, bottom: 12 })
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
      .onClick(() => {
        if (!this.securityKey) {
          router.pushUrl({ url: 'pages/AuthView' }).catch(() => {});
        } else {
          this.navigateToSelfProfile();
        }
      })

      
      if (this.profileData && this.profileData.level) {
        Column() {
          Row() {
            Text(`Lv.${this.profileData.level.level} ${this.profileData.level.name}`)
              .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Constants.THEME_COLOR)
            Blank()
            Text(`${this.profileData.level.exp} / ${this.profileData.level.next_exp}`)
              .fontSize(11).fontColor(Constants.TEXT_SECONDARY)
          }.width('100%')

          Stack({ alignContent: Alignment.Start }) {
            Row().width('100%').height(6).borderRadius(3)
              .backgroundColor(Constants.EXP_BAR_BG)
            Row().width(`${this.getExpProgress() * 100}%`).height(6).borderRadius(3)
              .backgroundColor(Constants.THEME_COLOR)
          }.width('100%').height(6).margin({ top: 6 })
        }
        .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
        .backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
        .margin({ left: 16, right: 16, bottom: 24 })
      } else {
        Row().height(12) 
      }

      
      List({ space: 12 }) {
        
        if (this.securityKey) {
          ListItem() {
            Row() {
              SymbolGlyph($r('sys.symbol.bell')).fontSize(20).fontColor([Constants.THEME_COLOR]).margin({ right: 12 })
              Text("消息中心").fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY).layoutWeight(1)
              if (this.getTotalUnread() > 0) {
                Text(`${this.getTotalUnread()}`)
                  .fontSize(11).fontColor(Color.White).fontWeight(FontWeight.Bold)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(12).backgroundColor('#FF3B30')
                  .margin({ right: 8 })
              }
              SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
            }
            .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
            .onClick(() => router.pushUrl({ url: 'pages/MessageCenterView' }).catch(() => {}))
          }
        }

        ListItem() {
          Row() {
            SymbolGlyph($r('sys.symbol.clock')).fontSize(20).fontColor([Constants.THEME_COLOR]).margin({ right: 12 })
            Text("阅读历史").fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY).layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
          }
          .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
          .onClick(() => router.pushUrl({ url: 'pages/HistoryView' }).catch(() => {}))
        }

        ListItem() {
          Row() {
            SymbolGlyph($r('sys.symbol.bookmark')).fontSize(20).fontColor([Constants.THEME_COLOR]).margin({ right: 12 })
            Text("我的收藏").fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY).layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
          }
          .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
          .onClick(() => router.pushUrl({ url: 'pages/CollectionView' }).catch(() => {}))
        }

        ListItem() {
          Row() {
            SymbolGlyph($r('sys.symbol.gearshape')).fontSize(20).fontColor([$r('app.color.text_secondary')]).margin({ right: 12 })
            Text("设置").fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY).layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
          }
          .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
          .onClick(() => router.pushUrl({ url: 'pages/Settings' }).catch(() => {}))
        }

        ListItem() {
          Row() {
            SymbolGlyph($r('sys.symbol.info_circle')).fontSize(20).fontColor([$r('app.color.text_secondary')]).margin({ right: 12 })
            Text("关于").fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY).layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
          }
          .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
          .onClick(() => router.pushUrl({ url: 'pages/AboutView' }).catch(() => {}))
        }

        if (this.securityKey) {
          ListItem() {
            Row() {
              Text("退出登录").fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.Red).layoutWeight(1).textAlign(TextAlign.Center)
            }
            .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
            .onClick(() => {
              promptAction.showDialog({
                title: '退出登录',
                message: '确定要退出当前账号吗？',
                buttons: [
                  { text: '取消', color: Constants.DIALOG_CANCEL },
                  { text: '退出', color: '#FF0000' }
                ]
              }).then(data => {
                if (data.index === 1) {
                  AppStorage.setOrCreate('security_key', '');
                  AppStorage.setOrCreate('userInfo', null);
                  PreferenceManager.putString('security_key', '');
                  PreferenceManager.putString('userInfo', '');

                  try {
                    let ctx = getContext(this) as common.UIAbilityContext;
                    ctx.eventHub.emit('auth_state_changed', '');
                  } catch (e) {}

                  promptAction.openToast({ message: '已安全退出登录' });
                }
              }).catch(() => {});
            })
          }.margin({ top: 12 })
        }
        }.padding({ left: 16, right: 16, bottom: 40 }).width('100%')

        
        Row().height(140)
      }
      .width('100%')
    }
    .scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
  }
}
