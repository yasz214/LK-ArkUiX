import { curves, promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { ContentItem, RichSpan, CommentItem, CommentReply, SearchArticle } from '../models/DataModels';
import { DetailViewModel } from '../viewmodel/DetailViewModel';
import { Constants } from '../common/Constants';
import { T2SEngine } from '../utils/T2SEngine';
import { ImageCacheManager } from '../utils/ImageCacheManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { FontManager } from '../utils/FontManager';
import { NativeArticleParser } from '../utils/NativeArticleParser';
import { NovelRepository } from '../repository/NovelRepository';
import { ConfigurationConstant } from '@kit.AbilityKit';

import { FileLog } from '../utils/FileLog';
import { openUrl } from '../utils/BrowserHelper';
import webview from '@ohos.web.webview';

@Entry
@Component
struct ArticleDetail {
  @State viewModel: DetailViewModel = new DetailViewModel();
  @State previewImageUrl: string = '';
  @State isPreviewOpen: boolean = false;
  @State showNavBar: boolean = true;
  @State currentAid: number = 0;

  @State isRefreshing: boolean = false;
  @State refreshState: RefreshStatus = RefreshStatus.Inactive;
  @StorageLink('custom_reading_font') customReadingFont: string = '';
  @StorageLink('appColorMode') appColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  @StorageLink('isActualDarkMode') isActualDarkMode: boolean = false;
  @StorageLink('autoSimp') autoSimp: boolean = true;

  
  @State showCommentInput: boolean = false;
  @State commentText: string = '';
  
  @State showCommentSection: boolean = true;

  
  @State replyTargetTid: number = 0;
  @State replyTargetRid: number = 0;
  @State replyTargetUid: number = 0;
  @State replyTargetNickname: string = '';
  @State replyPlaceholder: string = '说点什么...';

  
  @State expandedReplies: Map<number, CommentReply[]> = new Map();
  @State loadingRepliesTid: number = 0;
  
  @State commentRefreshKey: number = 0;

  
  private pendingScrollIndex: number = -1;
  private hasRestoredPosition: boolean = false;
  private lastFirstVisibleIndex: number = 0; 

  private scroller: Scroller = new Scroller();
  @State hasScrolledToComments: boolean = false;

  
  @State currentSid: number = 0;
  @State collectionTitle: string = '';
  @State collectionList: SearchArticle[] = [];

  
  @State failedImages: Map<string, number> = new Map();

  aboutToAppear() {
    let params = router.getParams() as Record<string, string | number>;
    let aid = params?.['aid'] as number | undefined;
    let tag = params?.['tag'] as string | undefined;
    let sid = params?.['sid'] as number | undefined;
    let colTitle = params?.['collectionTitle'] as string | undefined;

    if (tag) {
      let baseTag = tag.replace('阅读', '');
      let autoSimp = AppStorage.get<boolean>('autoSimp') ?? true;
      let finalTitle = baseTag + '阅读';
      this.viewModel.navTitle = autoSimp ? T2SEngine.convert(finalTitle) : finalTitle;
    }

    
    if (sid !== undefined && sid > 0) {
      this.currentSid = sid;
      if (colTitle) this.collectionTitle = colTitle;
      this.loadCollectionList(sid);
    }

    if (aid !== undefined) {
      this.currentAid = aid;
      let safeAid = aid;

      
      let savedIndex = PreferenceManager.getNumberSync(`reading_pos_${safeAid}`, -1);
      if (savedIndex > 0) {
        this.pendingScrollIndex = savedIndex;
        FileLog.i('ArticleDetail', `同步读取保存位置: index=${savedIndex}`);
      }

      
      this.viewModel.loadDetail(safeAid).then(() => {
        this.tryRestoreScrollPosition();
      });
      this.viewModel.loadInteraction(safeAid);
      this.viewModel.loadComments(safeAid);
      
      this.viewModel.loadLikedComments();
    } else {
      this.viewModel.message = '缺少文章 ID，无法加载内容';
      this.viewModel.isLoading = false;
    }
  }

  aboutToDisappear() {
    if (this.currentAid > 0 && this.viewModel.contentData.totalCount() > 0) {
      
      if (this.lastFirstVisibleIndex > 2) {
        PreferenceManager.putNumber(`reading_pos_${this.currentAid}`, this.lastFirstVisibleIndex);
        FileLog.i('ArticleDetail', `保存阅读位置: index=${this.lastFirstVisibleIndex}`);
      }
    }
  }

  
  onBackPress(): boolean {
    if (this.isPreviewOpen) {
      this.isPreviewOpen = false;
      return true; 
    }
    return false; 
  }

  private tryRestoreScrollPosition() {
    if (this.hasRestoredPosition) return;
    if (this.viewModel.contentData.totalCount() === 0) return;
    if (this.pendingScrollIndex <= 0) return;

    this.hasRestoredPosition = true;
    
    
    FileLog.i('ArticleDetail', `阅读位置已通过 initialIndex=${this.pendingScrollIndex} 恢复，跳过兜底校正`);
  }

  private navigateToProfile(uid: number) {
    if (uid <= 0) return;
    let selfUid = 0;
    let key = AppStorage.get<string>('security_key') || '';
    let parts = key.split(':');
    if (parts.length >= 2) selfUid = parseInt(parts[1]);
    router.pushUrl({
      url: 'pages/UserProfileView',
      params: { uid: uid, isSelf: uid === selfUid }
    }).catch(() => {});
  }

  private scrollToComments() {
    try {
      let totalContent = this.viewModel.contentData.totalCount();
      let commentIndex = totalContent + 4;
      this.scroller.scrollToIndex(commentIndex, false);
    } catch (e) {}
  }

  
  private async loadCollectionList(sid: number) {
    try {
      let res = await NovelRepository.getSeriesDetail(sid);
      
      let articles: SearchArticle[] = [];
      for (let a of res.articles) {
        let sa = new SearchArticle();
        sa.aid = a.aid;
        sa.title = a.title;
        sa.cover = a.cover;
        sa.hits = a.hits;
        articles.push(sa);
      }
      this.collectionList = articles;
      FileLog.i('ArticleDetail', `合集列表加载完成: sid=${sid}, name=${res.name}, 共 ${articles.length} 篇`);
    } catch (e) {
      FileLog.e('ArticleDetail', `合集列表加载失败: ${(e as Error).message}`);
    }
  }

  private openReplyInput(tid: number, rid: number, uid: number, nickname: string) {
    
    if (this.showCommentInput && this.replyTargetTid === tid && this.replyTargetRid === rid && this.replyTargetUid === uid) {
      this.showCommentInput = false;
      
      
      return;
    }
    this.replyTargetTid = tid;
    this.replyTargetRid = rid;
    this.replyTargetUid = uid;
    this.replyTargetNickname = nickname;
    if (nickname && nickname !== '') {
      this.replyPlaceholder = `回复 ${nickname}...`;
    } else {
      this.replyPlaceholder = '说点什么...';
    }
    this.commentText = '';
    this.showCommentInput = true;
  }

  
  private isVideoEmbed(url: string): boolean {
    let lower = url.toLowerCase();
    return lower.indexOf('bilibili.com') >= 0
      || lower.indexOf('player.bilibili.com') >= 0
      || lower.indexOf('youtube.com') >= 0
      || lower.indexOf('youtu.be') >= 0
      || lower.indexOf('nicovideo.jp') >= 0
      || lower.indexOf('embed') >= 0;
  }

  
  private extractLeadingNumber(str: string): string {
    let numStr = '';
    for (let i = 0; i < str.length; i++) {
      let c = str.charAt(i);
      if (c >= '0' && c <= '9') {
        numStr += c;
      } else {
        break;
      }
    }
    return numStr;
  }

  
  private tryNavigateInternalLink(url: string): boolean {
    
    let articlePatterns: string[] = [
      'lightnovel.fun/cn/detail/', 'lightnovel.us/cn/detail/',
      'lightnovel.fun/detail/', 'lightnovel.us/detail/',
      'lightnovel.fun/book/'
    ];
    for (let pattern of articlePatterns) {
      let idx = url.indexOf(pattern);
      if (idx >= 0) {
        let numStr = this.extractLeadingNumber(url.substring(idx + pattern.length));
        if (numStr.length > 0) {
          let targetAid = parseInt(numStr);
          if (targetAid > 0) {
            router.pushUrl({
              url: 'pages/ArticleDetail',
              params: { aid: targetAid }
            }).catch(() => {});
            return true;
          }
        }
      }
    }

    
    let seriesPatterns: string[] = [
      'lightnovel.fun/cn/series/', 'lightnovel.us/cn/series/',
      'lightnovel.fun/series/', 'lightnovel.us/series/'
    ];
    for (let pattern of seriesPatterns) {
      let idx = url.indexOf(pattern);
      if (idx >= 0) {
        let numStr = this.extractLeadingNumber(url.substring(idx + pattern.length));
        if (numStr.length > 0) {
          let targetSid = parseInt(numStr);
          if (targetSid > 0) {
            router.pushUrl({
              url: 'pages/CollectionDetailView',
              params: { sid: targetSid, currentAid: this.currentAid }
            }).catch(() => {});
            return true;
          }
        }
      }
    }

    return false;
  }

  
  private handleUrlClick(url: string) {
    if (this.tryNavigateInternalLink(url)) return;
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      openUrl(url, ctx);
    } catch (e) {}
  }

  private async loadAllReplies(comment: CommentItem) {
    if (this.loadingRepliesTid > 0) return;
    this.loadingRepliesTid = comment.tid;
    FileLog.i('ArticleDetail', `loadAllReplies: 开始加载 tid=${comment.tid}, aid=${this.currentAid}, 预期回复数=${comment.replies}`);
    try {
      
      let replies = await NovelRepository.getReplies(comment.tid, 1, 50);
      FileLog.i('ArticleDetail', `loadAllReplies: getReplies 返回 ${replies.length} 条回复`);

      
      let allReplies: CommentReply[] = replies.length > 0 ? replies : comment.reply_list;
      FileLog.i('ArticleDetail', `loadAllReplies: 最终使用 ${allReplies.length} 条回复`);

      if (allReplies.length > 0) {
        this.expandedReplies.set(comment.tid, allReplies);
        let newMap = new Map<number, CommentReply[]>();
        this.expandedReplies.forEach((v: CommentReply[], k: number) => {
          newMap.set(k, v);
        });
        this.expandedReplies = newMap;
        FileLog.i('ArticleDetail', `loadAllReplies: 成功设置 ${allReplies.length} 条回复到 expandedReplies`);
      } else {
        FileLog.w('ArticleDetail', `loadAllReplies: 没有获取到任何回复`);
      }
    } catch (e) {
      FileLog.e('ArticleDetail', `loadAllReplies 失败: ${(e as Error).message}`);
    } finally {
      this.loadingRepliesTid = 0;
    }
  }

  private getRepliesForComment(comment: CommentItem): CommentReply[] {
    let expanded = this.expandedReplies.get(comment.tid);
    if (expanded && expanded.length > 0) {
      return expanded;
    }
    return comment.reply_list;
  }

  
  private openImagePreview(url: string) {
    FileLog.i('ArticleDetail', `openImagePreview: url=${url.substring(0, 80)}`);
    this.previewImageUrl = url;
    this.isPreviewOpen = true;
  }

  
  @Builder RichTextContent(rawContent: string, fontSize: number, lineHeight: number) {
    if (rawContent.indexOf('<img') >= 0) {
      Column({ space: 6 }) {
        ForEach(NativeArticleParser.parseCommentContent(rawContent), (item: ContentItem, idx: number) => {
          if (item.type === 'image' && item.url) {
            Image(item.url)
              .width('100%').borderRadius(8).objectFit(ImageFit.Contain)
              .backgroundColor(Constants.CARD_BG_COLOR)
              .gesture(TapGesture().onAction(() => {
                if (item.url) {
                  this.openImagePreview(item.url);
                }
              }))
          } else if (item.spans.length > 0 && item.spans.some((s: RichSpan) => s.bold || s.italic || s.underline || s.lineThrough || s.color !== '' || s.fontSize > 0 || s.linkUrl !== '')) {
            Text() {
              ForEach(item.spans, (span: RichSpan) => {
                Span(this.autoSimp ? T2SEngine.convert(span.text) : span.text)
                  .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
                  .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
                  .decoration({
                    type: span.underline ? TextDecorationType.Underline :
                      (span.lineThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
                  })
                  .fontColor(span.linkUrl !== '' ? Constants.THEME_COLOR :
                    (span.color !== '' ? NativeArticleParser.adaptColorForDarkMode(span.color, this.isActualDarkMode) : Constants.TEXT_PRIMARY))
                  .fontSize(span.fontSize > 0 ? span.fontSize : fontSize)
                  .onClick(() => {
                    if (span.linkUrl !== '') {
                      this.handleUrlClick(span.linkUrl);
                    }
                  })
              }, (span: RichSpan, si: number) => `csi_${idx}_${si}_${span.text.length}`)
            }
            .lineHeight(lineHeight).width('100%')
          } else {
            Text(this.autoSimp ? T2SEngine.convert(item.value) : item.value)
              .fontSize(fontSize).fontColor(Constants.TEXT_PRIMARY).lineHeight(lineHeight)
              .width('100%')
          }
        }, (item: ContentItem, idx: number) => `ci_${idx}_${item.type}`)
      }.width('100%')
    } else if (rawContent.indexOf('[') >= 0 || rawContent.indexOf('http://') >= 0 || rawContent.indexOf('https://') >= 0) {
      Text() {
        ForEach(NativeArticleParser.parseBBCodeWithLinks(this.autoSimp ? T2SEngine.convert(rawContent.replace(/<br\s*\/?>/gi, '\n')) : rawContent.replace(/<br\s*\/?>/gi, '\n')), (span: RichSpan) => {
          Span(span.text)
            .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
            .decoration({
              type: span.underline ? TextDecorationType.Underline :
                (span.lineThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
            })
            .fontColor(span.linkUrl !== '' ? Constants.THEME_COLOR :
              (span.color !== '' ? NativeArticleParser.adaptColorForDarkMode(span.color, this.isActualDarkMode) : Constants.TEXT_PRIMARY))
            .fontSize(span.fontSize > 0 ? span.fontSize : fontSize)
            .onClick(() => {
              if (span.linkUrl !== '') {
                this.handleUrlClick(span.linkUrl);
              }
            })
        }, (span: RichSpan, si: number) => `cs_${si}_${span.text.length}`)
      }
      .lineHeight(lineHeight).width('100%')
    } else {
      Text(this.autoSimp ? T2SEngine.convert(rawContent.replace(/<br\s*\/?>/gi, '\n')) : rawContent.replace(/<br\s*\/?>/gi, '\n'))
        .fontSize(fontSize).fontColor(Constants.TEXT_PRIMARY).lineHeight(lineHeight)
        .width('100%')
    }
  }

  
  @Builder ReplyItemBuilder(reply: CommentReply) {
    Column() {
      Row() {
        Image(reply.user_info.avatar || '')
          .width(20).height(20).borderRadius(10)
          .backgroundColor(Constants.CARD_BG_COLOR)
          .margin({ right: 6 })
          .onClick(() => this.navigateToProfile(reply.user_info.uid))

        Text(reply.user_info.nickname)
          .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Constants.THEME_COLOR)
          .onClick(() => this.navigateToProfile(reply.user_info.uid))

        if (reply.user_info.uid === this.getSelfUid() && this.getSelfUid() > 0) {
          Text('我')
            .fontSize(9).fontColor(Color.White).fontWeight(FontWeight.Bold)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius(3).backgroundColor(Constants.THEME_COLOR)
            .margin({ left: 4 })
        }

        if (reply.user_info.level && reply.user_info.level.name && reply.user_info.level.name !== '' && reply.user_info.level.name !== 'undefined') {
          Text(reply.user_info.level.name)
            .fontSize(9).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius(3).backgroundColor(Constants.THEME_TINT_BG_STRONG)
            .margin({ left: 4 })
        }

        if (reply.r_rid > 0 && reply.r_user_info) {
          Text(' 回复 ').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
          Text(reply.r_user_info.nickname)
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Constants.THEME_COLOR)
            .onClick(() => {
              if (reply.r_user_info) {
                this.navigateToProfile(reply.r_user_info.uid);
              }
            })
        }
      }.width('100%').alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Start)

      Column() {
        this.RichTextContent(reply.content, 13, 20)
      }.margin({ top: 4 })

      Row() {
        Text(reply.time).fontSize(10).fontColor(Constants.TEXT_SECONDARY)
      }
      .width('100%').margin({ top: 4 })
    }
    .width('100%').padding({ top: 6, bottom: 6 })
    .onClick(() => {
      this.openReplyInput(reply.tid, reply.rid, reply.user_info.uid, reply.user_info.nickname);
    })
  }

  private getSelfUid(): number {
    let key = AppStorage.get<string>('security_key') || '';
    let parts = key.split(':');
    if (parts.length >= 2) return parseInt(parts[1]);
    return 0;
  }

  @Builder CommentItemBuilder(comment: CommentItem) {
    Column() {
      Row() {
        Image(comment.user_info.avatar || '')
          .width(32).height(32).borderRadius(16)
          .backgroundColor(Constants.CARD_BG_COLOR)
          .margin({ right: 10 })
          .onClick(() => this.navigateToProfile(comment.user_info.uid))

        Column() {
          Row() {
            Text(comment.user_info.nickname)
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => this.navigateToProfile(comment.user_info.uid))
            if (comment.user_info.uid === this.getSelfUid() && this.getSelfUid() > 0) {
              Text('我')
                .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .borderRadius(4).backgroundColor(Constants.THEME_COLOR)
                .margin({ left: 6 })
            }
            if (comment.user_info.level && comment.user_info.level.name && comment.user_info.level.name !== '' && comment.user_info.level.name !== 'undefined') {
              Text(comment.user_info.level.name)
                .fontSize(10).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .borderRadius(4).backgroundColor(Constants.THEME_TINT_BG_STRONG)
                .margin({ left: 4 })
            }
          }
          Text(comment.time)
            .fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1)

        
        Row() {
          SymbolGlyph(this.viewModel.likedCommentTids.indexOf(comment.tid) >= 0
            ? $r('sys.symbol.hand_thumbsup_fill') : $r('sys.symbol.hand_thumbsup'))
            .fontSize(14)
            .fontColor([this.viewModel.likedCommentTids.indexOf(comment.tid) >= 0 ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY])
          Text(`${comment.likes}`)
            .fontSize(12)
            .fontColor(this.viewModel.likedCommentTids.indexOf(comment.tid) >= 0 ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
            .margin({ left: 4 })
        }
        .margin({ left: 4 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => {
          this.viewModel.doCommentLike(comment.tid);
        })
      }.width('100%')

      Column() {
        this.RichTextContent(comment.content, 15, 24)
      }.margin({ top: 8 })

      if (this.getRepliesForComment(comment).length > 0) {
        Column() {
          ForEach(this.getRepliesForComment(comment), (reply: CommentReply) => {
            this.ReplyItemBuilder(reply)
          }, (reply: CommentReply) => `reply_${reply.tid}_${reply.rid}`)

          if (comment.replies > this.getRepliesForComment(comment).length) {
            Row() {
              if (this.loadingRepliesTid === comment.tid) {
                LoadingProgress().width(14).height(14).color(Constants.THEME_COLOR).margin({ right: 6 })
                Text('加载中...').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
              } else {
                Text(`查看全部 ${comment.replies} 条回复`)
                  .fontSize(12).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(10).fontColor([Constants.THEME_COLOR]).margin({ left: 2 })
              }
            }
            .padding({ top: 6, bottom: 2 })
            .onClick(() => {
              this.loadAllReplies(comment);
            })
          }
        }
        .width('100%')
        .backgroundColor(Constants.THEME_TINT_BG)
        .borderRadius(8)
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .margin({ top: 8 })
      } else if (comment.replies > 0) {
        Row() {
          if (this.loadingRepliesTid === comment.tid) {
            LoadingProgress().width(14).height(14).color(Constants.THEME_COLOR).margin({ right: 6 })
            Text('加载中...').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
          } else {
            Text(`查看全部 ${comment.replies} 条回复`)
              .fontSize(12).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(10).fontColor([Constants.THEME_COLOR]).margin({ left: 2 })
          }
        }
        .margin({ top: 8 })
        .padding({ left: 12, top: 6, bottom: 6, right: 12 })
        .backgroundColor(Constants.THEME_TINT_BG)
        .borderRadius(8)
        .onClick(() => {
          this.loadAllReplies(comment);
        })
      }

      Divider().color(Constants.DIVIDER_COLOR).margin({ top: 12 })
    }
    .width('100%')
    .padding({ top: 12, bottom: 0 })
    .onClick(() => {
      this.openReplyInput(comment.tid, 0, comment.user_info.uid, comment.user_info.nickname);
    })
  }

  @Builder CommentInputBuilder() {
    Column() {
      Row() {
        Row().width(40).height(4).borderRadius(2).backgroundColor(Constants.DIVIDER_COLOR)
      }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 12 })

      Text(this.replyTargetTid > 0 ? `回复 ${this.replyTargetNickname}` : '写评论')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
        .margin({ bottom: 12 })

      TextArea({ placeholder: this.replyPlaceholder, text: this.commentText })
        .onChange((value: string) => { this.commentText = value; })
        .height(120)
        .fontSize(15)
        .borderRadius(12)
        .backgroundColor(Constants.CARD_BG_COLOR)
        .padding(12)
        .margin({ left: 16, right: 16 })

      Row() {
        Text(`${this.commentText.length}/500`)
          .fontSize(12).fontColor(Constants.TEXT_SECONDARY)
        Blank()
        Button('发送')
          .fontSize(15).fontWeight(FontWeight.Medium)
          .height(36).borderRadius(18)
          .backgroundColor(this.commentText.trim().length > 0 ? Constants.THEME_COLOR : Constants.CARD_BG_COLOR)
          .fontColor(this.commentText.trim().length > 0 ? Color.White : Constants.TEXT_SECONDARY)
          .enabled(this.commentText.trim().length > 0 && !this.viewModel.isPostingComment)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(async () => {
            let success = false;
            let repliedTid = this.replyTargetTid; 
            if (this.replyTargetTid > 0) {
              success = await NovelRepository.postReply(
                this.currentAid,
                this.replyTargetTid,
                this.commentText.trim(),
                this.replyTargetRid,
                this.replyTargetUid
              );
              if (success) {
                promptAction.openToast({ message: '回复成功' });
              } else {
                promptAction.openToast({ message: '回复失败' });
              }
            } else {
              success = await this.viewModel.doPostComment(this.currentAid, this.commentText.trim());
            }
            if (success) {
              this.commentText = '';
              this.showCommentInput = false;
              this.expandedReplies = new Map<number, CommentReply[]>();
              this.replyTargetTid = 0;
              this.replyTargetRid = 0;
              this.replyTargetUid = 0;
              this.replyTargetNickname = '';
              this.replyPlaceholder = '说点什么...';
              
              await this.viewModel.loadComments(this.currentAid);
              
              this.commentRefreshKey++;
              if (repliedTid > 0) {
                
                let targetComment: CommentItem | undefined = undefined;
                for (let c of this.viewModel.comments) {
                  if (c.tid === repliedTid) { targetComment = c; break; }
                }
                if (!targetComment) {
                  for (let c of this.viewModel.hotComments) {
                    if (c.tid === repliedTid) { targetComment = c; break; }
                  }
                }
                if (targetComment) {
                  this.loadAllReplies(targetComment);
                }
              }
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    }
    .width('100%')
    .backgroundColor(Constants.BG_COLOR)
    .borderRadius({ topLeft: 16, topRight: 16 })
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

          Text(this.viewModel.navTitle).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
            .layoutWeight(1).textAlign(TextAlign.Center).padding({ right: 60 })
        }
        .width('100%')
        .height(this.showNavBar ? 64 : 0)
        .opacity(this.showNavBar ? 1 : 0)
        .backgroundColor($r('app.color.acrylic_tint')).backgroundBlurStyle(BlurStyle.Thin)
        .clip(true)
        .animation({ duration: 300, curve: curves.springMotion() })

        if (this.viewModel.isLoading && !this.isRefreshing) {
          LoadingProgress().width(48).height(48).margin({ top: 120 }).color(Constants.THEME_COLOR)
        } else if (this.viewModel.isError && this.viewModel.contentData.totalCount() === 0) {
          Column() {
            Text(this.viewModel.message).fontSize(16).margin({ bottom: 24 }).fontColor(Color.Red)
            Button('重新加载').width(140).height(40).borderRadius(20)
              .backgroundColor(Constants.THEME_COLOR)
              .onClick(() => this.viewModel.loadDetail(this.currentAid))
          }.margin({ top: 140 }).alignItems(HorizontalAlign.Center)
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ space: 24, scroller: this.scroller, initialIndex: this.pendingScrollIndex > 0 ? this.pendingScrollIndex : 0 }) {

              ListItem() {
                Row() {
                  if (this.viewModel.isUpdating || this.isRefreshing || this.refreshState === RefreshStatus.Refresh) {
                    LoadingProgress().width(12).height(12).color(Constants.THEME_COLOR).margin({right: 6})
                    Text("正在同步进度...").fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                  } else if (this.refreshState === RefreshStatus.OverDrag) {
                    Text("松手可刷新").fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                  } else if (this.viewModel.lastUpdateTime) {
                    Text(`同步于 ${this.viewModel.lastUpdateTime}`).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
                  }
                }.width('100%').constraintSize({ maxWidth: 840 }).justifyContent(FlexAlign.Center).padding({ top: 16, bottom: 8 })
              }

              ListItem() {
                Text(this.viewModel.articleTitle)
                  .fontSize(28).fontWeight(FontWeight.Bolder).fontColor(Constants.TEXT_PRIMARY)
                  .fontFamily(FontManager.getReadingFontFamily())
                  .width('100%').constraintSize({ maxWidth: 840 }).lineHeight(40).padding({ top: 0, bottom: 8 })
              }

              
              if (this.viewModel.isInteractionLoaded && this.viewModel.interaction.author.uid > 0) {
                ListItem() {
                  Row() {
                    Image(this.viewModel.interaction.author.avatar || '')
                      .width(40).height(40).borderRadius(20)
                      .backgroundColor(Constants.CARD_BG_COLOR)
                      .margin({ right: 12 })
                      .onClick(() => this.navigateToProfile(this.viewModel.interaction.author.uid))

                    Column() {
                      Row() {
                        Text(this.viewModel.interaction.author.nickname)
                          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                          .onClick(() => this.navigateToProfile(this.viewModel.interaction.author.uid))
                        
                        if (this.viewModel.interaction.author.level && this.viewModel.interaction.author.level.name &&
                          this.viewModel.interaction.author.level.name !== '' && this.viewModel.interaction.author.level.name !== 'undefined') {
                          Text(this.viewModel.interaction.author.level.name)
                            .fontSize(11).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .borderRadius(4).backgroundColor(Constants.THEME_TINT_BG_STRONG)
                            .margin({ left: 6 })
                        }
                      }
                      if (this.viewModel.interaction.author.sign) {
                        Text(this.viewModel.interaction.author.sign)
                          .fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                          .margin({ top: 2 })
                      }
                    }
                    .alignItems(HorizontalAlign.Start).layoutWeight(1)

                    Button(this.viewModel.interaction.already_follow === 1 ? '已关注' : '+ 关注')
                      .fontSize(14).fontWeight(FontWeight.Medium)
                      .height(32).borderRadius(16)
                      .backgroundColor(this.viewModel.interaction.already_follow === 1 ? Constants.CARD_BG_COLOR : Constants.THEME_COLOR)
                      .fontColor(this.viewModel.interaction.already_follow === 1 ? Constants.TEXT_SECONDARY : Color.White)
                      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                      .onClick(() => {
                        this.viewModel.doFollow();
                      })
                  }
                  .width('100%').constraintSize({ maxWidth: 840 })
                  .padding({ top: 16, bottom: 16, left: 16, right: 16 })
                  .backgroundColor(Constants.CARD_BG_COLOR)
                  .borderRadius(12)
                }
              }

              
              if (this.viewModel.isInteractionLoaded) {
                ListItem() {
                  Row() {
                    Text(`${this.viewModel.interaction.hits} 阅读`)
                      .fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                    Text('·').fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 8, right: 8 })
                    Text(`${this.viewModel.interaction.likes} 点赞`)
                      .fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                    Text('·').fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 8, right: 8 })
                    Text(`${this.viewModel.interaction.favorites} 收藏`)
                      .fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                    if (this.viewModel.interaction.time) {
                      Text('·').fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ left: 8, right: 8 })
                      Text(this.viewModel.interaction.time)
                        .fontSize(13).fontColor(Constants.TEXT_SECONDARY)
                    }
                  }
                  .width('100%').constraintSize({ maxWidth: 840 })
                  .justifyContent(FlexAlign.Center)
                  .padding({ top: 12, bottom: 12 })
                }
              }

              
              
              LazyForEach(this.viewModel.contentData, (item: ContentItem) => {
                ListItem() {
                  Column() {
                    if (item.type === 'image') {
                      if (item.url) {
                        if (this.failedImages.has(item.url)) {
                          
                          Column() {
                            SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
                              .fontSize(28).fontColor([Constants.TEXT_SECONDARY])
                            Text('图片加载失败').fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ top: 8 })
                            Button('点击重试')
                              .fontSize(13).fontWeight(FontWeight.Medium)
                              .height(32).borderRadius(16)
                              .backgroundColor(Constants.THEME_COLOR).fontColor(Color.White)
                              .margin({ top: 10 })
                              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                              .onClick(() => {
                                
                                let newMap = new Map<string, number>();
                                this.failedImages.forEach((v: number, k: string) => {
                                  if (k !== item.url) newMap.set(k, v);
                                });
                                this.failedImages = newMap;
                              })
                          }
                          .width('100%').height(160)
                          .backgroundColor(Constants.CARD_BG_COLOR)
                          .borderRadius(12)
                          .justifyContent(FlexAlign.Center)
                        } else {
                          
                          Image(item.url)
                            .width('100%')
                            .borderRadius(12)
                            .backgroundColor(Constants.CARD_BG_COLOR)
                            .objectFit(ImageFit.Contain)
                            .constraintSize({ minHeight: 80 })
                            .onComplete(() => {
                              ImageCacheManager.preCacheImage(item.url || '');
                            })
                            .onError(() => {
                              
                              let newMap = new Map<string, number>();
                              this.failedImages.forEach((v: number, k: string) => {
                                newMap.set(k, v);
                              });
                              newMap.set(item.url || '', (this.failedImages.get(item.url || '') ?? 0) + 1);
                              this.failedImages = newMap;
                            })
                            .gesture(TapGesture({ count: 1 }).onAction(() => {
                              FileLog.i('ArticleDetail', `图片 TapGesture: url=${(item.url || '').substring(0, 80)}`);
                              this.openImagePreview(item.url || '');
                            }))
                        }
                      } else {
                        Row() { Text(`[图片链接丢失]`).fontSize(14).fontColor(Constants.TEXT_SECONDARY) }
                        .width('100%').height(160).backgroundColor(Constants.CARD_BG_COLOR)
                        .borderRadius(12).justifyContent(FlexAlign.Center)
                      }
                    } else if (item.type === 'link') {
                      if (item.url && this.isVideoEmbed(item.url)) {
                        
                        Column() {
                          Web({ src: item.url, controller: new webview.WebviewController() })
                            .width('100%').aspectRatio(16 / 9)
                            .javaScriptAccess(true)
                            .domStorageAccess(true)
                            .mediaPlayGestureAccess(true)
                        }
                        .width('100%').borderRadius(12).clip(true)
                      } else {
                        
                        Row() {
                          SymbolGlyph($r('sys.symbol.link'))
                            .fontSize(18).fontColor([Constants.THEME_COLOR]).margin({ right: 10 })
                          Column() {
                            Text(item.url && (item.url.indexOf('lightnovel.fun') >= 0 || item.url.indexOf('lightnovel.us') >= 0) ? '站内链接' : '嵌入内容')
                              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                            Text(item.value)
                              .fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                              .margin({ top: 2 })
                          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                          SymbolGlyph($r('sys.symbol.arrow_right'))
                            .fontSize(16).fontColor([Constants.THEME_COLOR])
                        }
                        .width('100%').padding(14)
                        .backgroundColor(Constants.THEME_TINT_BG)
                        .borderRadius(12).border({ width: 1, color: Constants.DIVIDER_COLOR })
                        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
                        .onClick(() => {
                          if (item.url) {
                            this.handleUrlClick(item.url);
                          }
                        })
                      }
                    } else {
                      if (item.spans.length > 0 && item.spans.some((s: RichSpan) => s.bold || s.italic || s.underline || s.lineThrough || s.color !== '' || s.fontSize > 0 || s.linkUrl !== '')) {
                        Text() {
                          ForEach(item.spans, (span: RichSpan) => {
                            Span(span.text)
                              .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
                              .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
                              .decoration({
                                type: span.underline ? TextDecorationType.Underline :
                                  (span.lineThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
                              })
                              .fontColor(span.linkUrl !== '' ? Constants.THEME_COLOR :
                                (span.color !== '' ? NativeArticleParser.adaptColorForDarkMode(span.color, this.isActualDarkMode) : Constants.TEXT_PRIMARY))
                              .fontSize(span.fontSize > 0 ? span.fontSize : 19)
                              .fontFamily(FontManager.getReadingFontFamily())
                              .onClick(() => {
                                if (span.linkUrl !== '') {
                                  this.handleUrlClick(span.linkUrl);
                                }
                              })
                          }, (span: RichSpan, si: number) => `${si}_${span.text.length}`)
                        }
                        .lineHeight(34).letterSpacing(0.6)
                        .width('100%').textAlign(TextAlign.JUSTIFY)
                        .copyOption(CopyOptions.LocalDevice)
                      } else {
                        Text(item.value).fontSize(19).lineHeight(34).letterSpacing(0.6)
                          .fontColor(Constants.TEXT_PRIMARY).width('100%').textAlign(TextAlign.JUSTIFY)
                          .fontFamily(FontManager.getReadingFontFamily())
                          .copyOption(CopyOptions.LocalDevice)
                      }
                    }
                  }.width('100%').constraintSize({ maxWidth: 840 })
                }
              }, (item: ContentItem, index: number) => `c${index}_${item.type}_${item.value.length}`)

              
              if (this.currentSid > 0 && this.collectionList.length > 0) {
                ListItem() {
                  Column() {
                    Row() {
                      Text('选集').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
                      Text(`(${this.collectionList.length})`).fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
                      Blank()
                      Row() {
                        Text('更多').fontSize(13).fontColor(Constants.THEME_COLOR)
                        SymbolGlyph($r('sys.symbol.chevron_right'))
                          .fontSize(12).fontColor([Constants.THEME_COLOR]).margin({ left: 2 })
                      }
                      .onClick(() => {
                        router.pushUrl({
                          url: 'pages/CollectionDetailView',
                          params: { sid: this.currentSid, title: this.collectionTitle, currentAid: this.currentAid }
                        }).catch(() => {});
                      })
                    }
                    .width('100%').padding({ bottom: 10 })

                    Scroll() {
                      Row({ space: 10 }) {
                        ForEach(this.collectionList, (ep: SearchArticle) => {
                          Column() {
                            Text(this.autoSimp ? T2SEngine.convert(ep.title) : ep.title)
                              .fontSize(13)
                              .fontColor(ep.aid === this.currentAid ? Color.White : Constants.TEXT_PRIMARY)
                              .fontWeight(ep.aid === this.currentAid ? FontWeight.Bold : FontWeight.Normal)
                              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                              .textAlign(TextAlign.Center)
                          }
                          .width(110).height(52)
                          .justifyContent(FlexAlign.Center)
                          .padding({ left: 10, right: 10 })
                          .backgroundColor(ep.aid === this.currentAid ? Constants.THEME_COLOR : Constants.CARD_BG_COLOR)
                          .borderRadius(10)
                          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                          .onClick(() => {
                            if (ep.aid !== this.currentAid) {
                              router.pushUrl({
                                url: 'pages/ArticleDetail',
                                params: { aid: ep.aid, sid: this.currentSid, collectionTitle: this.collectionTitle }
                              }).catch(() => {});
                            }
                          })
                        }, (ep: SearchArticle) => `ep_${ep.aid}`)
                      }
                    }
                    .scrollable(ScrollDirection.Horizontal)
                    .scrollBar(BarState.Off)
                    .width('100%')
                  }
                  .width('100%').constraintSize({ maxWidth: 840 })
                  .padding({ top: 16, bottom: 8 })
                }
              }

              
              ListItem() {
                Row() {
                  Text(`评论 (${this.viewModel.commentTotal})`)
                    .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
                  Blank()
                }
                .width('100%').constraintSize({ maxWidth: 840 })
                .padding({ top: 16, bottom: 8 })
              }

              if (this.viewModel.hotComments.length > 0) {
                ListItem() {
                  Column() {
                    Text('热门评论').fontSize(14).fontWeight(FontWeight.Medium)
                      .fontColor(Constants.THEME_COLOR).margin({ bottom: 8 })
                    ForEach(this.viewModel.hotComments, (comment: CommentItem) => {
                      this.CommentItemBuilder(comment)
                    }, (comment: CommentItem) => `hot_${comment.tid}_${this.commentRefreshKey}`)
                  }.width('100%').constraintSize({ maxWidth: 840 })
                }
              }

              ForEach(this.viewModel.comments, (comment: CommentItem) => {
                ListItem() {
                  Column() {
                    this.CommentItemBuilder(comment)
                  }.width('100%').constraintSize({ maxWidth: 840 })
                }
              }, (comment: CommentItem) => `c_${comment.tid}_${this.commentRefreshKey}`)

              if (this.viewModel.commentHasMore) {
                ListItem() {
                  Row() {
                    if (this.viewModel.isLoadingComments) {
                      LoadingProgress().width(16).height(16).color(Constants.THEME_COLOR).margin({ right: 8 })
                      Text('加载中...').fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                    } else {
                      Text('加载更多评论').fontSize(14).fontColor(Constants.THEME_COLOR)
                    }
                  }
                  .width('100%').constraintSize({ maxWidth: 840 })
                  .justifyContent(FlexAlign.Center)
                  .padding({ top: 16, bottom: 16 })
                  .onClick(() => {
                    if (!this.viewModel.isLoadingComments && this.viewModel.commentHasMore) {
                      this.viewModel.loadComments(this.currentAid, true);
                    }
                  })
                }
                
                .onAppear(() => {
                  if (!this.viewModel.isLoadingComments && this.viewModel.commentHasMore) {
                    this.viewModel.loadComments(this.currentAid, true);
                  }
                })
              }

              if (!this.viewModel.isLoadingComments && this.viewModel.comments.length === 0 && this.viewModel.hotComments.length === 0) {
                ListItem() {
                  Text('暂无评论，来发表第一条吧~')
                    .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                    .width('100%').textAlign(TextAlign.Center)
                    .padding({ top: 24, bottom: 24 })
                }
              }

              ListItem() { Row().width('100%').constraintSize({ maxWidth: 840 }).height(100) }
            }
            .padding({ left: 24, right: 24 })
            .width('100%').height('100%')
            .alignListItem(ListItemAlign.Center)
            .edgeEffect(EdgeEffect.Spring)
            .cachedCount(8)
            .onScrollIndex((firstIndex: number) => {
              
              this.lastFirstVisibleIndex = firstIndex;
              if (this.viewModel.contentData.totalCount() > 0) {
                let commentStartIndex = this.viewModel.contentData.totalCount() + 4;
                this.hasScrolledToComments = firstIndex >= commentStartIndex;
              }
            })
            .onDidScroll(() => {
              let yOffset = this.scroller.currentOffset().yOffset;
              if (yOffset > 45 && this.showNavBar) {
                animateTo({ duration: 300, curve: curves.springMotion() }, () => { this.showNavBar = false; });
              } else if (yOffset <= 45 && !this.showNavBar) {
                animateTo({ duration: 300, curve: curves.springMotion() }, () => { this.showNavBar = true; });
              }
            })
            .onReachEnd(() => {
              
              if (!this.viewModel.isLoadingComments && this.viewModel.commentHasMore) {
                this.viewModel.loadComments(this.currentAid, true);
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .onStateChange((state: RefreshStatus) => { this.refreshState = state; })
          .onRefreshing(async () => {
            await this.viewModel.loadDetail(this.currentAid, true);
            this.isRefreshing = false;
          })

          
          Row() {
            Column() {
              SymbolGlyph(this.viewModel.interaction.already_like === 1
                ? $r('sys.symbol.hand_thumbsup_fill')
                : $r('sys.symbol.hand_thumbsup'))
                .fontSize(22)
                .fontColor(this.viewModel.interaction.already_like === 1 ? [Constants.THEME_COLOR] : [Constants.TEXT_SECONDARY])
              Text(this.viewModel.isInteractionLoaded
                ? (this.viewModel.interaction.likes > 0 ? `${this.viewModel.interaction.likes}` : '点赞')
                : '点赞')
                .fontSize(10).fontColor(this.viewModel.interaction.already_like === 1 ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              if (this.viewModel.isInteractionLoaded) {
                this.viewModel.doLike(this.currentAid);
              }
            })

            Column() {
              SymbolGlyph(this.viewModel.interaction.already_fav === 1
                ? $r('sys.symbol.star_fill')
                : $r('sys.symbol.star'))
                .fontSize(22)
                .fontColor(this.viewModel.interaction.already_fav === 1 ? ['#FFD700'] : [Constants.TEXT_SECONDARY])
              Text(this.viewModel.isInteractionLoaded
                ? (this.viewModel.interaction.favorites > 0 ? `${this.viewModel.interaction.favorites}` : '收藏')
                : '收藏')
                .fontSize(10).fontColor(this.viewModel.interaction.already_fav === 1 ? '#FFD700' : Constants.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              if (this.viewModel.isInteractionLoaded) {
                this.viewModel.doFavorite(this.currentAid);
              }
            })

            Column() {
              Image($r('app.media.ic_comment'))
                .width(22).height(22)
                .fillColor(Constants.TEXT_SECONDARY)
              Text(this.viewModel.isInteractionLoaded
                ? (this.viewModel.interaction.comments > 0 ? `${this.viewModel.interaction.comments}` : '评论')
                : '评论')
                .fontSize(10).fontColor(Constants.TEXT_SECONDARY)
                .margin({ top: 2 })
            }
            .layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              
              if (this.showCommentInput) {
                this.showCommentInput = false;
                return;
              }
              if (this.hasScrolledToComments && this.viewModel.comments.length > 0) {
                this.replyTargetTid = 0;
                this.replyTargetRid = 0;
                this.replyTargetUid = 0;
                this.replyTargetNickname = '';
                this.replyPlaceholder = '说点什么...';
                this.showCommentInput = true;
              } else {
                this.scrollToComments();
              }
            })
          }
          .width('100%')
          .height(56)
          .backgroundColor($r('app.color.acrylic_tint'))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: { top: 0.5 }, color: Constants.DIVIDER_COLOR })
          .padding({ bottom: 0 })
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
              .backgroundColor(Color.White)
              .fontColor(Color.Black)
              .fontSize(16).fontWeight(FontWeight.Bold)
              .margin({ bottom: 48 }).width(160).height(44).borderRadius(22)
              .shadow({ radius: 16, color: 'rgba(0,0,0,0.3)', offsetY: 4 })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .onClick(() => {
                let ctx = getContext(this) as common.UIAbilityContext;
                this.viewModel.downloadAndSaveImage(this.previewImageUrl, ctx);
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
    .bindSheet(this.showCommentInput, this.CommentInputBuilder(), {
      height: SheetSize.FIT_CONTENT,
      backgroundColor: Constants.BG_COLOR,
      dragBar: false,
      onDisappear: () => {
        this.showCommentInput = false;
        
        this.replyTargetTid = 0;
        this.replyTargetRid = 0;
        this.replyTargetUid = 0;
        this.replyTargetNickname = '';
        this.replyPlaceholder = '说点什么...';
      }
    })
  }
}
