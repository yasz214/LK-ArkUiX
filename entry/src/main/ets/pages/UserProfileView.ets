import { Constants } from '../common/Constants';
import router from '@ohos.router';
import { UserProfileData, UserArticleItem } from '../models/DataModels';
import { NovelRepository } from '../repository/NovelRepository';
import { T2SEngine } from '../utils/T2SEngine';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import common from '@ohos.app.ability.common';
import { ImageCacheManager } from '../utils/ImageCacheManager';
import { ImageSaveHelper } from '../utils/ImageSaveHelper';
import axios, { AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import { FileLog } from '../utils/FileLog';

const TAG = 'UserProfileView';
const DOMAIN = 0x0001;

@Entry
@Component
struct UserProfileView {
  @State profile: UserProfileData | null = null;
  @State isLoading: boolean = true;
  @State activeTab: number = 0; 
  @State bookArticles: UserArticleItem[] = [];
  @State otherArticles: UserArticleItem[] = [];
  @State bookPage: number = 1;
  @State otherPage: number = 1;
  @State bookHasMore: boolean = false;
  @State otherHasMore: boolean = false;
  @State isLoadingArticles: boolean = false;
  @State isFollowed: boolean = false;
  @StorageLink('autoSimp') autoSimp: boolean = true;

  
  @State isPreviewOpen: boolean = false;
  @State previewImageUrl: string = '';

  private targetUid: number = 0;
  private isSelf: boolean = false;
  private scroller: Scroller = new Scroller();
  
  private isSwiping: boolean = false;

  aboutToAppear() {
    let params = router.getParams() as Record<string, number | boolean>;
    if (params) {
      this.targetUid = (params['uid'] as number) ?? 0;
      this.isSelf = (params['isSelf'] as boolean) ?? false;
    }
    if (this.targetUid > 0) {
      this.loadProfile();
      this.loadArticles(0);
    } else {
      this.isLoading = false;
    }
  }

  
  onBackPress(): boolean {
    if (this.isPreviewOpen) {
      this.isPreviewOpen = false;
      return true;
    }
    return false;
  }

  
  async downloadAndSaveImage(imageUrl: string) {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      FileLog.i('ImageSave', `用户主页图片保存: ${imageUrl.substring(0, 80)}`);

      let ext = '.jpg';
      let urlLower = imageUrl.toLowerCase();
      if (urlLower.indexOf('.png') !== -1) ext = '.png';
      else if (urlLower.indexOf('.webp') !== -1) ext = '.webp';
      else if (urlLower.indexOf('.gif') !== -1) ext = '.gif';

      let buffer: ArrayBuffer | null = await ImageCacheManager.waitAndGetBuffer(imageUrl);

      if (buffer && buffer.byteLength > 0) {
        FileLog.i('ImageSave', `缓存获取成功, 大小=${buffer.byteLength}`);
      } else {
        FileLog.w('ImageSave', '缓存获取失败，降级HTTP下载');
        try { promptAction.openToast({ message: '正在下载图片...' }); } catch { }
        let config: AxiosRequestConfig<null> = { url: imageUrl, method: 'get', responseType: 'array_buffer', timeout: 30000 };
        let res: AxiosResponse<ArrayBuffer> = await axios.request<ArrayBuffer, AxiosResponse<ArrayBuffer>, null>(config);
        buffer = res.data;
      }

      if (buffer.byteLength === 0) {
        try { promptAction.openToast({ message: '下载失败：文件为空' }); } catch { }
        return;
      }

      let timestamp = new Date().getTime();
      let profileName: string = this.profile !== null ? this.profile.nickname : '用户主页';
      let safeName = profileName.replace(/[\\/:*?"<>|]/g, '_').substring(0, 60);
      let tempFileName = `${safeName}_${timestamp}${ext}`;
      let tempPath = ctx.tempDir + '/' + tempFileName;

      try {
        let tempFile = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        fs.writeSync(tempFile.fd, buffer);
        fs.closeSync(tempFile);
      } catch (writeErr) {
        let we = writeErr as Error;
        FileLog.e('ImageSave', `写入临时文件失败: ${we.message}`);
        try { promptAction.openToast({ message: '保存失败：无法写入临时文件' }); } catch { }
        return;
      }

      try {
        let documentSaveOptions = new picker.DocumentSaveOptions();
        documentSaveOptions.newFileNames = [tempFileName];
        let documentPicker = new picker.DocumentViewPicker(ctx);
        let saveResult = await documentPicker.save(documentSaveOptions);

        if (saveResult && saveResult.length > 0) {
          let targetUri = saveResult[0];

          if (targetUri.startsWith('content://')) {
            try {
              let bridgeSuccess = await ImageSaveHelper.saveViaContentResolver(targetUri, buffer);
              if (bridgeSuccess) {
                try { promptAction.openToast({ message: '保存成功', duration: 3000 }); } catch { }
                try { fs.unlinkSync(tempPath); } catch (_e) {}
                return;
              }
            } catch (bridgeErr) {
              let be = bridgeErr as Error;
              FileLog.w('ImageSave', `Bridge异常: ${be.message}`);
            }
          }

          try {
            let targetFile = fs.openSync(targetUri, fs.OpenMode.WRITE_ONLY);
            fs.writeSync(targetFile.fd, buffer);
            fs.closeSync(targetFile);
            try { promptAction.openToast({ message: '保存成功', duration: 3000 }); } catch { }
            try { fs.unlinkSync(tempPath); } catch (_e) {}
            return;
          } catch (err1b) {
            let e1b = err1b as Error;
            FileLog.e('ImageSave', `fs写入失败: ${e1b.message}`);
          }

          try { promptAction.openToast({ message: '保存失败，请查看调试日志', duration: 5000 }); } catch { }
        }
      } catch (docErr) {
        let de = docErr as Error;
        FileLog.e('ImageSave', `DocumentViewPicker异常: ${de.message}`);
        try { promptAction.openToast({ message: '保存失败' }); } catch { }
      }

      try { fs.unlinkSync(tempPath); } catch (_e) {}
    } catch (e) {
      let err = e as Error;
      FileLog.e('ImageSave', `图片保存顶层异常: ${err.message}`);
      try { promptAction.openToast({ message: '图片保存失败' }); } catch { }
    }
  }

  async loadProfile() {
    this.isLoading = true;
    try {
      let data = await NovelRepository.getUserProfile(this.targetUid);
      this.profile = data;
      this.isFollowed = data.followed === 1;
    } catch (e) {
      hilog.error(DOMAIN, TAG, `加载用户信息失败: ${(e as Error).message}`);
    } finally {
      this.isLoading = false;
    }
  }

  async loadArticles(type: number, isLoadMore: boolean = false) {
    if (this.isLoadingArticles) return;
    this.isLoadingArticles = true;

    try {
      let page = isLoadMore ? (type === 0 ? this.bookPage + 1 : this.otherPage + 1) : 1;
      
      let result = await NovelRepository.getUserArticles(this.targetUid, page, type);

      let items = result.list;
      if (isLoadMore) {
        if (type === 0) {
          for (let item of items) this.bookArticles.push(item);
          this.bookPage = result.page_info.cur;
        } else {
          for (let item of items) this.otherArticles.push(item);
          this.otherPage = result.page_info.cur;
        }
      } else {
        if (type === 0) {
          this.bookArticles = items;
          this.bookPage = result.page_info.cur;
        } else {
          this.otherArticles = items;
          this.otherPage = result.page_info.cur;
        }
      }

      if (type === 0) {
        this.bookHasMore = result.page_info.has_next === 1;
      } else {
        this.otherHasMore = result.page_info.has_next === 1;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `加载文章列表失败`);
    } finally {
      this.isLoadingArticles = false;
    }
  }

  private getDisplayText(text: string): string {
    if (!text) return '';
    return this.autoSimp ? T2SEngine.convert(text) : text;
  }

  private getExpProgress(): number {
    if (!this.profile || !this.profile.level) return 0;
    let currentExp = this.profile.level.exp;
    let nextExp = this.profile.level.next_exp;
    
    let currentLevelExp = 0;
    if (this.profile.all_level && this.profile.all_level.length > 0) {
      for (let entry of this.profile.all_level) {
        if (entry.level === this.profile.level.level) {
          currentLevelExp = entry.exp;
          break;
        }
      }
    } else {
      
      let levelExps: number[] = [0, 0, 251, 1001, 2001, 4501, 8001, 12501, 18001, 50001];
      let lvl = this.profile.level.level;
      if (lvl >= 0 && lvl < levelExps.length) {
        currentLevelExp = levelExps[lvl];
      }
    }

    if (nextExp <= currentLevelExp) return 1;
    let progress = (currentExp - currentLevelExp) / (nextExp - currentLevelExp);
    return Math.max(0, Math.min(1, progress));
  }

  private formatTime(time: string): string {
    if (!time || time.length < 10) return time;
    return time.substring(0, 10);
  }

  async doFollow() {
    if (!this.profile) return;
    let act = this.isFollowed ? 1 : 0;
    let success = await NovelRepository.toggleFollow(this.targetUid, act);
    if (success) {
      this.isFollowed = !this.isFollowed;
      promptAction.openToast({ message: this.isFollowed ? `已关注 ${this.profile.nickname}` : '已取消关注' });
    } else {
      promptAction.openToast({ message: '操作失败，请检查登录状态' });
    }
  }

  @Builder ArticleCardBuilder(article: UserArticleItem) {
    Row() {
      
      if (article.cover && article.cover !== '') {
        Image(article.cover)
          .width(80).height(107)
          .borderRadius(8).objectFit(ImageFit.Cover)
          .backgroundColor(Constants.CARD_BG_COLOR)
      } else if (article.banner && article.banner !== '') {
        Image(article.banner)
          .width(80).height(107)
          .borderRadius(8).objectFit(ImageFit.Cover)
          .backgroundColor(Constants.CARD_BG_COLOR)
      } else {
        Column() {
          Text(article.title.substring(0, 1))
            .fontSize(24).fontColor(Color.White).fontWeight(FontWeight.Bold)
        }
        .width(80).height(107).borderRadius(8)
        .backgroundColor(Constants.THEME_COLOR)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }

      
      Column() {
        Text(this.getDisplayText(article.title))
          .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Blank()

        if (article.group_name && article.group_name !== '' && article.group_name !== 'undefined') {
          Text(this.getDisplayText(article.group_name))
            .fontSize(11).fontColor(Constants.THEME_COLOR)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(Constants.THEME_TINT_BG)            .borderRadius(4)
        }

        Row() {
          if (article.coins > 0) {
            Row() {
              SymbolGlyph($r('sys.symbol.star_fill')).fontSize(11).fontColor(['#FFD700'])
              Text(` ${article.coins}`).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
            }
            .margin({ right: 12 })
          }
          Text(this.formatTime(article.time))
            .fontSize(11).fontColor(Constants.TEXT_SECONDARY)
        }
      }
      .layoutWeight(1).height(107)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 16, right: 16 })
    .backgroundColor(Constants.CARD_BG_COLOR)
    .borderRadius(12)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => {
      
      if (this.isSwiping) return;

      if (article.sid > 0) {
        router.pushUrl({ url: 'pages/CollectionDetailView', params: { sid: article.sid } }).catch(() => {});
      } else {
        router.pushUrl({ url: 'pages/ArticleDetail', params: { aid: article.aid } }).catch(() => {});
      }
    })
  }

  @Builder ExpBarBuilder(exp: number, nextExp: number, level: number, levelName: string) {
    Column() {
      Row() {
        Text(`Lv.${level} ${this.getDisplayText(levelName)}`)
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Constants.THEME_COLOR)
        Blank()
        Text(`${exp} / ${nextExp}`)
          .fontSize(11).fontColor(Constants.TEXT_SECONDARY)
      }.width('100%')

      Stack({ alignContent: Alignment.Start }) {
        
        Row().width('100%').height(6).borderRadius(3)
          .backgroundColor(Constants.EXP_BAR_BG)
        
        Row().width(`${this.getExpProgress() * 100}%`).height(6).borderRadius(3)
          .backgroundColor(Constants.THEME_COLOR)
      }
      .width('100%').height(6).margin({ top: 6 })
    }.width('100%')
  }

  build() {
    Stack() {
    Column() {
      
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor([Constants.TEXT_PRIMARY])
        }
        .width(44).height(44).justifyContent(FlexAlign.Center).borderRadius(22)
        .backgroundColor($r('app.color.acrylic_tint')).margin({ left: 16 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => router.back())

        Text(this.profile ? this.profile.nickname : '个人主页')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ right: 60 })
      }
      .width('100%').height(64).padding({ top: 20 })
      .zIndex(10)

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48).color(Constants.THEME_COLOR)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (!this.profile) {
        Column() {
          Text('无法加载用户信息').fontSize(16).fontColor(Constants.TEXT_SECONDARY)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12, scroller: this.scroller }) {
          
          ListItem() {
            Stack({ alignContent: Alignment.Bottom }) {
              
              Image(this.profile!.banner || 'https://static.lightnovel.fun/bg.jpg')
                .width('100%').height(200)
                .objectFit(ImageFit.Cover)
                .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 20, bottomRight: 20 })
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
                .onClick(() => {
                  let url = this.profile!.banner || 'https://static.lightnovel.fun/bg.jpg';
                  if (url) {
                    this.previewImageUrl = url;
                    this.isPreviewOpen = true;
                  }
                })

              
              Column()
                .width('100%').height(100)
                .linearGradient({
                  angle: 180,
                  colors: [['rgba(0,0,0,0)', 0], ['rgba(0,0,0,0.5)', 1]]
                })

              
              Column() {
                Row() {
                  
                  Image(this.profile!.avatar || '')
                    .width(72).height(72).borderRadius(36)
                    .border({ width: 3, color: Color.White })
                    .objectFit(ImageFit.Cover)
                    .backgroundColor(Constants.PLACEHOLDER_BG)
                    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                    .onClick(() => {
                      let url = this.profile!.avatar || '';
                      if (url) {
                        this.previewImageUrl = url;
                        this.isPreviewOpen = true;
                      }
                    })

                  Column() {
                    Text(this.profile!.nickname)
                      .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .shadow({ radius: 4, color: 'rgba(0,0,0,0.5)', offsetY: 1 })

                    Row() {
                      Text(`UID: ${this.profile!.uid}`)
                        .fontSize(12).fontColor('rgba(255,255,255,0.85)')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor('rgba(255,255,255,0.15)')
                        .borderRadius(6)
                      if (this.profile!.passer === 1) {
                        Text('Passer')
                          .fontSize(11).fontColor('#FFD700').fontWeight(FontWeight.Bold)
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .backgroundColor('rgba(255, 215, 0, 0.2)')
                          .borderRadius(6).margin({ left: 6 })
                      }
                    }.margin({ top: 4 })
                  }
                  .margin({ left: 14 }).alignItems(HorizontalAlign.Start).layoutWeight(1)

                  
                  if (!this.isSelf) {
                    Button(this.isFollowed ? '已关注' : '+ 关注')
                      .fontSize(13).fontWeight(FontWeight.Medium)
                      .height(32).borderRadius(16)
                      .backgroundColor(this.isFollowed ? 'rgba(255,255,255,0.2)' : Constants.THEME_COLOR)
                      .fontColor(Color.White)
                      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                      .onClick(() => this.doFollow())
                  }
                }
                .width('100%').padding({ left: 20, right: 20, bottom: 16 })
              }
              .width('100%')
            }
            .width('100%')
          }

          
          if (this.profile!.sign && this.profile!.sign !== '') {
            ListItem() {
              Row() {
                Image($r('app.media.ic_sign'))
                  .width(16).height(16).fillColor(Constants.TEXT_SECONDARY).margin({ right: 8 })
                Text(this.getDisplayText(this.profile!.sign))
                  .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                  .fontStyle(FontStyle.Italic)
                  .layoutWeight(1)
              }
              .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12)
              .margin({ left: 16, right: 16 })
            }
          }

          
          ListItem() {
            Column() {
              this.ExpBarBuilder(
                this.profile!.level.exp,
                this.profile!.level.next_exp,
                this.profile!.level.level,
                this.profile!.level.name
              )
            }
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12)
            .margin({ left: 16, right: 16 })
          }

          
          ListItem() {
            Row() {
              Column() {
                Text(`${this.profile!.articles}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.THEME_COLOR)
                Text('发帖').fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Center)

              Column() {
                Text(`${this.profile!.followers}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.THEME_COLOR)
                Text('粉丝').fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Center)

              Column() {
                Text(`${this.profile!.following}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.THEME_COLOR)
                Text('关注').fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Center)
            }
            .width('100%').padding({ top: 14, bottom: 14 })
            .backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12)
            .margin({ left: 16, right: 16 })
          }

          
          ListItem() {
            Column() {
              Row() {
                
                Column() {
                  Text('图书')
                    .fontSize(15).fontWeight(this.activeTab === 0 ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.activeTab === 0 ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                    .padding({ top: 10, bottom: 10 })
                  
                  Row()
                    .width(24).height(3).borderRadius(1.5)
                    .backgroundColor(this.activeTab === 0 ? Constants.THEME_COLOR : Color.Transparent)
                }
                .padding({ left: 16, right: 16 })
                .onClick(() => {
                  if (this.activeTab !== 0) {
                    this.activeTab = 0;
                    if (this.bookArticles.length === 0) this.loadArticles(0);
                  }
                })

                
                Column() {
                  Text('其他')
                    .fontSize(15).fontWeight(this.activeTab === 1 ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.activeTab === 1 ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                    .padding({ top: 10, bottom: 10 })
                  
                  Row()
                    .width(24).height(3).borderRadius(1.5)
                    .backgroundColor(this.activeTab === 1 ? Constants.THEME_COLOR : Color.Transparent)
                }
                .padding({ left: 16, right: 16 })
                .onClick(() => {
                  if (this.activeTab !== 1) {
                    this.activeTab = 1;
                    if (this.otherArticles.length === 0) this.loadArticles(1);
                  }
                })
              }
              .width('100%').padding({ left: 16, right: 16 })
            }
          }

          
          if (this.activeTab === 0) {
            ForEach(this.bookArticles, (article: UserArticleItem) => {
              ListItem() {
                Column() {
                  this.ArticleCardBuilder(article)
                }.margin({ left: 16, right: 16 })
              }
            }, (article: UserArticleItem) => `book_${article.aid}`)

            if (this.bookArticles.length === 0 && !this.isLoadingArticles) {
              ListItem() {
                Text('暂无内容')
                  .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                  .width('100%').textAlign(TextAlign.Center)
                  .padding({ top: 40, bottom: 40 })
              }
            }

            if (this.bookHasMore) {
              ListItem() {
                Row() {
                  if (this.isLoadingArticles) {
                    LoadingProgress().width(16).height(16).color(Constants.THEME_COLOR).margin({ right: 8 })
                    Text('加载中...').fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                  } else {
                    Text('加载更多').fontSize(14).fontColor(Constants.THEME_COLOR)
                      .onClick(() => this.loadArticles(0, true))
                  }
                }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 16, bottom: 16 })
              }
            }
          } else {
            ForEach(this.otherArticles, (article: UserArticleItem) => {
              ListItem() {
                Column() {
                  this.ArticleCardBuilder(article)
                }.margin({ left: 16, right: 16 })
              }
            }, (article: UserArticleItem) => `other_${article.aid}`)

            if (this.otherArticles.length === 0 && !this.isLoadingArticles) {
              ListItem() {
                Text('暂无内容')
                  .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                  .width('100%').textAlign(TextAlign.Center)
                  .padding({ top: 40, bottom: 40 })
              }
            }

            if (this.otherHasMore) {
              ListItem() {
                Row() {
                  if (this.isLoadingArticles) {
                    LoadingProgress().width(16).height(16).color(Constants.THEME_COLOR).margin({ right: 8 })
                    Text('加载中...').fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                  } else {
                    Text('加载更多').fontSize(14).fontColor(Constants.THEME_COLOR)
                      .onClick(() => this.loadArticles(1, true))
                  }
                }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 16, bottom: 16 })
              }
            }
          }

          if (this.isLoadingArticles && (this.activeTab === 0 ? this.bookArticles.length : this.otherArticles.length) === 0) {
            ListItem() {
              Row() {
                LoadingProgress().width(24).height(24).color(Constants.THEME_COLOR)
              }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 40, bottom: 40 })
            }
          }

          
          ListItem() { Row().height(100) }
        }
        .width('100%').layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
        
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
              if (offsetX > 50 && this.activeTab === 1) {
                
                this.activeTab = 0;
                if (this.bookArticles.length === 0) this.loadArticles(0);
              } else if (offsetX < -50 && this.activeTab === 0) {
                
                this.activeTab = 1;
                if (this.otherArticles.length === 0) this.loadArticles(1);
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
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

    
    if (this.isPreviewOpen) {
      Column() {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#CC000000')
            .onClick(() => {
              this.isPreviewOpen = false;
            })

          Image(this.previewImageUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .onClick(() => {
              this.isPreviewOpen = false;
            })

          
          Button('保存到设备')
            .backgroundColor(Color.White).fontColor(Color.Black)
            .fontSize(16).fontWeight(FontWeight.Bold)
            .margin({ bottom: 48 }).width(160).height(44).borderRadius(22)
            .shadow({ radius: 16, color: 'rgba(0,0,0,0.3)', offsetY: 4 })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              this.downloadAndSaveImage(this.previewImageUrl);
            })
        }
        .width('100%').height('100%')
      }
      .width('100%').height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .transition(TransitionEffect.opacity(0).animation({ duration: 200 }))
    }
    }
    .width('100%').height('100%')
  }
}
