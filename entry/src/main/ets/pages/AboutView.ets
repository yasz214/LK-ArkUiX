import router from '@ohos.router';
import { Constants } from '../common/Constants';
import bundleManager from '@ohos.bundle.bundleManager';
import common from '@ohos.app.ability.common';
import { openUrl } from '../utils/BrowserHelper';

@Entry
@Component
struct AboutView {
  @State realVersionName: string = '读取中...';

  aboutToAppear() {
    this.getAppVersion();
  }

  async getAppVersion() {
    try {
      let bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
      let bundleInfo = await bundleManager.getBundleInfoForSelf(bundleFlags);
      this.realVersionName = bundleInfo.versionName;
    } catch (err) {
      console.error('获取应用版本号失败', err);
      this.realVersionName = Constants.VER_NAME;
    }
  }

  private openQQLink() {
    let ctx = getContext(this) as common.UIAbilityContext;
    
    openUrl('tencent://message/?uin=2140303919&Site=qq&Menu=yes', ctx);
  }

  build() {
    Column() {
      
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor([Constants.TEXT_PRIMARY])
        }
        .width(44).height(44).justifyContent(FlexAlign.Center).margin({ left: 8 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => router.back())

        Text("关于").fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ right: 52 })
      }
      .width('100%').height(64).padding({ top: 20 })

      Column() {
        
        Stack() {
          Image($r('app.media.background'))
            .width('100%').height('100%').objectFit(ImageFit.Cover)
          Image($r('app.media.foreground'))
            .width('100%').height('100%').objectFit(ImageFit.Contain)
        }
        .width(80).height(80)
        .borderRadius(18)
        .clip(true)
        .margin({ bottom: 16 })
        .shadow({ radius: 12, color: 'rgba(0,0,0,0.08)', offsetY: 4 })

        Text("轻之国度")
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)

        Text(`Version ${this.realVersionName}`)
          .fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ top: 8 })
      }
      .margin({ top: 60, bottom: 60 }).alignItems(HorizontalAlign.Center)

      
      List({ space: 12 }) {
        ListItem() {
          Row() {
            Text("开发及维护").fontSize(16).fontColor(Constants.TEXT_PRIMARY).layoutWeight(1)
            Text("yasz123").fontSize(14).fontColor(Constants.TEXT_SECONDARY)
          }
          .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
        }

        ListItem() {
          Row() {
            Text("作者QQ").fontSize(16).fontColor(Constants.TEXT_PRIMARY).layoutWeight(1)
            Text("2140303919").fontSize(14).fontColor('#1890FF')
              .decoration({ type: TextDecorationType.Underline, color: '#1890FF' })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .onClick(() => this.openQQLink())
          }
          .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
        }

        ListItem() {
          Row() {
            Text("免责声明").fontSize(16).fontColor(Constants.TEXT_PRIMARY).layoutWeight(1)
            Text("仅供交流学习，严禁商用").fontSize(14).fontColor(Constants.TEXT_SECONDARY)
          }
          .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
        }
      }
      .padding({ left: 16, right: 16 }).width('100%')
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
