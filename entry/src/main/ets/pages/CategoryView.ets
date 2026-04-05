import { Constants } from '../common/Constants';
import { NovelRepository } from '../repository/NovelRepository';
import { GroupMainData, CategoryData, CategoryArticle, CategoryArticlePageInfo } from '../models/DataModels';
import { T2SEngine } from '../utils/T2SEngine';
import { PreloadEngine } from '../utils/PreloadEngine';
import { PreferenceManager } from '../utils/PreferenceManager';
import router from '@ohos.router';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import { FileLog } from '../utils/FileLog';

const TAG = 'CategoryView';
const DOMAIN = 0x0001;


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


function formatHitsCount(hits: number): string {
  if (hits >= 10000) {
    return (hits / 10000).toFixed(1) + '万';
  }
  return hits.toString();
}


@Component
struct ArticleCardGridNode {
  @Prop article: CategoryArticle;
  @StorageLink('autoSimp') autoSimp: boolean = true;
  checkSwipe?: () => boolean;

  private displayText(text: string): string {
    return this.autoSimp ? T2SEngine.convert(text) : text;
  }

  build() {
    Column() {
      
      Stack() {
        if (this.article.cover && this.article.cover_type === 1) {
          Image(this.article.cover)
            .width('100%').height('100%').objectFit(ImageFit.Cover)
        } else if (this.article.banner) {
          Image(this.article.banner)
            .width('100%').height('100%').objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text(this.displayText(this.article.title).substring(0, 1))
              .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
          }
          .width('100%').height('100%').backgroundColor(Constants.THEME_COLOR)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        }

        
        if (this.article.is_top === 1) {
          Text("置顶")
            .fontSize(9).fontColor(Color.White).fontWeight(FontWeight.Bold)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .backgroundColor('#FF6B6B')
            .borderRadius({ topLeft: 0, topRight: 8, bottomLeft: 8, bottomRight: 0 })
            .position({ right: 0, top: 0 })
        }
      }
      .width('100%').aspectRatio(0.75)
      .borderRadius({ topLeft: 12, topRight: 12, bottomLeft: 0, bottomRight: 0 })
      .clip(true)

      
      Column() {
        Text(this.displayText(this.article.title))
          .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(16).width('100%')

        Blank()

        Row() {
          Text(`${formatHitsCount(this.article.hits)}`)
            .fontSize(9).fontColor(Constants.TEXT_SECONDARY)
          Blank()
          if (this.article.comments > 0) {
            Text(`${this.article.comments}评`)
              .fontSize(9).fontColor(Constants.TEXT_SECONDARY)
          }
        }.width('100%')
      }
      .width('100%').padding({ left: 6, right: 6, top: 5, bottom: 6 })
      .height(56).alignItems(HorizontalAlign.Start)
    }
    .width('100%').backgroundColor(Constants.CARD_BG_COLOR)
    .borderRadius(12).border({ width: 0.5, color: 'rgba(0,0,0,0.04)' })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.04)', offsetY: 3 })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      if (this.checkSwipe && this.checkSwipe()) return;
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
struct ArticleCardNode {
  @Prop article: CategoryArticle;
  @StorageLink('autoSimp') autoSimp: boolean = true;

  
  checkSwipe?: () => boolean;

  private displayText(text: string): string {
    return this.autoSimp ? T2SEngine.convert(text) : text;
  }

  build() {
    Row() {
      
      if (this.article.cover && this.article.cover_type === 1) {
        Image(this.article.cover)
          .width(80).height(106).borderRadius(12).objectFit(ImageFit.Cover)
          .margin({ right: 14 })
      } else if (this.article.banner) {
        Image(this.article.banner)
          .width(80).height(106).borderRadius(12).objectFit(ImageFit.Cover)
          .margin({ right: 14 })
      } else {
        Column() {
          Text(this.displayText(this.article.title).substring(0, 1))
            .fontSize(28).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }
        .width(80).height(106).borderRadius(12)
        .backgroundColor(Constants.THEME_COLOR)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .margin({ right: 14 })
      }

      
      Column() {
        
        Row() {
          if (this.article.is_top === 1) {
            Text("置顶")
              .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(4).backgroundColor('#FF6B6B')
              .margin({ right: 6 })
          }
          Text(this.displayText(this.article.title))
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }.width('100%').alignItems(VerticalAlign.Top)

        Blank()

        
        Row() {
          if (this.article.avatar) {
            Image(this.article.avatar).width(16).height(16).borderRadius(8).margin({ right: 4 })
          }
          Text(this.article.author)
            .fontSize(12).fontColor(Constants.TEXT_SECONDARY)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.margin({ bottom: 4 }).width('100%')

        
        Row() {
          
          if (this.article.group_name && this.article.group_name !== 'undefined') {
            Text(this.displayText(this.article.group_name))
              .fontSize(10).fontColor(Constants.THEME_COLOR)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(4).backgroundColor(Constants.THEME_TINT_BG)
              .margin({ right: 8 })
          } else if (this.article.series_name && this.article.series_name !== 'undefined') {
            Text(this.displayText(this.article.series_name))
              .fontSize(10).fontColor('#FF8C00')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(4).backgroundColor('rgba(255, 140, 0, 0.08)')
              .margin({ right: 8 })
          }

          Text(`${formatHitsCount(this.article.hits)}阅读`)
            .fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ right: 8 })
          Text(`${this.article.comments}评论`)
            .fontSize(11).fontColor(Constants.TEXT_SECONDARY)

          Blank()

          
          Text(this.article.last_time ? this.article.last_time.split(' ')[0] : '')
            .fontSize(10).fontColor(Constants.TEXT_SECONDARY)
        }.width('100%')
      }
      .layoutWeight(1).height(106).justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%').padding(14).backgroundColor(Constants.CARD_BG_COLOR)
    .borderRadius(16)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
    .onClick(() => {
      
      if (this.checkSwipe && this.checkSwipe()) {
        return;
      }

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
export struct CategoryView {
  @StorageLink('autoSimp') autoSimp: boolean = true;
  @StorageLink('security_key') @Watch('onSecurityKeyChange') securityKey: string = '';

  
  switchTab?: (index: number) => void;

  @State mainGroups: GroupMainData[] = [];
  @State selectedGroupIndex: number = 1;
  @State categories: CategoryData[] = [];
  @State selectedCategoryIndex: number = 0;
  @State articles: CategoryArticle[] = [];
  @State pageInfo: CategoryArticlePageInfo = new CategoryArticlePageInfo();

  @State isLoadingGroups: boolean = true;
  @State isLoadingCategories: boolean = false;
  @State isLoadingArticles: boolean = false;
  @State isLoadingMore: boolean = false;
  @State isRefreshing: boolean = false;
  @State errorMessage: string = '';

  
  @State isWideScreen: boolean = false;
  
  @StorageLink('categoryLayoutMode') layoutMode: string = 'grid';
  
  @State containerWidth: number = 360;

  
  private isSwiping: boolean = false;

  
  private categorySeq: number = 0;
  private articleSeq: number = 0;
  private hasLoaded: boolean = false;

  
  private onAuthChanged: (key: string) => void = (key: string) => {
    FileLog.i(TAG, `onAuthChanged 收到, key长度=${key.length}, 已有分组=${this.mainGroups.length}`);
    if (key && key !== '' && this.mainGroups.length === 0) {
      this.securityKey = key;
      this.loadMainGroups();
    }
  };

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'aboutToAppear, securityKey长度=%{public}d, hasLoaded=%{public}s', this.securityKey.length, this.hasLoaded.toString());
    FileLog.i(TAG, `aboutToAppear, securityKey长度=${this.securityKey.length}, hasLoaded=${this.hasLoaded}`);

    
    this.loadLayoutMode();

    
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      ctx.eventHub.on('auth_state_changed', this.onAuthChanged);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'EventHub registration failed');
    }

    
    if (this.hasLoaded) return;

    if (this.securityKey) {
      this.hasLoaded = true;
      this.loadMainGroups();
    } else {
      
      this.tryLoadKeyFromDisk();
    }
  }

  aboutToDisappear() {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      ctx.eventHub.off('auth_state_changed', this.onAuthChanged);
    } catch (e) {}
  }

  
  async loadLayoutMode() {
    let saved = await PreferenceManager.getString('categoryLayoutMode', '');
    if (saved === 'grid' || saved === 'list') {
      this.layoutMode = saved;
      AppStorage.setOrCreate('categoryLayoutMode', saved);
    } else {
      
      let defaultMode = 'grid';
      this.layoutMode = defaultMode;
      AppStorage.setOrCreate('categoryLayoutMode', defaultMode);
    }
  }

  
  private async tryLoadKeyFromDisk() {
    try {
      let diskKey = await PreferenceManager.getString('security_key', '');
      FileLog.i(TAG, `tryLoadKeyFromDisk: 磁盘key长度=${diskKey.length}, 当前key长度=${this.securityKey.length}`);
      if (diskKey && diskKey !== '' && !this.securityKey) {
        this.securityKey = diskKey;
        AppStorage.setOrCreate('security_key', diskKey);
        if (this.mainGroups.length === 0 && !this.hasLoaded) {
          this.hasLoaded = true;
          this.loadMainGroups();
        }
      }
    } catch (e) {
      FileLog.e(TAG, 'tryLoadKeyFromDisk 异常');
    }
  }

  
  onSecurityKeyChange() {
    hilog.info(DOMAIN, TAG, 'onSecurityKeyChange 触发, securityKey长度=%{public}d, 已有分组=%{public}d', this.securityKey.length, this.mainGroups.length);
    FileLog.i(TAG, `onSecurityKeyChange 触发, securityKey长度=${this.securityKey.length}, 已有分组=${this.mainGroups.length}`);
    if (this.securityKey && this.mainGroups.length === 0 && !this.hasLoaded) {
      this.hasLoaded = true;
      this.loadMainGroups();
    }
  }

  async loadMainGroups() {
    this.isLoadingGroups = true;
    this.errorMessage = '';
    FileLog.i(TAG, `loadMainGroups 开始, securityKey长度=${this.securityKey.length}`);

    
    try {
      let cachedGroups = await PreferenceManager.getString('cache_mainGroups', '');
      if (cachedGroups && this.mainGroups.length === 0) {
        let parsed = JSON.parse(cachedGroups) as GroupMainData[];
        if (parsed.length > 0) {
          this.mainGroups = parsed;
          this.isLoadingGroups = false;
          
          let defaultIdx = parsed.length > 1 ? 1 : 0;
          this.selectedGroupIndex = defaultIdx;
          
          let cachedCats = await PreferenceManager.getString(`cache_categories_${parsed[defaultIdx].gid}`, '');
          if (cachedCats) {
            try {
              this.categories = JSON.parse(cachedCats) as CategoryData[];
              this.isLoadingCategories = false;
              if (this.categories.length > 0) {
                this.selectedCategoryIndex = 0;
                
                let cachedArts = await PreferenceManager.getString(`cache_catArticles_${parsed[defaultIdx].gid}_${this.categories[0].gid}`, '');
                if (cachedArts) {
                  try {
                    let artData = JSON.parse(cachedArts) as Record<string, Object>;
                    this.articles = artData['list'] as CategoryArticle[];
                    this.pageInfo = artData['page_info'] as CategoryArticlePageInfo;
                  } catch (e) {}
                }
              }
            } catch (e) {}
          }
          FileLog.i(TAG, `从缓存加载分组成功, ${parsed.length} 个分组, 默认选中index=${defaultIdx}`);
        }
      }
    } catch (e) {}

    try {
      let result = await NovelRepository.getGroupMain();
      FileLog.i(TAG, `loadMainGroups 成功, 获得 ${result.length} 个分组`);
      
      PreferenceManager.putString('cache_mainGroups', JSON.stringify(result));
      if (result.length > 0) {
        
        let defaultIdx = result.length > 1 ? 1 : 0;

        
        let needReloadCategories = true;
        if (this.mainGroups.length > 0 && this.selectedGroupIndex < this.mainGroups.length) {
          let oldGid = this.mainGroups[this.selectedGroupIndex].gid;
          let newGid = result[defaultIdx].gid;
          if (oldGid === newGid && this.categories.length > 0) {
            
            needReloadCategories = false;
            FileLog.i(TAG, `loadMainGroups: 分组gid未变(${oldGid})，跳过重载子分类`);
          }
        }

        this.mainGroups = result;
        this.selectedGroupIndex = defaultIdx;
        this.isLoadingGroups = false;
        FileLog.i(TAG, `loadMainGroups: isLoadingGroups 已置 false, 默认index=${defaultIdx}`);

        if (needReloadCategories) {
          this.loadCategories(result[defaultIdx].gid);
        } else {
          
          this.loadCategories(result[defaultIdx].gid);
        }
      } else {
        this.mainGroups = result;
        this.isLoadingGroups = false;
      }
    } catch (e) {
      let err = e as Error;
      this.errorMessage = err.message || '加载分区失败';
      FileLog.e(TAG, `loadMainGroups 失败: ${this.errorMessage}`);
      this.isLoadingGroups = false;
    }
  }

  async loadCategories(parentGid: number) {
    this.categorySeq++;
    let mySeq = this.categorySeq;

    
    let hadCache = false;
    if (this.categories.length === 0) {
      
      try {
        let cachedCats = await PreferenceManager.getString(`cache_categories_${parentGid}`, '');
        if (cachedCats) {
          let parsed = JSON.parse(cachedCats) as CategoryData[];
          if (parsed.length > 0) {
            this.categories = parsed;
            this.selectedCategoryIndex = 0;
            hadCache = true;
            FileLog.i(TAG, `loadCategories: 从缓存加载 ${parsed.length} 个分类`);
            
            this.loadArticles(parentGid, parsed[0].gid, 1);
          }
        }
      } catch (e) {}
    } else {
      
      hadCache = true;
    }

    
    if (!hadCache) {
      this.isLoadingCategories = true;
      this.categories = [];
      this.articles = [];
      this.pageInfo = new CategoryArticlePageInfo();
    }
    FileLog.i(TAG, `loadCategories 开始, parentGid=${parentGid}, seq=${mySeq}, hadCache=${hadCache}`);
    try {
      let result = await NovelRepository.getCategories(parentGid);
      
      if (mySeq !== this.categorySeq) {
        FileLog.i(TAG, `loadCategories seq过期(${mySeq}!=${this.categorySeq})，丢弃`);
        return;
      }

      
      let needUpdate = false;
      if (this.categories.length !== result.length) {
        needUpdate = true;
      } else {
        for (let i = 0; i < this.categories.length; i++) {
          if (this.categories[i].gid !== result[i].gid) {
            needUpdate = true;
            break;
          }
        }
      }

      if (needUpdate) {
        this.categories = result;
        this.selectedCategoryIndex = 0;
        if (result.length > 0) {
          this.loadArticles(parentGid, result[0].gid, 1);
        }
      }

      
      PreferenceManager.putString(`cache_categories_${parentGid}`, JSON.stringify(result));
      FileLog.i(TAG, `loadCategories 成功, 获得 ${result.length} 个分类`);
      this.isLoadingCategories = false;
    } catch (e) {
      if (mySeq !== this.categorySeq) return;
      let err = e as Error;
      FileLog.e(TAG, `加载分类失败: ${err.message || JSON.stringify(e)}`);
      hilog.error(DOMAIN, TAG, '加载分类失败');
      this.isLoadingCategories = false;
    }
  }

  async loadArticles(parentGid: number, gid: number, page: number) {
    if (page === 1) {
      this.articleSeq++;
      let hadCache = false;

      
      try {
        let cachedArts = await PreferenceManager.getString(`cache_catArticles_${parentGid}_${gid}`, '');
        if (cachedArts) {
          let artData = JSON.parse(cachedArts) as Record<string, Object>;
          let cachedList = artData['list'] as CategoryArticle[];
          let cachedPageInfo = artData['page_info'] as CategoryArticlePageInfo;
          if (cachedList && cachedList.length > 0) {
            this.articles = cachedList;
            this.pageInfo = cachedPageInfo;
            hadCache = true;
            this.isLoadingArticles = false;
            FileLog.i(TAG, `loadArticles: 从缓存加载 ${cachedList.length} 篇文章`);
          }
        }
      } catch (e) {}

      
      if (!hadCache) {
        if (!this.isRefreshing) {
          this.isLoadingArticles = true;
        }
        this.articles = [];
      }
    } else {
      this.isLoadingMore = true;
    }
    let mySeq = this.articleSeq;
    FileLog.i(TAG, `loadArticles 开始, parentGid=${parentGid}, gid=${gid}, page=${page}, seq=${mySeq}`);
    try {
      let result = await NovelRepository.getArticlesByCategory(parentGid, gid, page, 20);
      
      if (mySeq !== this.articleSeq) {
        FileLog.i(TAG, `loadArticles seq过期(${mySeq}!=${this.articleSeq})，丢弃`);
        return;
      }
      FileLog.i(TAG, `loadArticles 成功, 获得 ${result.list.length} 篇文章`);
      if (page === 1) {
        
        let needUpdate = false;
        if (this.articles.length !== result.list.length) {
          needUpdate = true;
        } else {
          for (let i = 0; i < this.articles.length; i++) {
            if (this.articles[i].aid !== result.list[i].aid) {
              needUpdate = true;
              break;
            }
          }
        }
        if (needUpdate) {
          this.articles = result.list;
        }
      } else {
        
        let newArr: CategoryArticle[] = [];
        for (let i = 0; i < this.articles.length; i++) {
          newArr.push(this.articles[i]);
        }
        for (let i = 0; i < result.list.length; i++) {
          newArr.push(result.list[i]);
        }
        this.articles = newArr;
      }
      this.pageInfo = result.page_info;
      FileLog.i(TAG, `loadArticles: 文章数组长度=${this.articles.length}, has_next=${this.pageInfo.has_next}`);

      
      if (page === 1) {
        let cacheData: Record<string, Object> = {
          'list': result.list as Object,
          'page_info': result.page_info as Object
        };
        PreferenceManager.putString(`cache_catArticles_${parentGid}_${gid}`, JSON.stringify(cacheData));
      }

      
      let aids: number[] = [];
      let items = result.list;
      for (let i = 0; i < items.length && i < 5; i++) {
        if (items[i].aid && (!items[i].sid || items[i].sid === 0)) {
          aids.push(items[i].aid);
        }
      }
      if (aids.length > 0) {
        setTimeout(() => {
          PreloadEngine.enqueueBatch(aids, 2);
        }, 2000);
      }
    } catch (e) {
      if (mySeq !== this.articleSeq) return;
      let err = e as Error;
      FileLog.e(TAG, `加载文章失败: ${err.message}`);
      hilog.error(DOMAIN, TAG, '加载文章失败');
    } finally {
      if (mySeq === this.articleSeq) {
        this.isLoadingArticles = false;
        this.isLoadingMore = false;
        this.isRefreshing = false;
        FileLog.i(TAG, `loadArticles finally: isLoadingArticles=${this.isLoadingArticles}, articles.length=${this.articles.length}`);
      }
    }
  }

  private displayText(text: string): string {
    return this.autoSimp ? T2SEngine.convert(text) : text;
  }

  
  
  private getGridColumns(itemCount?: number): number {
    let idealWidth = 120;
    let padding = 40;
    let available = this.containerWidth - padding;
    let maxCols = Math.floor(available / idealWidth);
    if (maxCols < 2) maxCols = 2;
    if (maxCols > 6) maxCols = 6;

    if (itemCount === undefined || itemCount <= 0) return maxCols;
    if (itemCount <= maxCols) return itemCount;

    let bestCols = maxCols;
    let bestRemainder = itemCount % maxCols;

    if (bestRemainder !== 0) {
      for (let c = maxCols; c >= 2; c--) {
        let rem = itemCount % c;
        if (rem === 0) {
          bestCols = c;
          break;
        }
        if (rem > bestRemainder || (rem === bestRemainder && c > bestCols)) {
          bestRemainder = rem;
          bestCols = c;
        }
      }
    }

    return bestCols;
  }

  
  private async preloadOtherSubcategoryLists(parentGid: number, cats: CategoryData[]) {
    for (let ci = 1; ci < cats.length; ci++) {
      let cat = cats[ci];
      let cachedArts = await PreferenceManager.getString(`cache_catArticles_${parentGid}_${cat.gid}`, '');
      if (cachedArts) continue; 

      try {
        let artResult = await NovelRepository.getArticlesByCategory(parentGid, cat.gid, 1, 20);
        if (artResult.list.length > 0) {
          let cacheData: Record<string, Object> = {
            'list': artResult.list as Object,
            'page_info': artResult.page_info as Object
          };
          PreferenceManager.putString(`cache_catArticles_${parentGid}_${cat.gid}`, JSON.stringify(cacheData));
        }
      } catch (e) {}
      
      await new Promise<void>((resolve: Function) => { setTimeout(() => { resolve(); }, 800); });
    }
  }

  build() {
    Column() {
      
      
      Row() {
        Text("分区").fontSize(20).fontWeight(FontWeight.Bolder).fontColor(Constants.TEXT_PRIMARY).letterSpacing(2)
        Blank()
        
        Row() {
          SymbolGlyph(this.layoutMode === 'grid' ? $r('sys.symbol.list_bullet') : $r('sys.symbol.square_grid_2x2'))
            .fontSize(20).fontColor([Constants.TEXT_SECONDARY])
        }
        .width(36).height(36).justifyContent(FlexAlign.Center)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => {
          let newMode = this.layoutMode === 'list' ? 'grid' : 'list';
          this.layoutMode = newMode;
          AppStorage.setOrCreate('categoryLayoutMode', newMode);
          PreferenceManager.putString('categoryLayoutMode', newMode);
        })
      }
      .width('100%').height(64).padding({ left: 16, right: 16, top: 16 })
      .backgroundColor(Constants.BG_COLOR)
      .zIndex(10)
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal, distance: 50 })
          .onActionEnd((event: GestureEvent) => {
            if (this.switchTab) {
              if (event.offsetX > 50) {
                
                this.switchTab(0);
              } else if (event.offsetX < -50) {
                
                this.switchTab(2);
              }
            }
          })
      )

      
      if (!this.securityKey) {
        Column() {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(64).fontColor([Constants.TEXT_SECONDARY]).margin({ bottom: 16 })
          Text("分区功能需要登录后使用")
            .fontSize(16).fontColor(Constants.TEXT_SECONDARY).margin({ bottom: 24 })
          Button('前往登录')
            .width(160).height(44).borderRadius(22)
            .backgroundColor(Constants.THEME_COLOR).fontSize(16)
            .onClick(() => {
              router.pushUrl({ url: 'pages/AuthView' }).catch(() => {});
            })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 50 })
            .onActionEnd((event: GestureEvent) => {
              if (this.switchTab) {
                if (event.offsetX > 50) { this.switchTab(0); }
                else if (event.offsetX < -50) { this.switchTab(2); }
              }
            })
        )
      } else if (this.isLoadingGroups) {
        Column() {
          LoadingProgress().width(48).height(48).color(Constants.THEME_COLOR)
          Text("加载分区...").fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ top: 12 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 50 })
            .onActionEnd((event: GestureEvent) => {
              if (this.switchTab) {
                if (event.offsetX > 50) { this.switchTab(0); }
                else if (event.offsetX < -50) { this.switchTab(2); }
              }
            })
        )
      } else if (this.errorMessage) {
        Column() {
          Text(this.errorMessage).fontSize(15).fontColor(Constants.TEXT_SECONDARY).margin({ bottom: 16 })
          Button('重新加载').width(140).height(40).borderRadius(20)
            .backgroundColor(Constants.THEME_COLOR)
            .onClick(() => this.loadMainGroups())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 50 })
            .onActionEnd((event: GestureEvent) => {
              if (this.switchTab) {
                if (event.offsetX > 50) { this.switchTab(0); }
                else if (event.offsetX < -50) { this.switchTab(2); }
              }
            })
        )
      } else {
        
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.mainGroups, (group: GroupMainData, index: number) => {
              Column() {
                if (group.logo && group.logo.startsWith('http')) {
                  Image(group.logo).width(28).height(28).objectFit(ImageFit.Contain)
                    .alt($r('app.media.startIcon'))
                } else {
                  Text(this.displayText(group.name).substring(0, 1))
                    .fontSize(18).fontWeight(FontWeight.Bold)
                    .fontColor(index === this.selectedGroupIndex ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                }
                Text(this.displayText(group.name))
                  .fontSize(12).fontWeight(index === this.selectedGroupIndex ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(index === this.selectedGroupIndex ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                  .margin({ top: 4 })
                if (group.last_time) {
                  Text(formatRelativeTime(group.last_time))
                    .fontSize(9).fontColor(index === this.selectedGroupIndex ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                    .margin({ top: 2 }).opacity(0.7)
                }
              }
              .width(64).height(76).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .borderRadius(16)
              .backgroundColor(index === this.selectedGroupIndex ? Constants.THEME_TINT_BG : Constants.CARD_BG_COLOR)
              .border({ width: index === this.selectedGroupIndex ? 1.5 : 0, color: Constants.THEME_COLOR })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .onClick(() => {
                if (index !== this.selectedGroupIndex) {
                  this.selectedGroupIndex = index;
                  this.loadCategories(group.gid);
                }
              })
            }, (group: GroupMainData) => `group_${group.gid}`)
          }.padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .width('100%').height(88).margin({ top: 4 })

        
        if (this.isLoadingCategories) {
          Row() {
            LoadingProgress().width(20).height(20).color(Constants.THEME_COLOR)
            Text("加载分类...").fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 8 })
          }.width('100%').height(44).justifyContent(FlexAlign.Center)
        } else if (this.categories.length > 0) {
          Scroll() {
            Row({ space: 0 }) {
              ForEach(this.categories, (cat: CategoryData, index: number) => {
                Text(this.displayText(cat.name))
                  .fontSize(14)
                  .fontWeight(index === this.selectedCategoryIndex ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(index === this.selectedCategoryIndex ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                  .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                  .borderRadius(20)
                  .backgroundColor(index === this.selectedCategoryIndex ? Constants.THEME_TINT_BG : Color.Transparent)
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                  .onClick(() => {
                    if (index !== this.selectedCategoryIndex) {
                      this.selectedCategoryIndex = index;
                      let group = this.mainGroups[this.selectedGroupIndex];
                      if (group) {
                        this.loadArticles(group.gid, cat.gid, 1);
                      }
                    }
                  })
              }, (cat: CategoryData) => `cat_${cat.gid}`)
            }.padding({ left: 12, right: 12 })
          }
          .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          .width('100%').height(52)
        }

        
        if (this.isLoadingArticles && !this.isRefreshing) {
          Column() {
            LoadingProgress().width(36).height(36).color(Constants.THEME_COLOR)
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, distance: 30 })
              .onActionEnd((event: GestureEvent) => {
                let offsetX = event.offsetX;
                
                if (this.categories.length > 1) {
                  if (offsetX > 50 && this.selectedCategoryIndex > 0) {
                    this.selectedCategoryIndex--;
                    let group = this.mainGroups[this.selectedGroupIndex];
                    if (group) { this.loadArticles(group.gid, this.categories[this.selectedCategoryIndex].gid, 1); }
                  } else if (offsetX < -50 && this.selectedCategoryIndex < this.categories.length - 1) {
                    this.selectedCategoryIndex++;
                    let group = this.mainGroups[this.selectedGroupIndex];
                    if (group) { this.loadArticles(group.gid, this.categories[this.selectedCategoryIndex].gid, 1); }
                  } else if (offsetX > 50 && this.selectedCategoryIndex === 0 && this.switchTab) {
                    this.switchTab(0);
                  } else if (offsetX < -50 && this.selectedCategoryIndex === this.categories.length - 1 && this.switchTab) {
                    this.switchTab(2);
                  }
                } else if (this.switchTab) {
                  if (offsetX > 50) { this.switchTab(0); }
                  else if (offsetX < -50) { this.switchTab(2); }
                }
              })
          )
        } else if (this.articles.length === 0 && !this.isLoadingCategories) {
          Column() {
            Text("暂无内容").fontSize(15).fontColor(Constants.TEXT_SECONDARY)
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, distance: 30 })
              .onActionEnd((event: GestureEvent) => {
                let offsetX = event.offsetX;
                
                if (this.categories.length > 1) {
                  if (offsetX > 50 && this.selectedCategoryIndex > 0) {
                    this.selectedCategoryIndex--;
                    let group = this.mainGroups[this.selectedGroupIndex];
                    if (group) { this.loadArticles(group.gid, this.categories[this.selectedCategoryIndex].gid, 1); }
                  } else if (offsetX < -50 && this.selectedCategoryIndex < this.categories.length - 1) {
                    this.selectedCategoryIndex++;
                    let group = this.mainGroups[this.selectedGroupIndex];
                    if (group) { this.loadArticles(group.gid, this.categories[this.selectedCategoryIndex].gid, 1); }
                  } else if (offsetX > 50 && this.selectedCategoryIndex === 0 && this.switchTab) {
                    this.switchTab(0);
                  } else if (offsetX < -50 && this.selectedCategoryIndex === this.categories.length - 1 && this.switchTab) {
                    this.switchTab(2);
                  }
                } else if (this.switchTab) {
                  if (offsetX > 50) { this.switchTab(0); }
                  else if (offsetX < -50) { this.switchTab(2); }
                }
              })
          )
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ space: 12 }) {
              if (this.layoutMode === 'grid') {
                
                ListItem() {
                  Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                    ForEach(this.articles, (article: CategoryArticle, index: number) => {
                      Column() {
                        ArticleCardGridNode({
                          article: article,
                          checkSwipe: () => { return this.isSwiping; }
                        })
                      }
                      .width(`${100 / this.getGridColumns(this.articles.length)}%`)
                      .padding(6)
                    }, (article: CategoryArticle, index: number) => `grid_${article.aid}_${index}`)
                  }
                  .width('100%').padding({ left: 10, right: 10, bottom: 24 })
                }
              } else {
                
                ForEach(this.articles, (article: CategoryArticle, index: number) => {
                  ListItem() {
                    ArticleCardNode({
                      article: article,
                      checkSwipe: () => { return this.isSwiping; }
                    })
                  }
                }, (article: CategoryArticle, index: number) => `article_${article.aid}_${index}`)
              }

              
              if (this.pageInfo.has_next === 1) {
                ListItem() {
                  Row() {
                    if (this.isLoadingMore) {
                      LoadingProgress().width(20).height(20).color(Constants.THEME_COLOR)
                      Text("加载中...").fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 8 })
                    } else {
                      Text("上拉加载更多").fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                    }
                  }.width('100%').height(48).justifyContent(FlexAlign.Center)
                }
              }

              
              ListItem() { Row().height(120) }
            }
            .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
            .padding({ left: 16, right: 16, top: 8 })
            .onReachEnd(() => {
              if (this.pageInfo.has_next === 1 && !this.isLoadingMore) {
                let group = this.mainGroups[this.selectedGroupIndex];
                let cat = this.categories[this.selectedCategoryIndex];
                if (group && cat) {
                  this.loadArticles(group.gid, cat.gid, this.pageInfo.next);
                }
              }
            })
            
            
            
            
            .priorityGesture(
              PanGesture({ direction: PanDirection.Horizontal, distance: 30 })
                .onActionStart(() => {
                  this.isSwiping = true;
                })
                .onActionUpdate(() => {
                  this.isSwiping = true;
                })
                .onActionEnd((event: GestureEvent) => {
                  let offsetX = event.offsetX;
                  if (this.categories.length > 1) {
                    if (offsetX > 50 && this.selectedCategoryIndex > 0) {
                      
                      this.selectedCategoryIndex--;
                      let group = this.mainGroups[this.selectedGroupIndex];
                      if (group) {
                        this.loadArticles(group.gid, this.categories[this.selectedCategoryIndex].gid, 1);
                      }
                    } else if (offsetX < -50 && this.selectedCategoryIndex < this.categories.length - 1) {
                      
                      this.selectedCategoryIndex++;
                      let group = this.mainGroups[this.selectedGroupIndex];
                      if (group) {
                        this.loadArticles(group.gid, this.categories[this.selectedCategoryIndex].gid, 1);
                      }
                    } else if (offsetX > 50 && this.selectedCategoryIndex === 0 && this.switchTab) {
                      
                      this.switchTab(0);
                    } else if (offsetX < -50 && this.selectedCategoryIndex === this.categories.length - 1 && this.switchTab) {
                      
                      this.switchTab(2);
                    }
                  } else if (this.switchTab) {
                    
                    if (offsetX > 50) { this.switchTab(0); }
                    else if (offsetX < -50) { this.switchTab(2); }
                  }
                  
                  setTimeout(() => {
                    this.isSwiping = false;
                  }, 150);
                })
                .onActionCancel(() => {
                  
                  setTimeout(() => {
                    this.isSwiping = false;
                  }, 150);
                })
            )
          }
          .layoutWeight(1)
          .onRefreshing(async () => {
            let group = this.mainGroups[this.selectedGroupIndex];
            let cat = this.categories[this.selectedCategoryIndex];
            if (group && cat) {
              await this.loadArticles(group.gid, cat.gid, 1);
            } else {
              this.isRefreshing = false;
            }
          })
        }
      }
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR).clip(true)
    .onAreaChange((_: Area, newArea: Area) => {
      let w = newArea.width;
      if (typeof w === 'number') {
        this.isWideScreen = w > 600;
        this.containerWidth = w;
      }
    })
  }
}