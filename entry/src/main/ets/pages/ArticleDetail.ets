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

class BlockedWordBucket {
  firstChar: string = '';
  words: string[] = [];
}

class BlockedWordMatcher {
  private buckets: BlockedWordBucket[] = [];
  count: number = 0;

  constructor(words: string[]) {
    this.count = words.length;
    for (let i = 0; i < words.length; i++) {
      let word = words[i];
      if (word.length === 0) continue;
      let firstChar = word.charAt(0);
      let bucket = this.getOrCreateBucket(firstChar);
      bucket.words.push(word);
    }
  }

  private getOrCreateBucket(firstChar: string): BlockedWordBucket {
    for (let i = 0; i < this.buckets.length; i++) {
      if (this.buckets[i].firstChar === firstChar) {
        return this.buckets[i];
      }
    }
    let bucket = new BlockedWordBucket();
    bucket.firstChar = firstChar;
    this.buckets.push(bucket);
    return bucket;
  }

  private getBucket(firstChar: string): BlockedWordBucket | null {
    for (let i = 0; i < this.buckets.length; i++) {
      if (this.buckets[i].firstChar === firstChar) {
        return this.buckets[i];
      }
    }
    return null;
  }

  contains(contentLower: string): boolean {
    if (contentLower.length === 0 || this.count === 0) return false;
    for (let i = 0; i < contentLower.length; i++) {
      let bucket = this.getBucket(contentLower.charAt(i));
      if (!bucket) continue;
      for (let j = 0; j < bucket.words.length; j++) {
        let word = bucket.words[j];
        if (this.matchesAt(contentLower, i, word)) {
          return true;
        }
      }
    }
    return false;
  }

  private matchesAt(contentLower: string, offset: number, word: string): boolean {
    if (offset + word.length > contentLower.length) return false;
    for (let i = 0; i < word.length; i++) {
      if (contentLower.charAt(offset + i) !== word.charAt(i)) return false;
    }
    return true;
  }
}

class RubyCharCell {
  text: string = '';
  width: number = 0;
  left: number = 0;
}

class RubyRenderAtom {
  key: number = 0;
  text: string = '';
  rubyText: string = '';
  fontSize: number = 0;
  bold: boolean = false;
  italic: boolean = false;
  underline: boolean = false;
  lineThrough: boolean = false;
  color: string = '';
  linkUrl: string = '';
}

@Entry
@Component
struct ArticleDetail {
  @State viewModel: DetailViewModel = new DetailViewModel();
  @State previewImageUrl: string = '';
  @State isPreviewOpen: boolean = false;
  @State showNavBar: boolean = true;
  @StorageLink('readingTopBarAlwaysShow') readingTopBarAlwaysShow: boolean = true;
  @StorageLink('topBarExtraHeight') topBarExtraHeight: number = 0;
  @State currentAid: number = 0;

  @State isRefreshing: boolean = false;
  @State refreshState: RefreshStatus = RefreshStatus.Inactive;
  @StorageLink('custom_reading_font') customReadingFont: string = '';
  @StorageLink('appColorMode') appColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  @StorageLink('isActualDarkMode') isActualDarkMode: boolean = false;
  @StorageLink('autoSimp') autoSimp: boolean = true;
  
  @StorageLink('debugMode') debugMode: boolean = false;

  
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
  
  private openedFromMessageTarget: boolean = false;

  private scroller: Scroller = new Scroller();
  @State hasScrolledToComments: boolean = false;
  
  private savedReadingIndex: number = -1;
  
  private hasJumpedViaCommentBtn: boolean = false;
  private mContext: common.UIAbilityContext | undefined = undefined;
  private pendingTargetTid: number = 0;
  private pendingTargetRid: number = 0;
  private pendingScrollToComment: boolean = false;
  private hasHandledMessageTarget: boolean = false;

  
  @State currentSid: number = 0;
  @State collectionTitle: string = '';
  @State collectionList: SearchArticle[] = [];

  
  @State failedImages: Map<string, number> = new Map();

  aboutToAppear() {
    this.mContext = getContext(this) as common.UIAbilityContext;
    let params = router.getParams() as Record<string, string | number>;
    let aid = params?.['aid'] as number | undefined;
    let tag = params?.['tag'] as string | undefined;
    let sid = params?.['sid'] as number | undefined;
    let colTitle = params?.['collectionTitle'] as string | undefined;
    let targetTid = params?.['targetTid'] as number | undefined;
    let targetRid = params?.['targetRid'] as number | undefined;
    let scrollToComment = params?.['scrollToComment'] as number | undefined;

    this.pendingTargetTid = targetTid ?? 0;
    this.pendingTargetRid = targetRid ?? 0;
    this.pendingScrollToComment = scrollToComment === 1 || this.pendingTargetTid > 0;
    this.openedFromMessageTarget = this.pendingScrollToComment;

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
        this.tryHandleMessageTarget();
      });
      this.viewModel.loadInteraction(safeAid);
      this.viewModel.loadComments(safeAid).then(() => {
        this.tryHandleMessageTarget();
      });
      
      this.viewModel.loadLikedComments();
    } else {
      this.viewModel.message = '缺少文章 ID，无法加载内容';
      this.viewModel.isLoading = false;
    }
  }

  aboutToDisappear() {
    if (this.currentAid > 0 && this.viewModel.contentData.totalCount() > 0) {
      
      let contentCount = this.viewModel.contentData.totalCount();
      let commentStartIndex = contentCount + 4;
      let isInCommentArea = this.lastFirstVisibleIndex >= commentStartIndex;
      if (this.openedFromMessageTarget && isInCommentArea) {
        FileLog.i('ArticleDetail', `消息评论跳转位置不覆盖阅读进度: index=${this.lastFirstVisibleIndex}`);
        return;
      }
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

  private findTargetComment(tid: number): CommentItem | null {
    if (tid <= 0) return null;
    for (let i = 0; i < this.viewModel.comments.length; i++) {
      let comment = this.viewModel.comments[i];
      if (comment.tid === tid) return comment;
    }
    for (let i = 0; i < this.viewModel.hotComments.length; i++) {
      let comment = this.viewModel.hotComments[i];
      if (comment.tid === tid) return comment;
    }
    return null;
  }

  private async loadUntilTargetComment(tid: number): Promise<CommentItem | null> {
    let target = this.findTargetComment(tid);
    let guard = 0;
    while (!target && this.viewModel.commentHasMore && guard < 8) {
      guard++;
      await this.viewModel.loadComments(this.currentAid, true);
      target = this.findTargetComment(tid);
    }
    return target;
  }

  private scrollToTargetComment(comment: CommentItem) {
    try {
      let baseIndex = this.viewModel.contentData.totalCount() + 4;
      for (let i = 0; i < this.viewModel.hotComments.length; i++) {
        if (this.viewModel.hotComments[i].tid === comment.tid) {
          this.scroller.scrollToIndex(baseIndex, false);
          return;
        }
      }
      if (this.viewModel.hotComments.length > 0) {
        baseIndex++;
      }
      for (let i = 0; i < this.viewModel.comments.length; i++) {
        if (this.viewModel.comments[i].tid === comment.tid) {
          this.scroller.scrollToIndex(baseIndex + i, false);
          return;
        }
      }
      this.scrollToComments();
    } catch (e) {
      this.scrollToComments();
    }
  }

  private async tryHandleMessageTarget() {
    if (this.hasHandledMessageTarget) return;
    if (!this.pendingScrollToComment && this.pendingTargetTid <= 0) return;
    if (this.currentAid <= 0) return;
    if (this.viewModel.isLoading || this.viewModel.isLoadingComments) return;

    this.hasHandledMessageTarget = true;
    this.scrollToComments();

    if (this.pendingTargetTid <= 0) return;
    let target = await this.loadUntilTargetComment(this.pendingTargetTid);
    if (target) {
      await this.loadAllReplies(target);
      this.commentRefreshKey++;
      this.scrollToTargetComment(target);
      FileLog.i('ArticleDetail', `消息深链定位完成: tid=${this.pendingTargetTid}, rid=${this.pendingTargetRid}`);
    } else {
      FileLog.w('ArticleDetail', `消息深链未找到目标评论: tid=${this.pendingTargetTid}, rid=${this.pendingTargetRid}`);
    }
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

      
      let rawBlockedWords: string = AppStorage.get<string>('blockedWords') ?? '';
      let isDebugMode: boolean = AppStorage.get<boolean>('debugMode') ?? false;
      let blockedWords: string[] = this.buildBlockedWords(rawBlockedWords);
      if (blockedWords.length > 0) {
        let blockedMatcher: BlockedWordMatcher = new BlockedWordMatcher(blockedWords);
        let selfUid: number = this.getSelfUid();
        let filteredReplies: CommentReply[] = [];
        let matchedCount: number = 0;
        for (let r = 0; r < allReplies.length; r++) {
          let reply = allReplies[r];
          let isSelfReply: boolean = this.isSelfReply(reply, selfUid);
          let blocked: boolean = !isSelfReply && blockedMatcher.contains(reply.content.toLowerCase());
          if (!blocked) {
            filteredReplies.push(reply);
          } else {
            matchedCount++;
            FileLog.i('ArticleDetail', `[BLOCKED] loadAllReplies 回复 rid=${reply.rid}, tid=${reply.tid}, uid=${reply.uid}, debugMode=${isDebugMode}`);
            if (isDebugMode) {
              reply.isBlocked = true;
              filteredReplies.push(reply); 
            }
            
          }
        }
        allReplies = filteredReplies;
        FileLog.i('ArticleDetail', `loadAllReplies: 屏蔽词过滤 words=${blockedWords.length}, matched=${matchedCount}, shown=${allReplies.length}, debugMode=${isDebugMode}, selfUid=${selfUid}`);
      }

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

  private buildBlockedWords(rawBlockedWords: string): string[] {
    let blockedWords: string[] = [];
    if (rawBlockedWords.trim().length === 0) return blockedWords;
    let parts: string[] = rawBlockedWords.split(',');
    for (let i = 0; i < parts.length; i++) {
      let word: string = parts[i].trim().toLowerCase();
      if (word.length > 0 && blockedWords.indexOf(word) < 0) {
        blockedWords.push(word);
      }
    }
    return blockedWords;
  }

  private isSelfReply(reply: CommentReply, selfUid: number): boolean {
    if (selfUid <= 0) return false;
    if (reply.uid === selfUid) return true;
    return reply.user_info.uid === selfUid;
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

  private splitChars(text: string): string[] {
    let chars: string[] = [];
    for (let i = 0; i < text.length; i++) {
      chars.push(text.charAt(i));
    }
    return chars;
  }

  private rubyBoxWidth(baseText: string, _rubyText: string, baseFontSize: number, _rubyFontSize: number,
    baseLetterSpacing: number, minWidth: number): number {
    let baseWidth = baseText.length * baseFontSize + Math.max(0, baseText.length - 1) * baseLetterSpacing;
    return Math.max(minWidth, baseWidth);
  }

  private createRubyAtom(span: RichSpan, text: string, rubyText: string, key: number): RubyRenderAtom {
    let atom = new RubyRenderAtom();
    atom.key = key;
    atom.text = text;
    atom.rubyText = rubyText;
    atom.fontSize = span.fontSize;
    atom.bold = span.bold;
    atom.italic = span.italic;
    atom.underline = span.underline;
    atom.lineThrough = span.lineThrough;
    atom.color = span.color;
    atom.linkUrl = span.linkUrl;
    return atom;
  }

  private buildRubyAtoms(spans: RichSpan[]): RubyRenderAtom[] {
    let atoms: RubyRenderAtom[] = [];
    let key = 0;
    for (let i = 0; i < spans.length; i++) {
      let span = spans[i];
      if (span.rubyText !== '') {
        atoms.push(this.createRubyAtom(span, span.text, span.rubyText, key));
        key++;
      } else {
        let chars = this.splitChars(span.text);
        for (let j = 0; j < chars.length; j++) {
          atoms.push(this.createRubyAtom(span, chars[j], '', key));
          key++;
        }
      }
    }
    return atoms;
  }

  private isCommentSafeRubyAtom(atom: RubyRenderAtom, fontSize: number): boolean {
    let baseFontSize = atom.fontSize > 0 ? atom.fontSize : fontSize;
    let width = this.rubyBoxWidth(atom.text, atom.rubyText, baseFontSize, 6, 0, 16);
    return atom.text.length <= 12 && atom.rubyText.length <= 20 && width <= 260;
  }

  private isArticleSafeRubyAtom(atom: RubyRenderAtom): boolean {
    let baseFontSize = atom.fontSize > 0 ? atom.fontSize : 19;
    let width = this.rubyBoxWidth(atom.text, atom.rubyText, baseFontSize, 8, 0.6, 20);
    return atom.text.length <= 12 && atom.rubyText.length <= 20 && width <= 320;
  }

  private rubyFontSizeForWidth(rubyText: string, boxWidth: number, preferredSize: number): number {
    if (rubyText.length <= 0) return preferredSize;
    let fittedSize = Math.floor(boxWidth / rubyText.length) + 1;
    if (fittedSize < 5) return 5;
    return Math.min(preferredSize, fittedSize);
  }

  private rubyCharLeft(index: number, count: number, boxWidth: number, charWidth: number): number {
    if (count <= 1) return Math.max(0, (boxWidth - charWidth) / 2);
    let step = (boxWidth - charWidth) / (count - 1);
    return Math.max(0, index * step);
  }

  private buildRubyCells(rubyText: string, boxWidth: number, rubyFontSize: number): RubyCharCell[] {
    let chars = this.splitChars(rubyText);
    let cells: RubyCharCell[] = [];
    let charWidth = rubyFontSize;
    for (let i = 0; i < chars.length; i++) {
      let cell = new RubyCharCell();
      cell.text = chars[i];
      cell.width = charWidth;
      cell.left = this.rubyCharLeft(i, chars.length, boxWidth, charWidth);
      cells.push(cell);
    }
    return cells;
  }

  private buildBaseCells(baseText: string, baseFontSize: number, baseLetterSpacing: number): RubyCharCell[] {
    let chars = this.splitChars(baseText);
    let cells: RubyCharCell[] = [];
    for (let i = 0; i < chars.length; i++) {
      let cell = new RubyCharCell();
      cell.text = chars[i];
      cell.width = baseFontSize;
      cell.left = i * (baseFontSize + baseLetterSpacing);
      cells.push(cell);
    }
    return cells;
  }

  @Builder RubyAnnotationRow(rubyText: string, boxWidth: number, rubyFontSize: number) {
    Stack() {
      ForEach(this.buildRubyCells(rubyText, boxWidth, rubyFontSize), (cell: RubyCharCell) => {
        Text(cell.text)
          .fontSize(rubyFontSize)
          .fontColor(Constants.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .lineHeight(rubyFontSize + 2)
          .height(rubyFontSize + 2)
          .width(cell.width)
          .maxLines(1)
          .position({ x: cell.left, y: 0 })
          .hitTestBehavior(HitTestMode.None)
      }, (cell: RubyCharCell, index: number) => `ruby_cell_${index}_${cell.text}`)
    }
    .width(boxWidth)
    .height(rubyFontSize + 2)
  }

  @Builder RubyBaseRow(atom: RubyRenderAtom, baseFontSize: number, baseLetterSpacing: number, boxWidth: number,
    lineHeight: number, useReadingFont: boolean) {
    Stack() {
      ForEach(this.buildBaseCells(atom.text, baseFontSize, baseLetterSpacing), (cell: RubyCharCell) => {
        Text(cell.text)
          .fontSize(baseFontSize)
          .fontWeight(atom.bold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(atom.italic ? FontStyle.Italic : FontStyle.Normal)
          .decoration({
            type: atom.underline ? TextDecorationType.Underline :
              (atom.lineThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
          })
          .fontColor(atom.linkUrl !== '' ? Constants.THEME_COLOR :
            (atom.color !== '' ? NativeArticleParser.adaptColorForDarkMode(atom.color, this.isActualDarkMode) : Constants.TEXT_PRIMARY))
          .fontFamily(useReadingFont ? FontManager.getReadingFontFamily() : '')
          .textAlign(TextAlign.Center)
          .lineHeight(lineHeight)
          .height(lineHeight)
          .width(cell.width)
          .maxLines(1)
          .position({ x: cell.left, y: 0 })
          .onClick(() => {
            if (atom.linkUrl !== '') {
              this.handleUrlClick(atom.linkUrl);
            }
          })
      }, (cell: RubyCharCell, index: number) => `ruby_base_${atom.key}_${index}_${cell.text}`)
    }
    .width(boxWidth)
    .height(lineHeight)
  }

  @Builder CommentRubySpan(atom: RubyRenderAtom, fontSize: number, lineHeight: number) {
    Column({ space: 0 }) {
      this.RubyAnnotationRow(atom.rubyText, this.rubyBoxWidth(atom.text, atom.rubyText,
        atom.fontSize > 0 ? atom.fontSize : fontSize, 6, 0, 16),
        this.rubyFontSizeForWidth(atom.rubyText, this.rubyBoxWidth(atom.text, atom.rubyText,
          atom.fontSize > 0 ? atom.fontSize : fontSize, 6, 0, 16), 6))
      this.RubyBaseRow(atom, atom.fontSize > 0 ? atom.fontSize : fontSize, 0,
        this.rubyBoxWidth(atom.text, atom.rubyText, atom.fontSize > 0 ? atom.fontSize : fontSize, 6, 0, 16),
        lineHeight, false)
    }
    .width(this.rubyBoxWidth(atom.text, atom.rubyText, atom.fontSize > 0 ? atom.fontSize : fontSize, 6, 0, 16))
    .constraintSize({ minWidth: this.rubyBoxWidth(atom.text, atom.rubyText, atom.fontSize > 0 ? atom.fontSize : fontSize, 6, 0, 16), maxWidth: this.rubyBoxWidth(atom.text, atom.rubyText, atom.fontSize > 0 ? atom.fontSize : fontSize, 6, 0, 16) })
    .height(lineHeight + 8)
  }

  @Builder CommentRubyPlainAtom(atom: RubyRenderAtom, fontSize: number, lineHeight: number) {
    Text(atom.text)
      .fontSize(atom.fontSize > 0 ? atom.fontSize : fontSize)
      .fontWeight(atom.bold ? FontWeight.Bold : FontWeight.Normal)
      .fontStyle(atom.italic ? FontStyle.Italic : FontStyle.Normal)
      .decoration({
        type: atom.underline ? TextDecorationType.Underline :
          (atom.lineThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
      })
      .fontColor(atom.linkUrl !== '' ? Constants.THEME_COLOR :
        (atom.color !== '' ? NativeArticleParser.adaptColorForDarkMode(atom.color, this.isActualDarkMode) : Constants.TEXT_PRIMARY))
      .lineHeight(lineHeight)
      .height(lineHeight + 8)
      .padding({ top: 8 })
      .copyOption(CopyOptions.LocalDevice)
      .onClick(() => {
        if (atom.linkUrl !== '') {
          this.handleUrlClick(atom.linkUrl);
        }
      })
  }

  
  @Builder CommentRubyFallbackText(span: RichSpan, fontSize: number, lineHeight: number) {
    Text(span.text)
      .fontSize(span.fontSize > 0 ? span.fontSize : fontSize)
      .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
      .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
      .decoration({
        type: span.underline ? TextDecorationType.Underline :
          (span.lineThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
      })
      .fontColor(span.linkUrl !== '' ? Constants.THEME_COLOR :
        (span.color !== '' ? NativeArticleParser.adaptColorForDarkMode(span.color, this.isActualDarkMode) : Constants.TEXT_PRIMARY))
      .lineHeight(lineHeight)
      .height(lineHeight + 8)
      .padding({ top: 8 })
      .copyOption(CopyOptions.LocalDevice)
      .onClick(() => {
        if (span.linkUrl !== '') {
          this.handleUrlClick(span.linkUrl);
        }
      })
  }

  @Builder ArticleRubySpan(atom: RubyRenderAtom) {
    Column({ space: 0 }) {
      this.RubyAnnotationRow(atom.rubyText, this.rubyBoxWidth(atom.text, atom.rubyText,
        atom.fontSize > 0 ? atom.fontSize : 19, 8, 0.6, 20),
        this.rubyFontSizeForWidth(atom.rubyText, this.rubyBoxWidth(atom.text, atom.rubyText,
          atom.fontSize > 0 ? atom.fontSize : 19, 8, 0.6, 20), 8))
      this.RubyBaseRow(atom, atom.fontSize > 0 ? atom.fontSize : 19, 0.6,
        this.rubyBoxWidth(atom.text, atom.rubyText, atom.fontSize > 0 ? atom.fontSize : 19, 8, 0.6, 20),
        28, true)
    }
    .width(this.rubyBoxWidth(atom.text, atom.rubyText, atom.fontSize > 0 ? atom.fontSize : 19, 8, 0.6, 20))
    .constraintSize({ minWidth: this.rubyBoxWidth(atom.text, atom.rubyText, atom.fontSize > 0 ? atom.fontSize : 19, 8, 0.6, 20), maxWidth: this.rubyBoxWidth(atom.text, atom.rubyText, atom.fontSize > 0 ? atom.fontSize : 19, 8, 0.6, 20) })
    .height(38)
  }

  @Builder ArticleRubyPlainAtom(atom: RubyRenderAtom) {
    Text(atom.text)
      .fontSize(atom.fontSize > 0 ? atom.fontSize : 19)
      .fontWeight(atom.bold ? FontWeight.Bold : FontWeight.Normal)
      .fontStyle(atom.italic ? FontStyle.Italic : FontStyle.Normal)
      .decoration({
        type: atom.underline ? TextDecorationType.Underline :
          (atom.lineThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
      })
      .fontColor(atom.linkUrl !== '' ? Constants.THEME_COLOR :
        (atom.color !== '' ? NativeArticleParser.adaptColorForDarkMode(atom.color, this.isActualDarkMode) : Constants.TEXT_PRIMARY))
      .fontFamily(FontManager.getReadingFontFamily())
      .letterSpacing(0.6)
      .lineHeight(28)
      .height(38)
      .padding({ top: 10 })
      .onClick(() => {
        if (atom.linkUrl !== '') {
          this.handleUrlClick(atom.linkUrl);
        }
      })
  }

  
  @Builder ArticleRubyFallbackText(span: RichSpan) {
    Text(span.text)
      .fontSize(span.fontSize > 0 ? span.fontSize : 19)
      .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
      .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
      .decoration({
        type: span.underline ? TextDecorationType.Underline :
          (span.lineThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
      })
      .fontColor(span.linkUrl !== '' ? Constants.THEME_COLOR :
        (span.color !== '' ? NativeArticleParser.adaptColorForDarkMode(span.color, this.isActualDarkMode) : Constants.TEXT_PRIMARY))
      .fontFamily(FontManager.getReadingFontFamily())
      .letterSpacing(0.6)
      .lineHeight(28)
      .height(38)
      .padding({ top: 10 })
      .onClick(() => {
        if (span.linkUrl !== '') {
          this.handleUrlClick(span.linkUrl);
        }
      })
  }

  
  
  @Builder RichTextContent(rawContent: string, fontSize: number, lineHeight: number, tid: number = 0) {
    if (rawContent.indexOf('<img') >= 0) {
      Column({ space: 6 }) {
        ForEach(this.viewModel.getOrParseCommentContent(rawContent, tid, this.autoSimp, this.isActualDarkMode), (item: ContentItem, idx: number) => {
          if (item.type === 'image' && item.url) {
            Image(item.url)
              .width('100%').borderRadius(8).objectFit(ImageFit.Contain)
              .backgroundColor(Constants.CARD_BG_COLOR)
              .gesture(TapGesture().onAction(() => {
                if (item.url) {
                  this.openImagePreview(item.url);
                }
              }))
          } else if (item.spans.length > 0 && item.spans.some((s: RichSpan) => s.rubyText !== '')) {
            
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.End }) {
              ForEach(this.buildRubyAtoms(item.spans), (atom: RubyRenderAtom) => {
                if (atom.rubyText !== '') {
                  if (this.isCommentSafeRubyAtom(atom, fontSize)) {
                    this.CommentRubySpan(atom, fontSize, lineHeight)
                  } else {
                    this.CommentRubyPlainAtom(atom, fontSize, lineHeight)
                  }
                } else {
                  this.CommentRubyPlainAtom(atom, fontSize, lineHeight)
                }
              }, (atom: RubyRenderAtom) => `crby_${idx}_${atom.key}_${atom.text}`)
            }.width('100%')
          } else if (item.spans.length > 0 && item.spans.some((s: RichSpan) => s.bold || s.italic || s.underline || s.lineThrough || s.color !== '' || s.fontSize > 0 || s.linkUrl !== '')) {
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
                  .fontSize(span.fontSize > 0 ? span.fontSize : fontSize)
                  .onClick(() => {
                    if (span.linkUrl !== '') {
                      this.handleUrlClick(span.linkUrl);
                    }
                  })
              }, (span: RichSpan, si: number) => `csi_${idx}_${si}_${span.text.length}`)
            }
            .lineHeight(lineHeight).width('100%').copyOption(CopyOptions.LocalDevice)
          } else {
            Text(item.value)
              .fontSize(fontSize).fontColor(Constants.TEXT_PRIMARY).lineHeight(lineHeight)
              .width('100%').copyOption(CopyOptions.LocalDevice)
          }
        }, (item: ContentItem, idx: number) => `ci_${idx}_${item.type}`)
      }.width('100%')
    } else if (rawContent.indexOf('[') >= 0 || rawContent.indexOf('http://') >= 0 || rawContent.indexOf('https://') >= 0) {
      if (this.viewModel.getOrParseBBCode(rawContent, tid, this.autoSimp, this.isActualDarkMode).some((s: RichSpan) => s.rubyText !== '')) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.End }) {
          ForEach(this.buildRubyAtoms(this.viewModel.getOrParseBBCode(rawContent, tid, this.autoSimp, this.isActualDarkMode)), (atom: RubyRenderAtom) => {
            if (atom.rubyText !== '') {
              if (this.isCommentSafeRubyAtom(atom, fontSize)) {
                this.CommentRubySpan(atom, fontSize, lineHeight)
              } else {
                this.CommentRubyPlainAtom(atom, fontSize, lineHeight)
              }
            } else {
              this.CommentRubyPlainAtom(atom, fontSize, lineHeight)
            }
          }, (atom: RubyRenderAtom) => `csr_${atom.key}_${atom.text}`)
        }.width('100%')
      } else {
        Text() {
          ForEach(this.viewModel.getOrParseBBCode(rawContent, tid, this.autoSimp, this.isActualDarkMode), (span: RichSpan) => {
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
        .lineHeight(lineHeight).width('100%').copyOption(CopyOptions.LocalDevice)
      }
    } else {
      Text(this.autoSimp ? T2SEngine.convert(rawContent.replace(/<br\s*\/?>/gi, '\n')) : rawContent.replace(/<br\s*\/?>/gi, '\n'))
        .fontSize(fontSize).fontColor(Constants.TEXT_PRIMARY).lineHeight(lineHeight)
        .width('100%').copyOption(CopyOptions.LocalDevice)
    }
  }

  
  @Builder ReplyItemBuilder(reply: CommentReply) {
    Column() {
      
      if (this.debugMode && reply.isBlocked === true) {
        Row() {
          SymbolGlyph($r('sys.symbol.eye_slash'))
            .fontSize(12).fontColor([Color.White])
          Text(' 已屏蔽（调试模式下显示）')
            .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
        }
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .borderRadius(4)
        .backgroundColor('#FF3B30')
        .margin({ bottom: 6 })
      }

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
        } else if (this.viewModel.isInteractionLoaded && this.viewModel.interaction.author.uid > 0
          && reply.user_info.uid === this.viewModel.interaction.author.uid) {
          Text('作者')
            .fontSize(9).fontColor(Color.White).fontWeight(FontWeight.Bold)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius(3).backgroundColor('#FF8C00')
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
        this.RichTextContent(reply.content, 13, 20, reply.tid || reply.rid || 0)
      }.margin({ top: 4 })

      Row() {
        Text(reply.time).fontSize(10).fontColor(Constants.TEXT_SECONDARY)
      }
      .width('100%').margin({ top: 4 })
    }
    .width('100%').padding({ top: 6, bottom: 6 })
    
    .border(this.debugMode && reply.isBlocked === true ? { width: { left: 3 }, color: '#FF3B30' } : {})
    .borderRadius(this.debugMode && reply.isBlocked === true ? 6 : 0)
    .padding(this.debugMode && reply.isBlocked === true ? { left: 8, top: 6, bottom: 6, right: 6 } : { top: 6, bottom: 6 })
    .backgroundColor(this.debugMode && reply.isBlocked === true ? '#1AFF3B30' : Color.Transparent)
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
      
      if (this.debugMode && comment.isBlocked === true) {
        Row() {
          SymbolGlyph($r('sys.symbol.eye_slash'))
            .fontSize(14).fontColor([Color.White])
          Text(' 已屏蔽（调试模式下显示）')
            .fontSize(11).fontColor(Color.White).fontWeight(FontWeight.Bold)
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(5)
        .backgroundColor('#FF3B30')
        .margin({ bottom: 8 })
      }

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
            } else if (this.viewModel.isInteractionLoaded && this.viewModel.interaction.author.uid > 0
              && comment.user_info.uid === this.viewModel.interaction.author.uid) {
              Text('作者')
                .fontSize(10).fontColor(Color.White).fontWeight(FontWeight.Bold)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .borderRadius(4).backgroundColor('#FF8C00')
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
        this.RichTextContent(comment.content, 15, 24, comment.tid)
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
    
    .border(this.debugMode && comment.isBlocked === true ? { width: { left: 3 }, color: '#FF3B30' } : {})
    .borderRadius(this.debugMode && comment.isBlocked === true ? 8 : 0)
    .backgroundColor(this.debugMode && comment.isBlocked === true ? '#1AFF3B30' : Color.Transparent)
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
              
              this.viewModel.clearCommentParseCache();
              
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

          Text(this.viewModel.articleTitle).fontSize(17).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
            .layoutWeight(1).constraintSize({ maxHeight: 44 }).lineHeight(20).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center).padding({ right: 60 })
        }
        .width('100%')
        .height(this.showNavBar ? 64 + this.topBarExtraHeight : 0)
        .padding({ top: this.topBarExtraHeight })
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
                      if (item.spans.length > 0 && item.spans.some((s: RichSpan) => s.rubyText !== '')) {
                        
                        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.End }) {
                          ForEach(this.buildRubyAtoms(item.spans), (atom: RubyRenderAtom) => {
                            if (atom.rubyText !== '') {
                              
                              if (this.isArticleSafeRubyAtom(atom)) {
                                this.ArticleRubySpan(atom)
                              } else {
                                this.ArticleRubyPlainAtom(atom)
                              }
                            } else {
                              this.ArticleRubyPlainAtom(atom)
                            }
                          }, (atom: RubyRenderAtom) => `ruby_${atom.key}_${atom.text}`)
                        }
                        .width('100%')
                      } else if (item.spans.length > 0 && item.spans.some((s: RichSpan) => s.bold || s.italic || s.underline || s.lineThrough || s.color !== '' || s.fontSize > 0 || s.linkUrl !== '')) {
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
              
              if (this.viewModel.payInfo && this.viewModel.payInfo.is_paid === 0 && this.viewModel.payInfo.price > 0) {
                ListItem() {
                  Column({ space: 16 }) {
                    SymbolGlyph($r('sys.symbol.lock_fill'))
                      .fontSize(32).fontColor([Constants.THEME_COLOR])

                    Text('本文为付费章节，支付后可阅读完整内容')
                      .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                      .fontWeight(FontWeight.Medium)

                    Button(this.viewModel.isPurchasing ? '支付中...' : `支付 ${this.viewModel.payInfo.price} 轻币解锁`)
                      .fontSize(15).fontWeight(FontWeight.Bold)
                      .width(220).height(40).borderRadius(20)
                      .backgroundColor(Constants.THEME_COLOR)
                      .enabled(!this.viewModel.isPurchasing)
                      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                      .onClick(() => {
                        
                        promptAction.showDialog({
                          title: '购买确认',
                          message: `是否确认花费 ${this.viewModel.payInfo?.price} 轻币解锁本章？`,
                          buttons: [
                            { text: '取消', color: Constants.TEXT_SECONDARY },
                            { text: '确认支付', color: Constants.THEME_COLOR }
                          ]
                        }).then(async (data) => {
                          if (data.index === 1) {
                            let success = await this.viewModel.doPurchase(this.currentAid);
                            if (success) {
                              promptAction.showToast({ message: '解锁成功，已为你加载全文' });
                            } else {
                              promptAction.showToast({ message: '解锁失败，可能余额不足或网络异常' });
                            }
                          }
                        });
                      })
                  }
                  .width('100%').constraintSize({ maxWidth: 840 })
                  .padding({ top: 40, bottom: 40 })
                  .backgroundColor(Constants.THEME_TINT_BG)
                  .borderRadius(12)
                  .margin({ top: 12, bottom: 12 })
                }
              }
              
              
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
                  Text(`评论 (${this.viewModel.commentTotal})` +
                    (this.viewModel.commentBlockedCount > 0
                      ? (this.debugMode
                        ? `（调试模式下显示已屏蔽${this.viewModel.commentBlockedCount}条）`
                        : `（已屏蔽${this.viewModel.commentBlockedCount}条）`)
                      : ''))
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
              
              if (this.readingTopBarAlwaysShow) {
                if (!this.showNavBar) {
                  animateTo({ duration: 300, curve: curves.springMotion() }, () => { this.showNavBar = true; });
                }
                return;
              }
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
            
            Row() {
              SymbolGlyph($r('sys.symbol.pencil_line'))
                .fontSize(16).fontColor([Constants.TEXT_SECONDARY])
                .margin({ right: 6 })
              Text('说点什么...')
                .fontSize(14).fontColor(Constants.TEXT_SECONDARY)
            }
            .layoutWeight(1)
            .height(36)
            .padding({ left: 14, right: 14 })
            .backgroundColor(Constants.PLACEHOLDER_BG)
            .borderRadius(18)
            .margin({ left: 12 })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
            .onClick(() => {
              
              if (this.showCommentInput) {
                this.showCommentInput = false;
                return;
              }
              this.replyTargetTid = 0;
              this.replyTargetRid = 0;
              this.replyTargetUid = 0;
              this.replyTargetNickname = '';
              this.replyPlaceholder = '说点什么...';
              this.commentText = '';
              this.showCommentInput = true;
            })

            
            Row({ space: 4 }) {
              Column() {
                SymbolGlyph(this.viewModel.interaction.already_like === 1
                  ? $r('sys.symbol.hand_thumbsup_fill')
                  : $r('sys.symbol.hand_thumbsup'))
                  .fontSize(20)
                  .fontColor(this.viewModel.interaction.already_like === 1 ? [Constants.THEME_COLOR] : [Constants.TEXT_SECONDARY])
                Text(this.viewModel.isInteractionLoaded
                  ? (this.viewModel.interaction.likes > 0 ? `${this.viewModel.interaction.likes}` : '点赞')
                  : '点赞')
                  .fontSize(9).fontColor(this.viewModel.interaction.already_like === 1 ? Constants.THEME_COLOR : Constants.TEXT_SECONDARY)
                  .margin({ top: 1 })
              }
              .width(48).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
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
                  .fontSize(20)
                  .fontColor(this.viewModel.interaction.already_fav === 1 ? ['#FFD700'] : [Constants.TEXT_SECONDARY])
                Text(this.viewModel.isInteractionLoaded
                  ? (this.viewModel.interaction.favorites > 0 ? `${this.viewModel.interaction.favorites}` : '收藏')
                  : '收藏')
                  .fontSize(9).fontColor(this.viewModel.interaction.already_fav === 1 ? '#FFD700' : Constants.TEXT_SECONDARY)
                  .margin({ top: 1 })
              }
              .width(48).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .onClick(() => {
                if (this.viewModel.isInteractionLoaded) {
                  this.viewModel.doFavorite(this.currentAid);
                }
              })

              Column() {
                Image($r('app.media.ic_comment'))
                  .width(20).height(20)
                  .fillColor(Constants.TEXT_SECONDARY)
                Text(this.viewModel.isInteractionLoaded
                  ? (this.viewModel.interaction.comments > 0 ? `${this.viewModel.interaction.comments}` : '评论')
                  : '评论')
                  .fontSize(9).fontColor(Constants.TEXT_SECONDARY)
                  .margin({ top: 1 })
              }
              .width(48).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .onClick(() => {
                
                
                
                
                if (this.showCommentInput) {
                  this.showCommentInput = false;
                  return;
                }
                if (this.hasJumpedViaCommentBtn && this.savedReadingIndex > 0) {
                  
                  this.scroller.scrollToIndex(this.savedReadingIndex, false);
                  this.savedReadingIndex = -1;
                  this.hasJumpedViaCommentBtn = false;
                } else {
                  
                  this.savedReadingIndex = this.lastFirstVisibleIndex;
                  this.hasJumpedViaCommentBtn = true;
                  this.scrollToComments();
                }
              })
            }
            .margin({ left: 8, right: 8 })
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
              .backgroundColor($r('sys.color.menu_back_blur_color'))
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
                
                if (this.mContext) {
                  this.viewModel.downloadAndSaveImage(this.previewImageUrl, this.mContext);
                } else {
                  let ctx = getContext(this) as common.UIAbilityContext;
                  this.viewModel.downloadAndSaveImage(this.previewImageUrl, ctx);
                }
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
