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
import { CheckInResult, HistoryItem } from '../models/DataModels';
import { SessionStore } from '../common/SessionStore';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAmbientLightColors } from '../utils/ImmersiveLightHelper';

const TAG = 'IndexPage';
const DOMAIN = 0x0001;

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  
  @StorageLink('isActualDarkMode') isActualDarkMode: boolean = false;
  
  @StorageLink('navbarTransparency') navbarTransparency: number = 40;
  @StorageLink('navbarBlurRadius') navbarBlurRadius: number = 30;
  
  @State indicatorPos: number = 0;
  @State tabsWidth: number = 360;
  private tabsController: TabsController = new TabsController();

  
  
  @StorageLink('security_key') securityKey: string = '';

  
  @State showCheckInDialog: boolean = false;
  @State checkInCoin: number = 0;
  @State checkInExp: number = 0;
  @State checkInDialogScale: number = 0.6;
  @State checkInDialogOpacity: number = 0;

  
  @State showFirstUseGuide: boolean = false;
  @State guideTopBarValue: number = 0;
  @State guideDialogScale: number = 0.6;
  @State guideDialogOpacity: number = 0;

  private toHexByte(value: number): string {
    let clamped = Math.round(value);
    if (clamped > 255) clamped = 255;
    if (clamped < 0) clamped = 0;
    let hex = clamped.toString(16).toUpperCase();
    if (hex.length < 2) {
      return '0' + hex;
    }
    return hex;
  }

  
  private get navbarBgColor(): string {
    let opacity = 1 - this.navbarTransparency / 100;
    if (opacity > 1) opacity = 1;
    if (opacity < 0) opacity = 0;
    let alphaHex = this.toHexByte(opacity * 255);
    if (this.isActualDarkMode) {
      return `#${alphaHex}0B0E14`;
    }
    return `#${alphaHex}FFFFFF`;
  }

  
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

    
    this.checkFirstUseGuide();
  }

  
  aboutToDisappear() {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      ctx.eventHub.off('auth_state_changed', this.onAuthChanged);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'EventHub unregistration failed');
    }
  }

  
  onPageShow() {
    hilog.info(DOMAIN, TAG, 'onPageShow 触发');
    let latestKey = AppStorage.get<string>('security_key') ?? '';

    if (latestKey !== this.securityKey) {
      hilog.info(DOMAIN, TAG, '检测到 key 变化，触发 onAuthChanged');
      this.securityKey = latestKey;
      this.onAuthChanged(latestKey);
    }
  }

  async initGlobalSettings() {
    
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      await SessionStore.init(ctx);
    } catch (e) {
      
      let savedKey = await PreferenceManager.getString('security_key', '');
      if (savedKey) {
        AppStorage.setOrCreate('security_key', savedKey);
      }
      let isAutoSimp = await PreferenceManager.getBoolean('autoSimp', true);
      AppStorage.setOrCreate('autoSimp', isAutoSimp);
    }
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

  
  async checkFirstUseGuide() {
    let guideDone = await PreferenceManager.getBoolean('firstUseGuideDone', false);
    if (!guideDone) {
      
      setTimeout(() => {
        this.guideTopBarValue = AppStorage.get<number>('topBarExtraHeight') ?? 0;
        this.showFirstUseGuide = true;
        animateTo({ duration: 400, curve: curves.springMotion(0.6, 0.9) }, () => {
          this.guideDialogScale = 1;
          this.guideDialogOpacity = 1;
        });
      }, 1500);
    }
  }

  private dismissFirstUseGuide() {
    
    let value = Math.round(this.guideTopBarValue);
    AppStorage.setOrCreate('topBarExtraHeight', value);
    PreferenceManager.putNumber('topBarExtraHeight', value);
    PreferenceManager.putBoolean('firstUseGuideDone', true);

    animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
      this.guideDialogScale = 0.6;
      this.guideDialogOpacity = 0;
    });
    setTimeout(() => {
      this.showFirstUseGuide = false;
    }, 280);
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
        this.preloadItems(history);

        let collections = await NovelRepository.getCollections();
        PreferenceManager.putString('cache_collection', JSON.stringify(collections));
        PreferenceManager.putString('time_collection', now);
        this.preloadItems(collections);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '后台同步拉取失败');
    }
  }

  private preloadItems(items: HistoryItem[]) {
    let count = 0;
    for (let i = 0; i < items.length && count < 8; i++) {
      if (items[i].aid > 0) {
        PreloadEngine.enqueue(items[i].aid, 0);
        count++;
      }
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
      
      Column()
        .width('100%').height('100%')
        .linearGradient({
          direction: GradientDirection.Top,
          colors: getAmbientLightColors(this.isActualDarkMode)
        })
        .hitTestBehavior(HitTestMode.None)

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
        
        Row()
          .width('100%').height('100%')
          .backgroundColor(this.navbarBgColor)
          .blur(this.navbarBlurRadius)
        
        Stack() {
          
          Row()
            .width(68).height(52)
            .backgroundColor(Constants.THEME_COLOR)
            .borderRadius(26)
            .opacity(0.15)
        }
        .width('25%').height('100%')
        .translate({ x: `${this.indicatorPos * 100}%` })
        .animation({ duration: 350, curve: curves.springMotion(0.32, 0.78) })
        .hitTestBehavior(HitTestMode.None)

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
      .width('86%').height(72).margin({ bottom: 28 }).borderRadius(36).clip(true)
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
                Text('轻币')
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

      
      if (this.showFirstUseGuide) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%').height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')

          Column() {
            Text('欢迎使用')
              .fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor(Constants.TEXT_PRIMARY)
              .margin({ top: 28 })

            Text('部分设备的状态栏可能与部分页面顶栏重叠。\n请拖动下方滑块调节顶栏间距，直到预览效果合适。')
              .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
              .textAlign(TextAlign.Center)
              .margin({ top: 12, left: 20, right: 20 })

            
            Column() {
              Row()
                .width('100%').height(20 + this.guideTopBarValue)
                .backgroundColor(Constants.THEME_TINT_BG_STRONG)
                .borderRadius({ topLeft: 8, topRight: 8 })
              Row() {
                SymbolGlyph($r('sys.symbol.chevron_left'))
                  .fontSize(16).fontColor([Constants.TEXT_PRIMARY])
                  .margin({ left: 8 })
                Text('标题栏预览').fontSize(14).fontColor(Constants.TEXT_PRIMARY)
                  .layoutWeight(1).textAlign(TextAlign.Center).margin({ right: 24 })
              }
              .width('100%').height(36)
              .backgroundColor(Constants.CARD_BG_COLOR)
              .borderRadius({ bottomLeft: 8, bottomRight: 8 })
            }
            .width('80%').borderRadius(8).margin({ top: 16 })
            .border({ width: 1, color: Constants.DIVIDER_COLOR })
            .clip(true)

            Row() {
              Text(`${Math.round(this.guideTopBarValue)} vp`)
                .fontSize(13).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                .width(50)
              Slider({
                value: this.guideTopBarValue,
                min: 0,
                max: 50,
                step: 2,
                style: SliderStyle.OutSet
              })
                .layoutWeight(1)
                .trackColor(Constants.PLACEHOLDER_BG)
                .selectedColor(Constants.THEME_COLOR)
                .blockColor(Constants.THEME_COLOR)
                .onChange((value: number) => {
                  this.guideTopBarValue = value;
                })
            }
            .width('80%').alignItems(VerticalAlign.Center).margin({ top: 12 })

            Text('此设置不影响“我的”页面，可在 设置 → 外观设置 中随时修改')
              .fontSize(11).fontColor(Constants.TEXT_SECONDARY)
              .margin({ top: 8 })

            Text('完成')
              .fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('70%').height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(Constants.THEME_COLOR)
              .borderRadius(22)
              .margin({ top: 16, bottom: 24 })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .onClick(() => {
                this.dismissFirstUseGuide();
              })
          }
          .width('82%')
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(24)
          .alignItems(HorizontalAlign.Center)
          .shadow({ radius: 40, color: 'rgba(0, 0, 0, 0.2)', offsetY: 12 })
          .scale({ x: this.guideDialogScale, y: this.guideDialogScale })
          .opacity(this.guideDialogOpacity)
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
