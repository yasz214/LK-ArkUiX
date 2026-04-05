import { HomeView } from './HomeView';
import { CategoryView } from './CategoryView';
import { DynamicView } from './DynamicView';
import { ProfileView } from './ProfileView';
import { Constants } from '../common/Constants';
import { curves } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import { NovelRepository } from '../repository/NovelRepository';
import { PreferenceManager } from '../utils/PreferenceManager';
import { PreloadEngine } from '../utils/PreloadEngine';
import { CheckInResult } from '../models/DataModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'IndexPage';
const DOMAIN = 0x0001;

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  
  @State indicatorPos: number = 0;
  @State tabsWidth: number = 360;
  private tabsController: TabsController = new TabsController();

  
  
  @StorageLink('security_key') securityKey: string = '';

  
  @State showCheckInDialog: boolean = false;
  @State checkInCoin: number = 0;
  @State checkInExp: number = 0;
  @State checkInDialogScale: number = 0.6;
  @State checkInDialogOpacity: number = 0;

  
  private onAuthChanged: (key: string) => void = (key: string) => {
    this.securityKey = key;
    if (key) {
      this.syncDataInBackground();
    } else {
      
      PreferenceManager.putString('cache_history', '[]');
      PreferenceManager.putString('cache_collection', '[]');
    }
  };

  aboutToAppear() {
    
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      ctx.eventHub.on('auth_state_changed', this.onAuthChanged);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'EventHub registration failed');
    }

    this.initGlobalSettings();
    this.syncDataInBackground();

    
    PreloadEngine.init();

    
    this.autoCheckIn();
  }

  
  onPageShow() {
    hilog.info(DOMAIN, TAG, 'onPageShow 触发');
    let latestKey = AppStorage.get<string>('security_key') ?? '';
    hilog.info(DOMAIN, TAG, 'AppStorage key长度=%{public}d, 本地key长度=%{public}d', latestKey.length, this.securityKey.length);

    if (latestKey !== this.securityKey) {
      hilog.info(DOMAIN, TAG, '检测到 key 变化，触发 onAuthChanged');
      this.securityKey = latestKey;
      this.onAuthChanged(latestKey);
    }

    
    PreferenceManager.getString('security_key', '').then((diskKey: string) => {
      hilog.info(DOMAIN, TAG, '磁盘 key长度=%{public}d', diskKey.length);
      if (diskKey && diskKey !== '' && diskKey !== this.securityKey) {
        hilog.info(DOMAIN, TAG, '磁盘 key 与内存不一致！用磁盘值修复');
        AppStorage.setOrCreate('security_key', diskKey);
        this.securityKey = diskKey;
        this.onAuthChanged(diskKey);
      } else if (!diskKey && this.securityKey) {
        hilog.info(DOMAIN, TAG, '磁盘已清空，清除内存 key');
        AppStorage.setOrCreate('security_key', '');
        this.securityKey = '';
        this.onAuthChanged('');
      }
    }).catch(() => {});
  }

  async initGlobalSettings() {
    
    
    let savedKey = await PreferenceManager.getString('security_key', '');
    if (savedKey) {
      AppStorage.setOrCreate('security_key', savedKey);
    }

    
    let isAutoSimp = await PreferenceManager.getBoolean('autoSimp', true);

    
    AppStorage.setOrCreate('autoSimp', !isAutoSimp);

    
    
    setTimeout(() => {
      AppStorage.setOrCreate('autoSimp', isAutoSimp);
    }, 150);
  }

  
  async autoCheckIn() {
    
    setTimeout(async () => {
      try {
        let key = AppStorage.get<string>('security_key');
        if (!key) {
          hilog.info(DOMAIN, TAG, '[签到] 未登录，跳过');
          return;
        }
        let result: CheckInResult = await NovelRepository.dailyCheckIn();
        hilog.info(DOMAIN, TAG, '[签到] %{public}s', result.message);
        if (result.success) {
          
          this.checkInCoin = result.coin;
          this.checkInExp = result.exp;
          this.showCheckInDialog = true;
          
          animateTo({ duration: 400, curve: curves.springMotion(0.6, 0.9) }, () => {
            this.checkInDialogScale = 1;
            this.checkInDialogOpacity = 1;
          });
        }
      } catch (e) {
        hilog.error(DOMAIN, TAG, '[签到] 异常');
      }
    }, 2000);
  }

  private getFormattedTime(): string {
    let d = new Date();
    let y = d.getFullYear();
    let m = (d.getMonth() + 1).toString().padStart(2, '0');
    let day = d.getDate().toString().padStart(2, '0');
    let h = d.getHours().toString().padStart(2, '0');
    let min = d.getMinutes().toString().padStart(2, '0');
    let s = d.getSeconds().toString().padStart(2, '0');
    return `${y}/${m}/${day} ${h}:${min}:${s}`;
  }

  async syncDataInBackground() {
    
    
    try {
      let key = AppStorage.get<string>('security_key');
      if (key) {
        let now = this.getFormattedTime();
        let history = await NovelRepository.getHistory();
        PreferenceManager.putString('cache_history', JSON.stringify(history));
        PreferenceManager.putString('time_history', now);

        let collections = await NovelRepository.getCollections();
        PreferenceManager.putString('cache_collection', JSON.stringify(collections));
        PreferenceManager.putString('time_collection', now);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '后台同步拉取失败');
    }
  }

  
  private isTabActive(targetIndex: number): boolean {
    
    let nearest = Math.round(this.indicatorPos);
    return nearest === targetIndex;
  }

  @Builder TabBuilder(title: string, targetIndex: number, symbolId: Resource, selectedSymbolId: Resource) {
    Column() {
      SymbolGlyph(this.isTabActive(targetIndex) ? selectedSymbolId : symbolId)
        .fontSize(24)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor(this.isTabActive(targetIndex) ? [Constants.THEME_COLOR] : [$r('app.color.tabbar_fg')])
        .margin({ bottom: 4 })
        .scale({ x: this.isTabActive(targetIndex) ? 1.1 : 1, y: this.isTabActive(targetIndex) ? 1.1 : 1 })
        .animation({ duration: 250, curve: curves.springMotion() })

      Text(title)
        .fontSize(10)
        .fontColor(this.isTabActive(targetIndex) ? Constants.THEME_COLOR : $r('app.color.text_secondary'))
        .fontWeight(this.isTabActive(targetIndex) ? FontWeight.Medium : FontWeight.Normal)
        .animation({ duration: 200 })
    }
    .layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.tabsController.changeIndex(targetIndex);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
        TabContent() {
          HomeView({ switchTab: (idx: number) => {
            this.currentIndex = idx;
            this.tabsController.changeIndex(idx);
          }})
        }
        TabContent() { CategoryView({ switchTab: (idx: number) => {
          this.currentIndex = idx;
          this.tabsController.changeIndex(idx);
        }}) }
        TabContent() { DynamicView() }
        TabContent() { ProfileView() }
      }
      
      
      .scrollable(this.currentIndex !== 1)
      .animationDuration(300)
      .barHeight(0)
      
      .onGestureSwipe((index: number, extraInfo: TabsAnimationEvent) => {
        let progress = extraInfo.currentOffset / this.tabsWidth;
        this.indicatorPos = index - progress;
      })
      .onAnimationStart((_index: number, targetIndex: number) => {
        this.currentIndex = targetIndex;
        
        animateTo({ duration: 350, curve: curves.springMotion(0.35, 0.8) }, () => {
          this.indicatorPos = targetIndex;
        });
      })
      .onChange((index: number) => {
        this.currentIndex = index;
        this.indicatorPos = index;
      })
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        let w = newArea.width;
        if (typeof w === 'number') {
          this.tabsWidth = w;
        }
      })
      .width('100%').height('100%')

      Stack({ alignContent: Alignment.Start }) {
        Stack() {
          Row().width(68).height(52).backgroundColor(Constants.EXP_BAR_BG).borderRadius(26)
        }
        .width('25%').height('100%')
        .translate({ x: `${this.indicatorPos * 100}%` })
        .animation({ duration: 350, curve: curves.springMotion(0.32, 0.78) })

        Row() {
          this.TabBuilder('首页', 0, $r('sys.symbol.house'), $r('sys.symbol.house_fill'))
          this.TabBuilder('分区', 1, $r('sys.symbol.square_grid_2x2'), $r('sys.symbol.square_fill_grid_2x2'))
          this.TabBuilder('动态', 2, $r('sys.symbol.rectangle_on_rectangle'), $r('sys.symbol.rectangle_on_rectangle_fill'))
          this.TabBuilder('我的', 3, $r('sys.symbol.person'), $r('sys.symbol.person_fill'))
        }.width('100%').height('100%')
      }
      .width('86%').height(72).margin({ bottom: 28 }).borderRadius(36)
      .backgroundColor($r('app.color.acrylic_tint')).backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
      .shadow({ radius: 32, color: Constants.EXP_BAR_BG, offsetY: 12 })

      
      if (this.showCheckInDialog) {
        Stack({ alignContent: Alignment.Center }) {
          
          Column()
            .width('100%').height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.45)')
            .onClick(() => {
              animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
                this.checkInDialogScale = 0.6;
                this.checkInDialogOpacity = 0;
              });
              setTimeout(() => {
                this.showCheckInDialog = false;
              }, 280);
            })

          
          Column() {
            
            Text('🎉')
              .fontSize(52)
              .margin({ top: 28 })

            Text('签到成功!')
              .fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor(Constants.TEXT_PRIMARY)
              .margin({ top: 12 })

            
            Row() {
              
              Column() {
                Text(`${this.checkInCoin}`)
                  .fontSize(28).fontWeight(FontWeight.Bold)
                  .fontColor(Constants.THEME_COLOR)
                  .margin({ top: 4 })
                Text('铜币')
                  .fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)

              
              Column()
                .width(1).height(50)
                .backgroundColor(Constants.THEME_TINT_BG_STRONG)

              
              Column() {
                Text(`${this.checkInExp}`)
                  .fontSize(28).fontWeight(FontWeight.Bold)
                  .fontColor('#FF9500')
                  .margin({ top: 4 })
                Text('经验')
                  .fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 24, bottom: 20 })

            
            Text('知道了')
              .fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('80%').height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(Constants.THEME_COLOR)
              .borderRadius(22)
              .margin({ bottom: 24 })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .onClick(() => {
                animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
                  this.checkInDialogScale = 0.6;
                  this.checkInDialogOpacity = 0;
                });
                setTimeout(() => {
                  this.showCheckInDialog = false;
                }, 280);
              })
          }
          .width('78%')
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(24)
          .alignItems(HorizontalAlign.Center)
          .shadow({ radius: 40, color: 'rgba(0, 0, 0, 0.2)', offsetY: 12 })
          .scale({ x: this.checkInDialogScale, y: this.checkInDialogScale })
          .opacity(this.checkInDialogOpacity)
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}