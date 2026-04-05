import router from '@ohos.router';
import { Constants } from '../common/Constants';
import { SeriesInfoData, SeriesArticle, SeriesEditor } from '../models/DataModels';
import { NovelRepository } from '../repository/NovelRepository';
import { T2SEngine } from '../utils/T2SEngine';
import { PreferenceManager } from '../utils/PreferenceManager';
import { PreloadEngine } from '../utils/PreloadEngine';
import common from '@ohos.app.ability.common';
import { ImageCacheManager } from '../utils/ImageCacheManager';
import { ImageSaveHelper } from '../utils/ImageSaveHelper';
import axios, { AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import { FileLog } from '../utils/FileLog';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct CollectionDetailView {
  @State seriesInfo: SeriesInfoData = new SeriesInfoData();
  @State isLoading: boolean = true;
  @State isError: boolean = false;
  @State pageTitle: string = '系列详情';
  @StorageLink('autoSimp') autoSimp: boolean = true;

  @State currentSid: number = 0;
  @State isUpdating: boolean = false;
  @State isRefreshing: boolean = false;
  @State refreshState: RefreshStatus = RefreshStatus.Inactive;
  @State lastUpdateTime: string = '';

  
  @State isPreviewOpen: boolean = false;
  @State previewImageUrl: string = '';
  
  @State currentAid: number = 0;
  private listScroller: Scroller = new Scroller();

  aboutToAppear() {
    let params = router.getParams() as Record<string, number | string | undefined>;
    let sid = params?.['sid'] as number | undefined;
    let title = params?.['title'] as string | undefined;
    let aid = params?.['currentAid'] as number | undefined;

    if (sid !== undefined) {
      this.currentSid = sid;
      if (title) this.pageTitle = title;
      if (aid !== undefined && aid > 0) this.currentAid = aid;
      this.loadData(sid);
    } else {
      this.isLoading = false;
      this.isError = true;
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
      FileLog.i('ImageSave', `合集详情图片保存: ${imageUrl.substring(0, 80)}`);

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
      let safeName = this.pageTitle.replace(/[\\/:*?"<>|]/g, '_').substring(0, 60);
      if (!safeName) safeName = '合集';
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

  private formatNumber(n: number): string {
    if (n >= 10000) {
      return (n / 10000).toFixed(1) + 'w';
    }
    return n.toString();
  }

  async loadData(sid: number, isRefresh: boolean = false) {
    let cacheKey = `cache_collection_v2_${sid}`;
    let timeKey = `time_collection_v2_${sid}`;

    if (!isRefresh) {
      this.isLoading = true;
      let cache = await PreferenceManager.getString(cacheKey, '');
      let time = await PreferenceManager.getString(timeKey, '');
      if (cache) {
        try {
          let obj: Object = JSON.parse(cache);
          let raw = obj as Record<string, Object>;
          // 简易恢复：至少恢复基础字段 + articles
          let cached = new SeriesInfoData();
          cached.sid = (raw['sid'] as number) ?? 0;
          cached.name = (raw['name'] as string) ?? '';
          cached.author = (raw['author'] as string) ?? '';
          cached.intro = (raw['intro'] as string) ?? '';
          cached.cover = (raw['cover'] as string) ?? '';
          cached.banner = (raw['banner'] as string) ?? '';
          cached.hits = (raw['hits'] as number) ?? 0;
          cached.likes = (raw['likes'] as number) ?? 0;
          cached.rate = (raw['rate'] as number) ?? 0;
          cached.rates = (raw['rates'] as number) ?? 0;
          cached.last_time = (raw['last_time'] as string) ?? '';

          let rawArticles = raw['articles'] as Record<string, Object>[];
          if (rawArticles && Array.isArray(rawArticles)) {
            for (let ra of rawArticles) {
              let a = new SeriesArticle();
              a.aid = (ra['aid'] as number) ?? 0;
              a.title = (ra['title'] as string) ?? '';
              a.cover = (ra['cover'] as string) ?? '';
              a.banner = (ra['banner'] as string) ?? '';
              a.hits = (ra['hits'] as number) ?? 0;
              a.comments = (ra['comments'] as number) ?? 0;
              a.time = (ra['time'] as string) ?? '';
              cached.articles.push(a);
            }
          }

          let rawEditors = raw['editors'] as Record<string, Object>[];
          if (rawEditors && Array.isArray(rawEditors)) {
            for (let re of rawEditors) {
              let e = new SeriesEditor();
              e.uid = (re['uid'] as number) ?? 0;
              e.nickname = (re['nickname'] as string) ?? '';
              e.avatar = (re['avatar'] as string) ?? '';
              cached.editors.push(e);
            }
          }

          this.seriesInfo = cached;
          if (cached.name) this.pageTitle = cached.name;
          this.isLoading = false;
          this.isError = false;
        } catch (e) {}
      }
      if (time) this.lastUpdateTime = time;
    }

    this.isUpdating = true;
    try {
      let res = await NovelRepository.getSeriesDetail(sid);
      this.seriesInfo = res;
      if (res.name) this.pageTitle = res.name;
      this.isError = false;
      let now = this.getFormattedTime();
      this.lastUpdateTime = now;
      PreferenceManager.putString(cacheKey, JSON.stringify(res));
      PreferenceManager.putString(timeKey, now);

      // ✨ 合集内文章批量预加载
      let aids: number[] = [];
      for (let i = 0; i < res.articles.length && i < 10; i++) {
        if (res.articles[i].aid) aids.push(res.articles[i].aid);
      }
      if (aids.length > 0) {
        PreloadEngine.enqueueBatch(aids, 3);
      }

      // ✨ 自动滚动到当前正在阅读的文章
      if (this.currentAid > 0 && !isRefresh) {
        this.scrollToCurrentArticle();
      }
    } catch (e) {
      if (this.seriesInfo.articles.length === 0) this.isError = true;
    } finally {
      this.isLoading = false;
      this.isUpdating = false;
    }
  }

  // ✨ 自动滚动到当前正在阅读的文章
  private scrollToCurrentArticle() {
    if (this.currentAid <= 0 || this.seriesInfo.articles.length === 0) return;
    let targetIndex = -1;
    for (let i = 0; i < this.seriesInfo.articles.length; i++) {
      if (this.seriesInfo.articles[i].aid === this.currentAid) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex < 0) return;

    // List 中有 2 个前置 ListItem（同步状态 + 合集头部），文章从 index=2 开始
    let listIndex = targetIndex + 2;
    setTimeout(() => {
      this.listScroller.scrollToIndex(listIndex, false);
    }, 300);
  }

  @Builder SeriesHeader() {
    Column() {
      // ✨ 封面横幅（点击可预览大图）
      Stack() {
        Image(this.seriesInfo.banner || this.seriesInfo.cover)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)

        // 渐变遮罩
        Column() {
          Blank()
        }
        .width('100%').height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['rgba(0,0,0,0)', 0.3], ['rgba(0,0,0,0.7)', 1.0]]
        })

        // 合集标题 + 作者
        Column() {
          Blank()
          Text(this.autoSimp ? T2SEngine.convert(this.seriesInfo.name) : this.seriesInfo.name)
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          if (this.seriesInfo.author) {
            Text(this.autoSimp ? T2SEngine.convert(this.seriesInfo.author) : this.seriesInfo.author)
              .fontSize(14).fontColor('#CCffffff')
              .margin({ top: 4 }).width('100%')
          }
        }
        .width('100%').height('100%')
        .padding({ left: 20, right: 20, bottom: 16 })
      }
      .width('100%').aspectRatio(2.4).borderRadius({ bottomLeft: 20, bottomRight: 20 }).clip(true)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      .onClick(() => {
        let url = this.seriesInfo.banner || this.seriesInfo.cover;
        if (url) {
          this.previewImageUrl = url;
          this.isPreviewOpen = true;
        }
      })

      // ✨ 统计信息行
      Row() {
        // 浏览量
        Row() {
          SymbolGlyph($r('sys.symbol.eye')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
          Text(this.formatNumber(this.seriesInfo.hits)).fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
        }

        // 点赞
        if (this.seriesInfo.likes > 0) {
          Row() {
            SymbolGlyph($r('sys.symbol.heart')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
            Text(this.formatNumber(this.seriesInfo.likes)).fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
          }.margin({ left: 16 })
        }

        // 篇数
        Row() {
          SymbolGlyph($r('sys.symbol.doc_text')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
          Text(`${this.seriesInfo.articles.length} 篇`).fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
        }.margin({ left: 16 })

        // 评分
        if (this.seriesInfo.rate > 0) {
          Row() {
            SymbolGlyph($r('sys.symbol.star_fill')).fontSize(14).fontColor(['#FFD700'])
            Text(`${this.seriesInfo.rate}`).fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
            if (this.seriesInfo.rates > 0) {
              Text(`(${this.seriesInfo.rates}人)`).fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ left: 2 })
            }
          }.margin({ left: 16 })
        }
      }
      .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 8 })

      // ✨ 简介
      if (this.seriesInfo.intro) {
        Text(this.autoSimp ? T2SEngine.convert(this.seriesInfo.intro) : this.seriesInfo.intro)
          .fontSize(14).fontColor(Constants.TEXT_SECONDARY).lineHeight(22)
          .width('100%').padding({ left: 20, right: 20, bottom: 12 })
          .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      // ✨ 编辑者
      if (this.seriesInfo.editors.length > 0) {
        Row() {
          Text('编辑').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ right: 8 })
          ForEach(this.seriesInfo.editors, (editor: SeriesEditor) => {
            Row() {
              Image(editor.avatar).width(20).height(20).borderRadius(10).objectFit(ImageFit.Cover)
                .margin({ right: 4 })
              Text(this.autoSimp ? T2SEngine.convert(editor.nickname) : editor.nickname)
                .fontSize(12).fontColor(Constants.THEME_COLOR)
            }
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
            .margin({ right: 10 })
            .onClick(() => {
              if (editor.uid > 0) {
                router.pushUrl({ url: 'pages/UserProfileView', params: { uid: editor.uid, isSelf: false } }).catch(() => {});
              }
            })
          }, (editor: SeriesEditor) => `editor_${editor.uid}`)
        }
        .width('100%').padding({ left: 20, right: 20, bottom: 12 })
        .alignItems(VerticalAlign.Center)
      }

      // 分割线 + 目录标题
      Row() {
        Rect({ width: 4, height: 16 }).radius(2).fill(Constants.THEME_COLOR).margin({ right: 8 })
        Text('目录').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
        Blank()
        Text(`共 ${this.seriesInfo.articles.length} 篇`).fontSize(12).fontColor(Constants.TEXT_SECONDARY)
      }
      .width('100%').padding({ left: 20, right: 20, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
  }

  build() {
    Stack() {
    Column() {
      // ✨ 导航栏
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor([Constants.TEXT_PRIMARY])
        }
        .width(44).height(44).justifyContent(FlexAlign.Center).margin({ left: 8 })
        .onClick(() => router.back())

        Text(this.autoSimp ? T2SEngine.convert(this.pageTitle) : this.pageTitle)
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
          .layoutWeight(1).textAlign(TextAlign.Center).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ right: 48 })
      }.width('100%').height(64).padding({ top: 20 })

      if (this.isLoading && !this.isRefreshing) {
        LoadingProgress().width(40).height(40).margin({ top: 100 }).color(Constants.THEME_COLOR)
      } else if (this.isError && this.seriesInfo.articles.length === 0) {
        Column() {
          Text('网络连接失败，请检查您的网络').fontSize(15).margin({ bottom: 20 }).fontColor(Constants.TEXT_SECONDARY)
          Button('重新加载').width(140).height(40).borderRadius(20)
            .backgroundColor(Constants.THEME_COLOR)
            .onClick(() => this.loadData(this.currentSid))
        }.width('100%').margin({ top: 140 }).alignItems(HorizontalAlign.Center)
      } else if (this.seriesInfo.articles.length === 0) {
        Text("该系列暂无单本").fontColor(Constants.TEXT_SECONDARY).margin({ top: 100 })
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ space: 0, scroller: this.listScroller }) {
            // 同步状态提示
            ListItem() {
              Row() {
                if (this.isUpdating || this.isRefreshing || this.refreshState === RefreshStatus.Refresh) {
                  LoadingProgress().width(12).height(12).color(Constants.THEME_COLOR).margin({ right: 6 })
                  Text("正在同步数据...").fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                } else if (this.refreshState === RefreshStatus.OverDrag) {
                  Text("松手可刷新").fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                } else if (this.lastUpdateTime) {
                  Text(`同步于 ${this.lastUpdateTime}`).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                }
              }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 4, bottom: 4 })
            }

            
            if (this.seriesInfo.name) {
              ListItem() {
                this.SeriesHeader()
              }
            }

            
            ForEach(this.seriesInfo.articles, (item: SeriesArticle, index: number) => {
              ListItem() {
                Row() {
                  
                  Text(`${index + 1}`)
                    .fontSize(14).fontWeight(FontWeight.Bold)
                    .fontColor(item.aid === this.currentAid ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                    .width(32).textAlign(TextAlign.Center)

                  
                  Image(item.cover || item.banner)
                    .width(56).height(75).borderRadius(8).objectFit(ImageFit.Cover)
                    .backgroundColor(Constants.PLACEHOLDER_BG)
                    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                    .onClick(() => {
                      let url = item.cover || item.banner;
                      if (url) {
                        this.previewImageUrl = url;
                        this.isPreviewOpen = true;
                      }
                    })

                  
                  Column() {
                    Text(this.autoSimp ? T2SEngine.convert(item.title) : item.title)
                      .fontSize(15).fontWeight(FontWeight.Medium)
                      .fontColor(item.aid === this.currentAid ? Constants.THEME_COLOR : Constants.TEXT_PRIMARY)
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

                    Blank()

                    Row() {
                      if (item.time) {
                        Text(item.time.substring(0, 10)).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                      }
                      Blank()
                      if (item.hits > 0) {
                        Row() {
                          SymbolGlyph($r('sys.symbol.eye')).fontSize(11).fontColor([Constants.TEXT_SECONDARY])
                          Text(`${item.hits}`).fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ left: 2 })
                        }
                      }
                      if (item.comments > 0) {
                        Row() {
                          Image($r('app.media.ic_comment')).width(11).height(11).fillColor(Constants.TEXT_SECONDARY)
                          Text(`${item.comments}`).fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ left: 2 })
                        }.margin({ left: 8 })
                      }
                    }.width('100%')
                  }
                  .layoutWeight(1).height(75).alignItems(HorizontalAlign.Start)
                  .margin({ left: 12 }).padding({ top: 2, bottom: 2 })
                }
                .width('100%').padding({ left: 12, right: 20, top: 10, bottom: 10 })
                .backgroundColor(item.aid === this.currentAid ? Constants.THEME_TINT_BG : Color.Transparent)
                .borderRadius(item.aid === this.currentAid ? 12 : 0)
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/ArticleDetail',
                    params: { aid: item.aid, sid: this.currentSid, collectionTitle: this.pageTitle }
                  }).catch(() => {});
                })
              }
            }, (item: SeriesArticle) => `${item.aid}_${item.title}`)

            
            ListItem() { Row().width('100%').height(100) }
          }
          .width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        }
        .width('100%').layoutWeight(1)
        .onStateChange((state: RefreshStatus) => { this.refreshState = state; })
        .onRefreshing(async () => {
          await this.loadData(this.currentSid, true);
          this.isRefreshing = false;
        })
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
