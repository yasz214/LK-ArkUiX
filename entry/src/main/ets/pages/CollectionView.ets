import router from '@ohos.router';
import { Constants } from '../common/Constants';
import { HistoryItem } from '../models/DataModels';
import { NovelRepository } from '../repository/NovelRepository';
import { T2SEngine } from '../utils/T2SEngine';
import { PreferenceManager } from '../utils/PreferenceManager';
import { PreloadEngine } from '../utils/PreloadEngine';

@Entry
@Component
struct CollectionView {
  @State list: HistoryItem[] = [];
  @State isLoading: boolean = true;
  @State isError: boolean = false;
  @StorageLink('autoSimp') autoSimp: boolean = true;
  @StorageLink('topBarExtraHeight') topBarExtraHeight: number = 0;
  @State isLoggedIn: boolean = false;

  @State isUpdating: boolean = false;
  @State isRefreshing: boolean = false;
  @State refreshState: RefreshStatus = RefreshStatus.Inactive;
  @State lastUpdateTime: string = '';
  @State currentPage: number = 1;
  @State hasMore: boolean = false;
  @State isLoadingMore: boolean = false;

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

  private preloadCollectionItems(items: HistoryItem[]) {
    let count = 0;
    for (let i = 0; i < items.length && count < 8; i++) {
      if (items[i].aid > 0) {
        PreloadEngine.enqueue(items[i].aid, 0);
        count++;
      }
    }
  }

  async loadData(isRefresh: boolean = false) {
    if (!isRefresh) {
      this.isLoading = true;
      let cache = await PreferenceManager.getString('cache_collection', '');
      let time = await PreferenceManager.getString('time_collection', '');
      if (cache) {
        try {
          let parsed: Object = JSON.parse(cache);
          this.list = parsed as HistoryItem[];
          this.preloadCollectionItems(this.list);
          this.isLoading = false;
          this.isError = false;
        } catch(e) {}
      }
      if (time) this.lastUpdateTime = time;
    }

    this.isUpdating = true;
    try {
      let res = await NovelRepository.getCollectionsPage(1);
      this.list = res.list;
      this.preloadCollectionItems(res.list);
      this.currentPage = res.page_info.cur > 0 ? res.page_info.cur : 1;
      this.hasMore = res.page_info.has_next === 1;
      this.isError = false;
      let now = this.getFormattedTime();
      this.lastUpdateTime = now;
      PreferenceManager.putString('cache_collection', JSON.stringify(res.list));
      PreferenceManager.putString('time_collection', now);
    } catch (e) {
      if (this.list.length === 0) this.isError = true;
    } finally {
      this.isUpdating = false;
      this.isLoading = false;
    }
  }

  async loadMore() {
    if (this.isLoadingMore || this.isUpdating || !this.hasMore) return;
    this.isLoadingMore = true;
    try {
      let nextPage = this.currentPage + 1;
      let res = await NovelRepository.getCollectionsPage(nextPage);
      if (res.list.length > 0) {
        let merged: HistoryItem[] = [];
        for (let i = 0; i < this.list.length; i++) {
          merged.push(this.list[i]);
        }
        for (let i = 0; i < res.list.length; i++) {
          merged.push(res.list[i]);
        }
        this.list = merged;
        this.preloadCollectionItems(res.list);
        PreferenceManager.putString('cache_collection', JSON.stringify(merged));
      }
      this.currentPage = res.page_info.cur > 0 ? res.page_info.cur : nextPage;
      this.hasMore = res.page_info.has_next === 1;
    } catch (e) {
    } finally {
      this.isLoadingMore = false;
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

            if (this.hasMore || this.isLoadingMore) {
              ListItem() {
                Row() {
                  if (this.isLoadingMore) {
                    LoadingProgress().width(16).height(16).color(Constants.THEME_COLOR).margin({ right: 8 })
                    Text('加载中...').fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                  } else {
                    Text('加载更多').fontSize(14).fontColor(Constants.THEME_COLOR)
                  }
                }
                .width('100%').justifyContent(FlexAlign.Center).padding({ top: 16, bottom: 16 })
                .onClick(() => {
                  this.loadMore();
                })
              }
              .onAppear(() => {
                this.loadMore();
              })
            } else {
              ListItem() {
                Text('没有更多了').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                  .width('100%').textAlign(TextAlign.Center).padding({ top: 12, bottom: 12 })
              }
            }
          }
          .width('100%').height('100%').padding({ left: 16, right: 16, bottom: 16 }).edgeEffect(EdgeEffect.Spring)
          .onReachEnd(() => {
            this.loadMore();
          })
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
