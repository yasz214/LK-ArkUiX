import { IndexViewModel } from '../viewmodel/IndexViewModel';
import { NovelCard, NovelCardGrid } from '../componets/NovelCard';
import { Constants } from '../common/Constants';
import { T2SEngine } from '../utils/T2SEngine';
import { PreloadEngine } from '../utils/PreloadEngine';
import { PreferenceManager } from '../utils/PreferenceManager';
import router from '@ohos.router';
import { NovelGroup, NovelItem, UserInfoData, SearchTag } from '../models/DataModels';
import { NovelRepository } from '../repository/NovelRepository';

@Component
struct BannerItemNode {
  @Prop item: NovelItem;
  @StorageLink('autoSimp') autoSimp: boolean = true;

  build() {
    
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.item.pic_url).width('100%').height(220).objectFit(ImageFit.Cover).borderRadius(16)
      Column() {
        Text(this.autoSimp ? T2SEngine.convert(this.item.title) : this.item.title)
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%').padding({ left: 20, right: 20, top: 40, bottom: 20 })
      .linearGradient({ direction: GradientDirection.Bottom, colors: [['rgba(0,0,0,0)', 0.0], ['rgba(0,0,0,0.75)', 1.0]] })
      .borderRadius({ bottomLeft: 16, bottomRight: 16 })
    }
    .width('100%').height(220).padding({ left: 20, right: 20 })
    
    .onAppear(() => {
      if (this.item.action_type === 1 && typeof this.item.action_params === 'number') {
        PreloadEngine.enqueue(this.item.action_params, 0);
      }
    })
    .onClick(() => {
      if (this.item.action_type === 1 && typeof this.item.action_params === 'number') {
        router.pushUrl({ url: 'pages/ArticleDetail', params: { aid: this.item.action_params, tag: this.item.parent_group_name } }).catch(()=>{});
      } else if (this.item.action_type === 2 && typeof this.item.action_params === 'number') {
        router.pushUrl({ url: 'pages/CollectionDetailView', params: { sid: this.item.action_params, title: this.item.title } }).catch(()=>{});
      }
    })
  }
}

@Component
struct GroupHeaderNode {
  @Prop title: string;
  @StorageLink('autoSimp') autoSimp: boolean = true;

  build() {
    Row() {
      Rect({ width: 4, height: 18 }).radius(2).fill(Constants.THEME_COLOR).margin({ left: 20, right: 8 })
      Text(this.autoSimp ? T2SEngine.convert(this.title) : this.title)
        .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY).letterSpacing(1)
    }
    .width('100%').padding({ top: 24, bottom: 16 }).alignItems(VerticalAlign.Center)
  }
}

@Component
export struct HomeView {
  @State viewModel: IndexViewModel = new IndexViewModel();
  @StorageLink('autoSimp') autoSimp: boolean = true;
  @StorageLink('userInfo') userInfo: UserInfoData | null = null;
  @StorageLink('security_key') securityKey: string = '';
  switchTab?: (index: number) => void;

  @State isRefreshing: boolean = false;
  @State refreshState: RefreshStatus = RefreshStatus.Inactive;
  
  @State isWideScreen: boolean = false;
  
  @StorageLink('homeLayoutMode') layoutMode: string = 'grid';
  
  @State containerWidth: number = 360;

  
  @State hotTags: SearchTag[] = [];
  @State currentPlaceholder: string = '搜索小说...';
  private placeholderTimer: number = -1;
  private placeholderIndex: number = 0;

  aboutToAppear() {
    this.viewModel.fetchRecommends();
    this.loadHotTags();
    
    this.loadLayoutMode();
  }

  async loadLayoutMode() {
    
    let saved = await PreferenceManager.getString('homeLayoutMode', '');
    if (saved === 'grid' || saved === 'list') {
      this.layoutMode = saved;
      AppStorage.setOrCreate('homeLayoutMode', saved);
    } else {
      
      let defaultMode = this.isWideScreen ? 'list' : 'grid';
      this.layoutMode = defaultMode;
      AppStorage.setOrCreate('homeLayoutMode', defaultMode);
    }
  }

  aboutToDisappear() {
    if (this.placeholderTimer !== -1) {
      clearInterval(this.placeholderTimer);
      this.placeholderTimer = -1;
    }
  }

  async loadHotTags() {
    try {
      let tags = await NovelRepository.getSearchTags();
      if (tags.length > 0) {
        this.hotTags = tags;
        
        AppStorage.setOrCreate('cachedHotTags', JSON.stringify(tags));
        this.placeholderIndex = Math.floor(Math.random() * tags.length);
        this.currentPlaceholder = tags[this.placeholderIndex].alias;
        
        this.placeholderTimer = setInterval(() => {
          if (this.hotTags.length > 0) {
            this.placeholderIndex = (this.placeholderIndex + 1) % this.hotTags.length;
            this.currentPlaceholder = this.hotTags[this.placeholderIndex].alias;
          }
        }, 4000);
      }
    } catch (e) {}
  }

  @Builder itemHead(text: string) {
    GroupHeaderNode({ title: text })
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

  build() {
    Column() {
      Row() {
        Text("轻之国度").fontSize(20).fontWeight(FontWeight.Bolder).fontColor(Constants.TEXT_PRIMARY).letterSpacing(2)

        Row() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(16).fontColor([Constants.TEXT_SECONDARY]).margin({ right: 6 })
          Text(this.autoSimp ? T2SEngine.convert(this.currentPlaceholder) : this.currentPlaceholder)
            .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1).height(36).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(18)
        .padding({ left: 12, right: 12 }).alignItems(VerticalAlign.Center)
        .margin({ left: 16, right: 16 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
        .onClick(() => router.pushUrl({ url: 'pages/SearchView' }).catch(() => {}))

        
        Row() {
          SymbolGlyph(this.layoutMode === 'grid' ? $r('sys.symbol.list_bullet') : $r('sys.symbol.square_grid_2x2'))
            .fontSize(20).fontColor([Constants.TEXT_SECONDARY])
        }
        .width(36).height(36).justifyContent(FlexAlign.Center)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => {
          let newMode = this.layoutMode === 'list' ? 'grid' : 'list';
          this.layoutMode = newMode;
          AppStorage.setOrCreate('homeLayoutMode', newMode);
          PreferenceManager.putString('homeLayoutMode', newMode);
        })

        Row() {
          if (this.securityKey && this.userInfo && this.userInfo.avatar) {
            Image(this.userInfo.avatar).width(34).height(34).borderRadius(17).objectFit(ImageFit.Cover)
          } else {
            Text("登录").fontSize(12).fontWeight(FontWeight.Medium).fontColor(Constants.THEME_COLOR)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(Constants.THEME_TINT_BG_STRONG).borderRadius(14)
          }
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => {
          if (this.securityKey) {
            if (this.switchTab) this.switchTab(3);
          } else {
            router.pushUrl({ url: 'pages/AuthView' }).catch(() => {});
          }
        })
      }
      .width('100%').height(64).padding({ left: 16, right: 16, top: 16 })
      .backgroundColor(Constants.BG_COLOR)
      .zIndex(10)

      if (this.viewModel.isLoading && !this.isRefreshing) {
        LoadingProgress().width(48).height(48).margin({ top: 120 }).color(Constants.THEME_COLOR)
      } else if (this.viewModel.message !== '' && this.viewModel.recommendGroups.length === 0) {
        Column() {
          Text(this.viewModel.message).fontSize(15).margin({ bottom: 20 }).fontColor(Constants.TEXT_SECONDARY)
          Button('重新加载').width(140).height(40).borderRadius(20)
            .backgroundColor(Constants.THEME_COLOR)
            .onClick(() => {
              this.viewModel.isLoading = true;
              this.viewModel.fetchRecommends();
            })
        }.width('100%').margin({ top: 140 }).alignItems(HorizontalAlign.Center)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List() {
            ListItem() {
              Row() {
                if (this.viewModel.isUpdating || this.isRefreshing || this.refreshState === RefreshStatus.Refresh) {
                  LoadingProgress().width(12).height(12).color(Constants.THEME_COLOR).margin({right: 6})
                  Text("正在同步推荐...").fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                } else if (this.refreshState === RefreshStatus.OverDrag) {
                  Text("松手可刷新").fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                } else if (this.viewModel.lastUpdateTime) {
                  Text(`同步于 ${this.viewModel.lastUpdateTime}`).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                }
              }
              .width('100%').justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 12 })
            }

            ForEach(this.viewModel.recommendGroups, (group: NovelGroup) => {
              if (group.title === '推薦頂欄橫幅' || group.title === '推荐顶栏横幅') {
                ListItem() {
                  if (this.isWideScreen) {
                    
                    Row({ space: 12 }) {
                      ForEach(group.items, (item: NovelItem) => {
                        Column() {
                          BannerItemNode({ item: item })
                        }.layoutWeight(1)
                      }, (item: NovelItem) => `${item.id}_${item.title}`)
                    }
                    .width('100%').padding({ left: 16, right: 16 }).margin({ bottom: 16 })
                  } else {
                    
                    Swiper() {
                      ForEach(group.items, (item: NovelItem) => {
                        BannerItemNode({ item: item })
                      }, (item: NovelItem) => `${item.id}_${item.title}`)
                    }
                    .width('100%').height(220).autoPlay(true).interval(4000)
                    .indicator(Indicator.dot().selectedColor(Constants.THEME_COLOR))
                    .margin({ bottom: 16 })
                  }
                }
              } else {
                ListItemGroup({ header: this.itemHead(group.title) }) {
                  if (this.layoutMode === 'grid') {
                    
                    ListItem() {
                      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                        ForEach(group.items, (item: NovelItem) => {
                          Column() {
                            NovelCardGrid({ item: item })
                          }
                          .width(`${100 / this.getGridColumns(group.items.length)}%`)
                          .padding(6)
                        }, (item: NovelItem) => `g_${item.id}_${item.title}`)
                      }
                      .width('100%').padding({ left: 14, right: 14, bottom: 24 })
                    }
                  } else {
                    
                    ListItem() {
                      GridRow({ columns: { sm: 1, md: 2, lg: 3, xl: 4 }, gutter: 20 }) {
                        ForEach(group.items, (item: NovelItem) => {
                          GridCol() { NovelCard({ item: item }) }
                        }, (item: NovelItem) => `${item.id}_${item.title}`)
                      }
                      .padding({ left: 20, right: 20, bottom: 24 })
                    }
                  }
                }
              }
            }, (group: NovelGroup) => `${group.gid}_${group.title}`)

            ListItem() { Row().height(120) }
          }
          .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .onStateChange((state: RefreshStatus) => { this.refreshState = state; })
        .onRefreshing(async () => {
          await this.viewModel.fetchRecommends(true);
          this.isRefreshing = false;
        })
      }
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .onAreaChange((_: Area, newArea: Area) => {
      let w = newArea.width;
      if (typeof w === 'number') {
        this.isWideScreen = w > 600;
        this.containerWidth = w;
      }
    })
  }
}
