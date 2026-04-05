import router from '@ohos.router';
import { Constants } from '../common/Constants';
import { HistoryItem } from '../models/DataModels';
import { NovelRepository } from '../repository/NovelRepository';
import { T2SEngine } from '../utils/T2SEngine';
import { PreferenceManager } from '../utils/PreferenceManager';

@Entry
@Component
struct CollectionView {
  @State list: HistoryItem[] = [];
  @State isLoading: boolean = true;
  @State isError: boolean = false;
  @StorageLink('autoSimp') autoSimp: boolean = true;
  @State isLoggedIn: boolean = false;

  @State isUpdating: boolean = false;
  @State isRefreshing: boolean = false;
  @State refreshState: RefreshStatus = RefreshStatus.Inactive;
  @State lastUpdateTime: string = '';

  aboutToAppear() {
    let key = AppStorage.get<string>('security_key') || '';
    this.isLoggedIn = key.length > 0;
    if (this.isLoggedIn) {
      this.loadData();
    } else {
      this.isLoading = false;
    }
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

  async loadData(isRefresh: boolean = false) {
    if (!isRefresh) {
      this.isLoading = true;
      let cache = await PreferenceManager.getString('cache_collection', '');
      let time = await PreferenceManager.getString('time_collection', '');
      if (cache) {
        try {
          this.list = JSON.parse(cache);
          this.isLoading = false;
          this.isError = false;
        } catch(e) {}
      }
      if (time) this.lastUpdateTime = time;
    }

    this.isUpdating = true;
    try {
      let res = await NovelRepository.getCollections();
      this.list = res;
      this.isError = false;
      let now = this.getFormattedTime();
      this.lastUpdateTime = now;
      PreferenceManager.putString('cache_collection', JSON.stringify(res));
      PreferenceManager.putString('time_collection', now);
    } catch (e) {
      if (this.list.length === 0) this.isError = true;
    } finally {
      this.isUpdating = false;
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor([Constants.TEXT_PRIMARY])
        }
        .width(44).height(44).justifyContent(FlexAlign.Center).margin({ left: 8 })
        .onClick(() => router.back())
        Text("我的收藏").fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({right: 52})
      }.width('100%').height(64)

      if (!this.isLoggedIn) {
        Column() {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(48).fontColor([Constants.TEXT_SECONDARY]).margin({ bottom: 16 })
          Text('请先登录').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
            .margin({ bottom: 8 })
          Text('登录后即可查看收藏列表').fontSize(14).fontColor(Constants.TEXT_SECONDARY)
            .margin({ bottom: 24 })
          Button('去登录').width(140).height(40).borderRadius(20)
            .backgroundColor(Constants.THEME_COLOR)
            .onClick(() => router.pushUrl({ url: 'pages/AuthView' }).catch(() => {}))
        }.width('100%').margin({ top: 120 }).alignItems(HorizontalAlign.Center)
      } else if (this.isLoading && !this.isRefreshing) {
        LoadingProgress().width(40).height(40).margin({ top: 100 }).color(Constants.THEME_COLOR)
      } else if (this.isError && this.list.length === 0) {
        Column() {
          Text('网络连接失败，请检查您的网络').fontSize(15).margin({ bottom: 20 }).fontColor(Constants.TEXT_SECONDARY)
          Button('重新加载').width(140).height(40).borderRadius(20)
            .backgroundColor(Constants.THEME_COLOR)
            .onClick(() => this.loadData())
        }.width('100%').margin({ top: 140 }).alignItems(HorizontalAlign.Center)
      } else if (this.list.length === 0) {
        Text("暂无收藏").fontColor(Constants.TEXT_SECONDARY).margin({ top: 100 })
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ space: 16 }) {
            ListItem() {
              Row() {
                if (this.isUpdating || this.isRefreshing || this.refreshState === RefreshStatus.Refresh) {
                  LoadingProgress().width(12).height(12).color(Constants.THEME_COLOR).margin({right: 6})
                  Text("正在同步...").fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                } else if (this.refreshState === RefreshStatus.OverDrag) {
                  Text("松手可刷新").fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                } else if (this.lastUpdateTime) {
                  Text(`同步于 ${this.lastUpdateTime}`).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                }
              }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 4, bottom: 4 })
            }

            ForEach(this.list, (item: HistoryItem) => {
              ListItem() {
                Row() {
                  Image(item.cover).width(60).height(80).borderRadius(8).objectFit(ImageFit.Cover)
                  Column() {
                    Text(this.autoSimp ? T2SEngine.convert(item.title) : item.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY).maxLines(2)
                    Blank()
                    Text(`收藏时间: ${item.last_time || item.time || '未知'}`).fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                  }
                  .layoutWeight(1).height(80).alignItems(HorizontalAlign.Start).margin({ left: 16 }).padding({ top: 4, bottom: 4 })
                }
                .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                .onClick(() => {
                  if (item.sid && item.sid !== 0) {
                    router.pushUrl({ url: 'pages/CollectionDetailView', params: { sid: item.sid, title: item.title } }).catch(() => {});
                  } else {
                    router.pushUrl({ url: 'pages/ArticleDetail', params: { aid: item.aid } }).catch(() => {});
                  }
                })
              }
              
            }, (item: HistoryItem) => `${item.aid}_${item.title}`)
          }
          .width('100%').height('100%').padding({ left: 16, right: 16, bottom: 16 }).edgeEffect(EdgeEffect.Spring)
        }
        .width('100%').layoutWeight(1)
        .onStateChange((state: RefreshStatus) => { this.refreshState = state; })
        .onRefreshing(async () => {
          await this.loadData(true);
          this.isRefreshing = false;
        })
      }
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}