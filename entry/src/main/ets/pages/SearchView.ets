import { curves, promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import { NovelRepository } from '../repository/NovelRepository';
import { SearchArticle, SearchCollection, SearchTag } from '../models/DataModels';
import { Constants } from '../common/Constants';
import { PreferenceManager } from '../utils/PreferenceManager';
import { T2SEngine } from '../utils/T2SEngine';

@Entry
@Component
struct SearchView {
  @State keyword: string = '';
  @State isLoading: boolean = false;
  @State articles: SearchArticle[] = [];
  @State collections: SearchCollection[] = [];
  @State searchHistory: string[] = [];

  @StorageLink('autoSimp') autoSimp: boolean = true;
  
  @StorageLink('security_key') securityKey: string = '';

  @State isDraggingMode: boolean = false;
  @State draggedItem: string | null = null;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State isHoveringDelete: boolean = false;

  
  @State hotTags: SearchTag[] = [];

  
  private deleteAreaCoord: Record<string, number> = { 'x': 0, 'y': 0, 'w': 0, 'h': 0 };

  async aboutToAppear() {
    let historyStr = await PreferenceManager.getString('searchHistory', '[]');
    try {
      this.searchHistory = JSON.parse(historyStr);
    } catch(e) { }

    
    try {
      let cached = AppStorage.get<string>('cachedHotTags');
      if (cached) {
        this.hotTags = JSON.parse(cached) as SearchTag[];
      }
    } catch (e) { }

    
    try {
      let tags = await NovelRepository.getSearchTags();
      if (tags.length > 0) {
        this.hotTags = tags;
        AppStorage.setOrCreate('cachedHotTags', JSON.stringify(tags));
      }
    } catch (e) { }
  }

  checkHit(touchX: number, touchY: number): boolean {
    const ax = this.deleteAreaCoord['x'];
    const ay = this.deleteAreaCoord['y'];
    const aw = this.deleteAreaCoord['w'];
    const ah = this.deleteAreaCoord['h'];
    return touchX >= ax && touchX <= (ax + aw) && touchY >= ay && touchY <= (ay + ah);
  }

  async saveHistory(kw: string) {
    if (!kw.trim()) return;
    let idx = this.searchHistory.indexOf(kw);
    if (idx !== -1) {
      this.searchHistory.splice(idx, 1);
    }
    this.searchHistory.unshift(kw);
    if (this.searchHistory.length > 12) this.searchHistory.pop();

    PreferenceManager.putString('searchHistory', JSON.stringify(this.searchHistory));
  }

  clearHistory() {
    this.searchHistory = [];
    PreferenceManager.putString('searchHistory', '[]');
    promptAction.openToast({ message: '历史记录已清空' });
  }

  async performSearch() {
    
    if (!this.securityKey) {
      promptAction.openToast({ message: '搜索功能需要登录后使用' });
      
      router.pushUrl({ url: 'pages/AuthView' }).catch(() => {});
      return; 
    }

    if (!this.keyword.trim()) return;
    this.saveHistory(this.keyword.trim());
    this.isLoading = true;
    try {
      let res = await NovelRepository.searchNovels(this.keyword);
      this.articles = res.articles || [];
      this.collections = res.collections || [];

      if (this.articles.length === 0 && this.collections.length === 0) {
        promptAction.openToast({ message: '没有找到相关内容' });
      }
    } catch (e) {
      promptAction.openToast({ message: '搜索失败' });
    } finally {
      this.isLoading = false;
    }
  }

  @Builder Header(text: string) {
    Text(text)
      .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Constants.THEME_COLOR)
      .padding({ top: 16, bottom: 8, left: 4 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
    Column() {
      
      Row() {
        Text("❮")
          .fontSize(22)
          .fontColor(Constants.TEXT_PRIMARY)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => router.back())

        TextInput({ placeholder: '搜索小说...', text: this.keyword })
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Constants.CARD_BG_COLOR)
          .borderRadius(22)
          .enterKeyType(EnterKeyType.Search)
          .margin({ left: 4, right: 4 })
          .onChange((val) => {
            this.keyword = val;
            if (val === '') {
              this.articles = [];
              this.collections = [];
            }
          })
          .onSubmit(() => this.performSearch())

        Text("搜索")
          .fontSize(16)
          .fontColor(Constants.THEME_COLOR)
          .width(52)
          .height(44)
          .textAlign(TextAlign.Center)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => this.performSearch())
      }
      .width('100%')
      .height(88)
      .padding({ top: 36, bottom: 8, left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        LoadingProgress().width(40).height(40).margin({ top: 100 }).color(Constants.THEME_COLOR)
      } else if (this.keyword === '' && this.articles.length === 0 && this.collections.length === 0) {
        List() {
          
          if (this.searchHistory.length > 0) {
            ListItem() {
              Column() {
                Row() {
                  Text("搜索历史").fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
                  Blank()
                  Stack() {
                    if (!this.isDraggingMode) {
                      SymbolGlyph($r('sys.symbol.trash'))
                        .fontSize(20).fontColor([Constants.TEXT_SECONDARY])
                        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.8 })
                        .onClick(() => this.clearHistory())
                        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.5, y: 0.5 })))
                    }
                  }
                  .width(60).height(60)
                  .margin({ right: -12, top: -12 })
                }.width('100%').height(60).alignItems(VerticalAlign.Center)

                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.searchHistory, (hist: string) => {
                    Text(this.autoSimp ? T2SEngine.convert(hist) : hist)
                      .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                      .backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
                      .margin({ right: 10, bottom: 10 })
                      .zIndex(hist === this.draggedItem ? 100 : 1)
                      .opacity(hist === this.draggedItem ? 0.8 : 1)
                      .scale({
                        x: hist === this.draggedItem ? 1.1 : 1,
                        y: hist === this.draggedItem ? 1.1 : 1
                      })
                      .translate({
                        x: hist === this.draggedItem ? this.offsetX : 0,
                        y: hist === this.draggedItem ? this.offsetY : 0
                      })
                      .animation({ duration: 250, curve: curves.springMotion() })
                      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                      
                      .onClick(() => {
                        this.keyword = hist;
                        this.performSearch();
                      })
                      
                      .parallelGesture(
                        GestureGroup(GestureMode.Sequence,
                          LongPressGesture({ repeat: false })
                            .onAction(() => {
                              this.draggedItem = hist;
                              animateTo({ duration: 300, curve: curves.springMotion() }, () => {
                                this.isDraggingMode = true;
                              })
                              promptAction.openToast({ message: '可拖拽至底部垃圾桶删除' });
                            }),
                          PanGesture()
                            .onActionUpdate((event: GestureEvent) => {
                              this.offsetX = event.offsetX;
                              this.offsetY = event.offsetY;
                              if (event.fingerList && event.fingerList.length > 0) {
                                const touch = event.fingerList[0];
                                this.isHoveringDelete = this.checkHit(touch.globalX, touch.globalY);
                              }
                            })
                            .onActionEnd((event: GestureEvent) => {
                              let droppedOnDelete = false;
                              if (event.fingerList && event.fingerList.length > 0) {
                                const touch = event.fingerList[0];
                                droppedOnDelete = this.checkHit(touch.globalX, touch.globalY);
                              }
                              
                              if (!droppedOnDelete && this.isHoveringDelete) {
                                droppedOnDelete = true;
                              }
                              if (droppedOnDelete) {
                                let idx = this.searchHistory.indexOf(hist);
                                if (idx !== -1) {
                                  this.searchHistory.splice(idx, 1);
                                  PreferenceManager.putString('searchHistory', JSON.stringify(this.searchHistory));
                                  promptAction.openToast({ message: '已删除该搜索记录' });
                                }
                              }
                              animateTo({ duration: 300, curve: curves.springMotion() }, () => {
                                this.isDraggingMode = false;
                                this.isHoveringDelete = false;
                                this.draggedItem = null;
                                this.offsetX = 0;
                                this.offsetY = 0;
                              })
                            })
                        )
                      )
                      
                      .onTouch((event: TouchEvent) => {
                        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                          if (this.isDraggingMode && this.draggedItem === hist) {
                            
                            setTimeout(() => {
                              if (this.isDraggingMode) {
                                animateTo({ duration: 300, curve: curves.springMotion() }, () => {
                                  this.isDraggingMode = false;
                                  this.isHoveringDelete = false;
                                  this.draggedItem = null;
                                  this.offsetX = 0;
                                  this.offsetY = 0;
                                })
                              }
                            }, 100);
                          }
                        }
                      })
                  }, (hist: string) => hist)
                }.width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)
            }
          }

          
          if (this.hotTags.length > 0) {
            ListItem() {
              Column() {
                Text("热门搜索").fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
                  .margin({ bottom: 12 })

                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.hotTags, (tag: SearchTag, index: number) => {
                    Row() {
                      Text(`${index + 1}`)
                        .fontSize(12).fontWeight(FontWeight.Bold)
                        .fontColor(index < 3 ? Color.White : Constants.TEXT_SECONDARY)
                        .backgroundColor(index < 3 ? Constants.THEME_COLOR : Constants.THEME_TINT_BG_STRONG)
                        .width(22).height(22).borderRadius(11)
                        .textAlign(TextAlign.Center)
                        .margin({ right: 6 })
                      Text(this.autoSimp ? T2SEngine.convert(tag.alias) : tag.alias)
                        .fontSize(14).fontColor(Constants.TEXT_PRIMARY)
                    }
                    .padding({ left: 10, right: 14, top: 8, bottom: 8 })
                    .backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
                    .margin({ right: 10, bottom: 10 })
                    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                    .onClick(() => {
                      this.keyword = tag.alias;
                      this.performSearch();
                    })
                  }, (tag: SearchTag) => `tag_${tag.id}`)
                }.width('100%')
              }.width('100%').alignItems(HorizontalAlign.Start)
            }
          }
        }
        .padding(20).layoutWeight(1).edgeEffect(EdgeEffect.Spring).scrollBar(BarState.Off)
      } else if (this.articles.length === 0 && this.collections.length === 0 && this.keyword !== '') {
        Text("没有找到相关小说").fontColor(Constants.TEXT_SECONDARY).margin({ top: 100 })
      } else {
        List({ space: 16 }) {
          if (this.collections.length > 0) {
            ListItemGroup({ header: this.Header('小说合集') }) {
              ForEach(this.collections, (item: SearchCollection) => {
                ListItem() {
                  Row() {
                    Image(item.cover).width(60).height(80).borderRadius(8).objectFit(ImageFit.Cover)
                    Column() {
                      Row() {
                        Text('合集').fontSize(10).fontColor(Color.White).backgroundColor(Constants.THEME_COLOR).padding(4).borderRadius(4).margin({ right: 6 })
                        Text(this.autoSimp ? T2SEngine.convert(item.name) : item.name)
                          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY).maxLines(2).layoutWeight(1)
                      }
                      Blank()
                      Text(`作者: ${item.author || '未知'}`).fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                    }
                    .layoutWeight(1).height(80).alignItems(HorizontalAlign.Start).margin({ left: 16 }).padding({ top: 4, bottom: 4 })
                  }
                  .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                  .onClick(() => {
                    router.pushUrl({
                      url: 'pages/CollectionDetailView',
                      params: { sid: item.sid, title: item.name }
                    }).catch(()=>{});
                  })
                }
              }, (item: SearchCollection) => `col_${item.sid}`)
            }
          }

          if (this.articles.length > 0) {
            ListItemGroup({ header: this.Header('单本章节') }) {
              ForEach(this.articles, (item: SearchArticle) => {
                ListItem() {
                  Row() {
                    Image(item.cover).width(60).height(80).borderRadius(8).objectFit(ImageFit.Cover)
                    Column() {
                      Text(this.autoSimp ? T2SEngine.convert(item.title) : item.title)
                        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY).maxLines(2)
                      Blank()
                      Text(`作者: ${item.author || '未知'}`).fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                    }
                    .layoutWeight(1).height(80).alignItems(HorizontalAlign.Start).margin({ left: 16 }).padding({ top: 4, bottom: 4 })
                  }
                  .width('100%').padding(16).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(16)
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                  .onClick(() => router.pushUrl({ url: 'pages/ArticleDetail', params: { aid: item.aid } }).catch(()=>{}))
                }
              }, (item: SearchArticle) => `art_${item.aid}`)
            }
          }
        }.padding(16).layoutWeight(1).edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)

      
      if (this.isDraggingMode) {
        Column() {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(this.isHoveringDelete ? 48 : 36)
            .fontColor(this.isHoveringDelete ? [Color.White] : ['rgba(255, 59, 48, 0.8)'])
            .animation({ duration: 200, curve: curves.springMotion() })
          Text(this.isHoveringDelete ? '松手删除' : '拖到这里删除')
            .fontSize(13).fontColor(this.isHoveringDelete ? Color.White : '#FF3B30')
            .margin({ top: 6 })
        }
        .width(140).height(100).borderRadius(20)
        .backgroundColor(this.isHoveringDelete ? '#FF3B30' : 'rgba(255, 59, 48, 0.08)')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .margin({ bottom: 80 })
        .shadow({ radius: 24, color: 'rgba(255, 59, 48, 0.2)', offsetY: 8 })
        .animation({ duration: 300, curve: curves.springMotion() })
        .onAreaChange((_, area) => {
          this.deleteAreaCoord['x'] = area.globalPosition.x as number;
          this.deleteAreaCoord['y'] = area.globalPosition.y as number;
          this.deleteAreaCoord['w'] = area.width as number;
          this.deleteAreaCoord['h'] = area.height as number;
        })
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 100 })))
      }
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}