import { Constants } from '../common/Constants';
import { NovelRepository } from '../repository/NovelRepository';
import { FollowedArticle, FollowedArticleResponse } from '../models/DataModels';
import { T2SEngine } from '../utils/T2SEngine';
import { PreloadEngine } from '../utils/PreloadEngine';
import { PreferenceManager } from '../utils/PreferenceManager';
import { FileLog } from '../utils/FileLog';
import router from '@ohos.router';

const TAG = 'DynamicView';


function formatRelativeTime(timeStr: string): string {
  if (!timeStr) return '';
  try {
    let timestamp = Date.parse(timeStr.replace(/-/g, '/'));
    if (isNaN(timestamp)) return '';
    let now = Date.now();
    let diffMs = now - timestamp;
    if (diffMs < 0) return '刚刚';

    let diffMin = Math.floor(diffMs / 60000);
    if (diffMin < 1) return '刚刚';
    if (diffMin < 60) return `${diffMin} 分钟前`;

    let diffHour = Math.floor(diffMin / 60);
    if (diffHour < 24) return `${diffHour} 小时前`;

    let diffDay = Math.floor(diffHour / 24);
    if (diffDay < 30) return `${diffDay} 天前`;

    let diffMonth = Math.floor(diffDay / 30);
    if (diffMonth < 12) return `${diffMonth} 个月前`;

    let diffYear = Math.floor(diffMonth / 12);
    return `${diffYear} 年前`;
  } catch (e) {
    return '';
  }
}


function formatCount(count: number): string {
  if (count >= 10000) {
    return (count / 10000).toFixed(1) + '万';
  }
  return count.toString();
}

@Component
struct DynamicArticleCard {
  @Prop article: FollowedArticle;
  @StorageLink('autoSimp') autoSimp: boolean = true;

  private displayText(text: string): string {
    return this.autoSimp ? T2SEngine.convert(text) : text;
  }

  build() {
    Column() {
      
      Row() {
        if (this.article.author.avatar) {
          Image(this.article.author.avatar)
            .width(36).height(36).borderRadius(18)
            .objectFit(ImageFit.Cover)
            .backgroundColor(Constants.PLACEHOLDER_BG)
        } else {
          Column() {
            Text(this.displayText(this.article.author.nickname).substring(0, 1))
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
          }
          .width(36).height(36).borderRadius(18)
          .backgroundColor(Constants.THEME_COLOR)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        }

        Column() {
          Row() {
            Text(this.displayText(this.article.author.nickname))
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            
            if (this.article.author.level && this.article.author.level.level > 0) {
              Text(`Lv.${this.article.author.level.level}`)
                .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4).backgroundColor(Constants.THEME_COLOR)
                .margin({ left: 6 })
            }
          }.width('100%')

          Text(formatRelativeTime(this.article.time))
            .fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
        }
        .margin({ left: 10 }).layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .width('100%').padding({ left: 16, right: 16, top: 14 })
      .onClick(() => {
        if (this.article.author.uid > 0) {
          router.pushUrl({
            url: 'pages/UserProfileView',
            params: { uid: this.article.author.uid }
          }).catch(() => {});
        }
      })

      
      Text(this.displayText(this.article.title))
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(24).letterSpacing(0.3)
        .width('100%').padding({ left: 16, right: 16, top: 10 })

      
      if (this.article.cover && this.article.cover_type === 1) {
        Image(this.article.cover)
          .width('100%').constraintSize({ maxHeight: 200 })
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
          .backgroundColor(Constants.PLACEHOLDER_BG)
          .margin({ top: 10, left: 16, right: 16 })
      } else if (this.article.banner) {
        Image(this.article.banner)
          .width('100%').constraintSize({ maxHeight: 200 })
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
          .backgroundColor(Constants.PLACEHOLDER_BG)
          .margin({ top: 10, left: 16, right: 16 })
      }

      
      Row() {
        if (this.article.group_name && this.article.group_name !== 'undefined') {
          Text(this.displayText(this.article.group_name))
            .fontSize(10).fontColor(Constants.THEME_COLOR)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4).backgroundColor(Constants.THEME_TINT_BG)
            .margin({ right: 8 })
        }
        if (this.article.series_name && this.article.series_name !== 'undefined') {
          Text(this.displayText(this.article.series_name))
            .fontSize(10).fontColor('#FF8C00')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4).backgroundColor('rgba(255, 140, 0, 0.08)')
            .margin({ right: 8 })
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 8 })

      
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.eye')).fontSize(14).fontColor([Constants.TEXT_SECONDARY]).margin({ right: 3 })
          Text(formatCount(this.article.hits)).fontSize(12).fontColor(Constants.TEXT_SECONDARY)
        }.margin({ right: 16 })

        Row() {
          Image($r('app.media.ic_comment')).width(14).height(14).fillColor(Constants.TEXT_SECONDARY).margin({ right: 3 })
          Text(formatCount(this.article.comments)).fontSize(12).fontColor(Constants.TEXT_SECONDARY)
        }.margin({ right: 16 })

        Row() {
          SymbolGlyph($r('sys.symbol.heart')).fontSize(14).fontColor([Constants.TEXT_SECONDARY]).margin({ right: 3 })
          Text(formatCount(this.article.likes)).fontSize(12).fontColor(Constants.TEXT_SECONDARY)
        }.margin({ right: 16 })

        Row() {
          SymbolGlyph($r('sys.symbol.star_fill')).fontSize(14).fontColor([Constants.TEXT_SECONDARY]).margin({ right: 3 })
          Text(formatCount(this.article.favorites)).fontSize(12).fontColor(Constants.TEXT_SECONDARY)
        }

        Blank()

        if (this.article.last_time && this.article.last_time !== this.article.time) {
          Text(`更新于 ${this.article.last_time.split(' ')[0]}`)
            .fontSize(10).fontColor(Constants.TEXT_SECONDARY)
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 14 })
    }
    .width('100%').backgroundColor(Constants.CARD_BG_COLOR)
    .borderRadius(16)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onAppear(() => {
      
      if (this.article.aid > 0) {
        PreloadEngine.enqueue(this.article.aid, 1);
      }
    })
    .onClick(() => {
      if (this.article.sid && this.article.sid > 0) {
        router.pushUrl({
          url: 'pages/CollectionDetailView',
          params: { sid: this.article.sid, title: this.article.title }
        }).catch(() => {});
      } else {
        router.pushUrl({
          url: 'pages/ArticleDetail',
          params: { aid: this.article.aid, tag: this.article.group_name || '' }
        }).catch(() => {});
      }
    })
  }
}

@Component
export struct DynamicView {
  @StorageLink('security_key') @Watch('onSecurityKeyChange') securityKey: string = '';
  @StorageLink('autoSimp') autoSimp: boolean = true;

  @State articles: FollowedArticle[] = [];
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State refreshState: RefreshStatus = RefreshStatus.Inactive;
  @State isLoadingMore: boolean = false;
  @State isEmpty: boolean = false;
  @State isError: boolean = false;
  @State errorMsg: string = '';

  
  private currentPage: number = 1;
  @State hasMore: boolean = false;
  private totalCount: number = 0;

  
  @State lastUpdateTime: string = '';
  @State isUpdating: boolean = false;
  private cacheKey: string = 'cache_dynamic_feed';
  private timeKey: string = 'time_dynamic_feed';

  aboutToAppear() {
    this.loadData();
  }

  onSecurityKeyChange() {
    
    this.articles = [];
    this.currentPage = 1;
    this.hasMore = false;
    this.loadData();
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
    if (!this.securityKey) {
      
      this.isLoading = false;
      this.isEmpty = true;
      return;
    }

    if (!isRefresh) {
      this.isLoading = true;
      this.isError = false;

      
      let cache = await PreferenceManager.getString(this.cacheKey, '');
      let time = await PreferenceManager.getString(this.timeKey, '');
      if (cache) {
        try {
          let cachedArticles = JSON.parse(cache) as FollowedArticle[];
          if (cachedArticles.length > 0) {
            this.articles = cachedArticles;
            this.isEmpty = false;
            this.isLoading = false;
            FileLog.i(TAG, `缓存加载: ${cachedArticles.length} 条`);
          }
        } catch (e) {}
      }
      if (time) this.lastUpdateTime = time;
    }

    this.isUpdating = true;
    try {
      this.currentPage = 1;
      let response: FollowedArticleResponse = await NovelRepository.getFollowedArticles(1, 20);
      let list = response.list;
      let pageInfo = response.page_info;

      this.articles = list;
      this.totalCount = pageInfo.count;
      this.hasMore = pageInfo.has_next === 1;
      this.isEmpty = list.length === 0;

      let now = this.getFormattedTime();
      this.lastUpdateTime = now;

      
      PreferenceManager.putString(this.cacheKey, JSON.stringify(list));
      PreferenceManager.putString(this.timeKey, now);

      FileLog.i(TAG, `动态加载: ${list.length} 条, total=${this.totalCount}, hasMore=${this.hasMore}`);
    } catch (e) {
      let err = e as Error;
      FileLog.e(TAG, `加载失败: ${err.message}`);
      if (this.articles.length === 0) {
        this.isError = true;
        this.errorMsg = '加载失败，请检查网络';
      }
    } finally {
      this.isLoading = false;
      this.isUpdating = false;
    }
  }

  async loadMore() {
    if (this.isLoadingMore || !this.hasMore) return;
    this.isLoadingMore = true;

    try {
      let nextPage = this.currentPage + 1;
      let response: FollowedArticleResponse = await NovelRepository.getFollowedArticles(nextPage, 20);

      for (let item of response.list) {
        this.articles.push(item);
      }
      this.currentPage = nextPage;
      this.hasMore = response.page_info.has_next === 1;

      FileLog.i(TAG, `加载更多: page=${nextPage}, 新增${response.list.length}条, 总计${this.articles.length}条`);
    } catch (e) {
      FileLog.e(TAG, `加载更多失败: ${(e as Error).message}`);
    } finally {
      this.isLoadingMore = false;
    }
  }

  build() {
    Column() {
      
      Row() {
        Text('动态').fontSize(20).fontWeight(FontWeight.Bolder).fontColor(Constants.TEXT_PRIMARY).letterSpacing(2)
        Blank()
      }
      .width('100%').height(64).padding({ left: 16, right: 16, top: 16 })
      .backgroundColor(Constants.BG_COLOR)
      .zIndex(10)

      if (!this.securityKey) {
        
        Column() {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(64).fontColor([Constants.TEXT_SECONDARY])
            .margin({ bottom: 16 })
          Text('登录后查看关注动态')
            .fontSize(16).fontColor(Constants.TEXT_SECONDARY)
            .margin({ bottom: 20 })
          Button('去登录').width(140).height(40).borderRadius(20)
            .backgroundColor(Constants.THEME_COLOR)
            .onClick(() => {
              router.pushUrl({ url: 'pages/AuthView' }).catch(() => {});
            })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else if (this.isLoading && this.articles.length === 0) {
        
        LoadingProgress().width(48).height(48).margin({ top: 120 }).color(Constants.THEME_COLOR)
      } else if (this.isError && this.articles.length === 0) {
        
        Column() {
          Text(this.errorMsg).fontSize(15).fontColor(Constants.TEXT_SECONDARY).margin({ bottom: 20 })
          Button('重新加载').width(140).height(40).borderRadius(20)
            .backgroundColor(Constants.THEME_COLOR)
            .onClick(() => {
              this.loadData();
            })
        }.width('100%').margin({ top: 140 }).alignItems(HorizontalAlign.Center)
      } else if (this.isEmpty) {
        
        Column() {
          SymbolGlyph($r('sys.symbol.bell'))
            .fontSize(64).fontColor([Constants.TEXT_SECONDARY])
            .margin({ bottom: 16 })
          Text('暂无关注动态')
            .fontSize(16).fontColor(Constants.TEXT_SECONDARY)
            .margin({ bottom: 8 })
          Text('去关注感兴趣的作者吧')
            .fontSize(13).fontColor(Constants.TEXT_SECONDARY)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ space: 12 }) {
            
            ListItem() {
              Row() {
                if (this.isUpdating || this.isRefreshing || this.refreshState === RefreshStatus.Refresh) {
                  LoadingProgress().width(12).height(12).color(Constants.THEME_COLOR).margin({ right: 6 })
                  Text('正在同步动态...').fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                } else if (this.refreshState === RefreshStatus.OverDrag) {
                  Text('松手可刷新').fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                } else if (this.lastUpdateTime) {
                  Text(`同步于 ${this.lastUpdateTime}`).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                }
              }
              .width('100%').justifyContent(FlexAlign.Center).padding({ top: 4, bottom: 8 })
            }

            
            ForEach(this.articles, (article: FollowedArticle) => {
              ListItem() {
                DynamicArticleCard({ article: article })
              }
              .padding({ left: 12, right: 12 })
            }, (article: FollowedArticle) => `${article.aid}_${article.time}`)

            
            ListItem() {
              if (this.isLoadingMore) {
                Row() {
                  LoadingProgress().width(20).height(20).color(Constants.THEME_COLOR).margin({ right: 8 })
                  Text('加载更多...').fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                }
                .width('100%').justifyContent(FlexAlign.Center).padding({ top: 16, bottom: 16 })
              } else if (!this.hasMore && this.articles.length > 0) {
                Text('没有更多了').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                  .width('100%').textAlign(TextAlign.Center).padding({ top: 16, bottom: 16 })
              } else {
                Row().height(16)
              }
            }

            
            ListItem() { Row().height(100) }
          }
          .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
          .onReachEnd(() => {
            if (this.hasMore && !this.isLoadingMore) {
              this.loadMore();
            }
          })
        }
        .layoutWeight(1)
        .onStateChange((state: RefreshStatus) => { this.refreshState = state; })
        .onRefreshing(async () => {
          await this.loadData(true);
          this.isRefreshing = false;
        })
      }
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
  }
}
