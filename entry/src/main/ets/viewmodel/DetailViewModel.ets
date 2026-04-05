import { promptAction } from '@kit.ArkUI';
import { NovelRepository } from '../repository/NovelRepository';
import { NativeArticleParser } from '../utils/NativeArticleParser';
import { ContentDataSource } from '../utils/ContentDataSource';
import axios, { AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import { ContentItem, ArticleInteraction, CommentItem } from '../models/DataModels';
import { T2SEngine } from '../utils/T2SEngine';
import { PreferenceManager } from '../utils/PreferenceManager';
import { FileLog } from '../utils/FileLog';
import { PreloadEngine } from '../utils/PreloadEngine';
import { ImageSaveHelper } from '../utils/ImageSaveHelper';
import { ImageCacheManager } from '../utils/ImageCacheManager';

interface ArticleDetailData {
  content?: string;
  title?: string;
  type?: string;     
  sort?: string;
  category?: string;
  tag?: string;
}

interface ArticleDetailResult {
  data: ArticleDetailData;
  rawJson: string;
}

@Observed
export class DetailViewModel {
  articleTitle: string = '';
  navTitle: string = '文章阅读'; 
  isLoading: boolean = true;
  isError: boolean = false;
  message: string = '加载排版中...';
  contentData: ContentDataSource = new ContentDataSource();

  private renderSessionId: number = 0;

  isUpdating: boolean = false;
  lastUpdateTime: string = '';

  
  interaction: ArticleInteraction = new ArticleInteraction();
  isInteractionLoaded: boolean = false;

  
  comments: CommentItem[] = [];
  hotComments: CommentItem[] = [];
  commentTotal: number = 0;
  commentPage: number = 1;
  commentHasMore: boolean = false;
  isLoadingComments: boolean = false;
  isPostingComment: boolean = false;

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

  async loadDetail(aid: number, isRefresh: boolean = false) {
    let cacheKey = `cache_article_${aid}`;
    let timeKey = `time_article_${aid}`;

    if (!isRefresh) {
      this.isLoading = true;
      NovelRepository.addHistory(aid);

      
      let memEntry = PreloadEngine.getFromMemory(aid);
      if (memEntry) {
        FileLog.i('DetailVM', `命中预加载内存缓存: aid=${aid}`);
        this.articleTitle = memEntry.title;
        if (memEntry.navTitle) this.navTitle = memEntry.navTitle;
        this.contentData.setData(memEntry.parsedItems);
        this.message = '';
        this.isLoading = false;
        this.isError = false;
        this.lastUpdateTime = this.getFormattedTime();
      } else {
        
        let cache = await PreferenceManager.getString(cacheKey, '');
        let time = await PreferenceManager.getString(timeKey, '');

        if (cache) {
          try {
            let cachedObj = JSON.parse(cache) as Record<string, Object>;
            let cachedTitle = cachedObj['title'] as string;
            let cachedItems = cachedObj['parsedItems'] as ContentItem[];
            let cachedNavTitle = cachedObj['navTitle'] as string;

            if (cachedNavTitle) this.navTitle = cachedNavTitle;

            
            await this.renderToUIAsync(cachedTitle, cachedItems);
            this.message = '';
            this.isLoading = false;
            this.isError = false;
          } catch (e) {}
        }
        if (time) this.lastUpdateTime = time;
      }
    }

    this.isUpdating = true;
    try {
      let result = await NovelRepository.getArticleDetail(aid) as ArticleDetailResult;
      let originalRawContent = result.data.content || '';
      let originalTitle = result.data.title || '';

      
      let rawTag = result.data.sort || result.data.type || result.data.category || result.data.tag;
      if (rawTag) {
        let baseTag = String(rawTag).replace('阅读', '');
        let autoSimp = AppStorage.get<boolean>('autoSimp') ?? true;
        let finalTitle = baseTag + '阅读';
        this.navTitle = autoSimp ? T2SEngine.convert(finalTitle) : finalTitle;
      }

      let originalParsedItems = NativeArticleParser.parse(originalRawContent, result.rawJson);

      let now = this.getFormattedTime();
      this.lastUpdateTime = now;

      let cacheObj: Record<string, string | ContentItem[]> = {
        'title': originalTitle,
        'parsedItems': originalParsedItems,
        'navTitle': this.navTitle 
      };

      PreferenceManager.putString(cacheKey, JSON.stringify(cacheObj));
      PreferenceManager.putString(timeKey, now);

      
      await this.renderToUIAsync(originalTitle, originalParsedItems);
      this.message = '';
      this.isError = false;
    } catch (e) {
      if (this.contentData.totalCount() === 0) {
        this.message = '网络请求失败';
        this.isError = true;
      }
    } finally {
      this.isLoading = false;
      this.isUpdating = false;
    }
  }

  private async renderToUIAsync(originalTitle: string, originalParsedItems: ContentItem[]) {
    this.renderSessionId++;
    let currentSession = this.renderSessionId;
    let autoSimp = AppStorage.get<boolean>('autoSimp') ?? false;

    FileLog.i('DetailVM', `renderToUIAsync: ${originalParsedItems.length} 条内容, autoSimp=${autoSimp}`);
    
    let textCount = 0, imgCount = 0, linkCount = 0;
    for (let item of originalParsedItems) {
      if (item.type === 'text') textCount++;
      else if (item.type === 'image') imgCount++;
      else linkCount++;
    }
    FileLog.i('DetailVM', `内容分布: text=${textCount}, image=${imgCount}, link=${linkCount}`);

    try {
      if (!autoSimp) {
        this.articleTitle = originalTitle;
        this.contentData.setData(originalParsedItems);
        FileLog.i('DetailVM', `直接渲染完成, contentData.totalCount=${this.contentData.totalCount()}`);
        return;
      }

      this.articleTitle = T2SEngine.convert(originalTitle);
      FileLog.i('DetailVM', `标题转换完成: "${this.articleTitle.substring(0, 30)}"`);

      let convertedItems = await T2SEngine.convertItemsAsync(originalParsedItems);
      FileLog.i('DetailVM', `繁简转换完成, 转换后条数=${convertedItems.length}`);

      if (this.renderSessionId !== currentSession) {
        FileLog.w('DetailVM', `渲染会话已过期 (current=${this.renderSessionId}, session=${currentSession}), 跳过 setData`);
        return;
      }
      this.contentData.setData(convertedItems);
      FileLog.i('DetailVM', `繁简转换渲染完成, contentData.totalCount=${this.contentData.totalCount()}`);
    } catch (e) {
      let err = e as Error;
      FileLog.e('DetailVM', `renderToUIAsync 异常! message=${err.message}`);
      FileLog.e('DetailVM', `renderToUIAsync 异常堆栈: ${JSON.stringify(e)}`);
      
      try {
        this.articleTitle = originalTitle;
        this.contentData.setData(originalParsedItems);
        FileLog.i('DetailVM', `异常回退渲染完成, contentData.totalCount=${this.contentData.totalCount()}`);
      } catch (e2) {
        FileLog.e('DetailVM', `异常回退也失败: ${(e2 as Error).message}`);
      }
    }
  }

  async downloadAndSaveImage(imageUrl: string, context: common.UIAbilityContext) {
    try {
      FileLog.i('ImageSave', `===== 图片保存流程开始 =====`);
      FileLog.i('ImageSave', `图片URL: ${imageUrl}`);

      
      let ext = '.jpg';
      let urlLower = imageUrl.toLowerCase();
      if (urlLower.indexOf('.png') !== -1) ext = '.png';
      else if (urlLower.indexOf('.webp') !== -1) ext = '.webp';
      else if (urlLower.indexOf('.gif') !== -1) ext = '.gif';

      
      let buffer: ArrayBuffer | null = await ImageCacheManager.waitAndGetBuffer(imageUrl);

      if (buffer && buffer.byteLength > 0) {
        FileLog.i('ImageSave', ` 从缓存获取成功! 大小=${buffer.byteLength} bytes`);
      } else {
        
        FileLog.w('ImageSave', '⚠️ 缓存获取失败，降级HTTP下载...');
        try { promptAction.openToast({ message: '正在下载图片...' }); } catch { }
        let config: AxiosRequestConfig<null> = {
          url: imageUrl,
          method: 'get',
          responseType: 'array_buffer',
          timeout: 30000
        };

        let res: AxiosResponse<ArrayBuffer> = await axios.request<ArrayBuffer, AxiosResponse<ArrayBuffer>, null>(config);
        buffer = res.data;
        FileLog.i('ImageSave', `降级下载完成, HTTP状态=${res.status}, 大小=${buffer.byteLength} bytes`);
      }

      if (buffer.byteLength === 0) {
        FileLog.e('ImageSave', '下载的文件大小为0，终止');
        try { promptAction.openToast({ message: '下载失败：文件为空' }); } catch { }
        return;
      }

      
      let timestamp = new Date().getTime();
      let safeTitle = this.articleTitle.replace(/[\\/:*?"<>|]/g, '_').substring(0, 60);
      if (!safeTitle) safeTitle = '图片';
      let tempFileName = `${safeTitle}_${timestamp}${ext}`;
      let tempPath = context.tempDir + '/' + tempFileName;

      
      try {
        let tempFile = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        fs.writeSync(tempFile.fd, buffer);
        fs.closeSync(tempFile);
        FileLog.i('ImageSave', `临时文件已写入: ${tempPath}`);
      } catch (writeErr) {
        let we = writeErr as Error;
        FileLog.e('ImageSave', `写入临时文件失败: ${we.message}`);
        try { promptAction.openToast({ message: '保存失败：无法写入临时文件' }); } catch { }
        return;
      }

      
      try {
        let documentSaveOptions = new picker.DocumentSaveOptions();
        documentSaveOptions.newFileNames = [tempFileName];
        let documentPicker = new picker.DocumentViewPicker(context);
        let saveResult = await documentPicker.save(documentSaveOptions);

        if (saveResult && saveResult.length > 0) {
          let targetUri = saveResult[0];
          FileLog.i('ImageSave', `DocumentPicker 返回 URI: ${targetUri}`);

          
          if (targetUri.startsWith('content://')) {
            try {
              FileLog.i('ImageSave', '尝试策略1: Java Bridge ContentResolver');
              let bridgeSuccess = await ImageSaveHelper.saveViaContentResolver(targetUri, buffer);
              if (bridgeSuccess) {
                FileLog.i('ImageSave', '策略1 成功');
                try { promptAction.openToast({ message: '保存成功', duration: 3000 }); } catch { }
                try { fs.unlinkSync(tempPath); } catch (_e) {}
                return;
              }
            } catch (bridgeErr) {
              let be = bridgeErr as Error;
              FileLog.w('ImageSave', `策略0 异常: ${be.message}`);
            }
          }

          
          try {
            FileLog.i('ImageSave', '尝试策略2: fs.openSync(URI, WRITE_ONLY)');
            let targetFile = fs.openSync(targetUri, fs.OpenMode.WRITE_ONLY);
            fs.writeSync(targetFile.fd, buffer);
            fs.closeSync(targetFile);
            FileLog.i('ImageSave', '策略2 成功');
            try { promptAction.openToast({ message: '保存成功', duration: 3000 }); } catch { }
            try { fs.unlinkSync(tempPath); } catch (_e) {}
            return;
          } catch (err1b) {
            let e1b = err1b as Error;
            FileLog.e('ImageSave', `策略1b失败: ${e1b.message}`);
          }

          
          FileLog.e('ImageSave', '所有保存策略均失败');
          try { promptAction.openToast({ message: '保存失败，请查看调试日志', duration: 5000 }); } catch { }
        } else {
          FileLog.i('ImageSave', 'DocumentPicker: 用户取消');
        }
      } catch (docErr) {
        let de = docErr as Error;
        FileLog.e('ImageSave', `DocumentViewPicker 异常: ${de.message}`);
        try { promptAction.openToast({ message: '保存失败' }); } catch { }
      }

      
      try { fs.unlinkSync(tempPath); } catch (_e) {}
    } catch (e) {
      let err = e as Error;
      FileLog.e('ImageSave', `图片保存顶层异常: ${err.message}`);
      try { promptAction.openToast({ message: '图片保存失败' }); } catch { }
    }
  }

  

  async loadInteraction(aid: number) {
    try {
      let result = await NovelRepository.getArticleInteraction(aid);
      if (result) {
        this.interaction = result;
        this.isInteractionLoaded = true;
        FileLog.i('DetailVM', `交互状态加载完成: likes=${result.likes}, already_like=${result.already_like}, already_fav=${result.already_fav}, author=${result.author.nickname}`);
      }
    } catch (e) {
      FileLog.e('DetailVM', `loadInteraction 失败: ${(e as Error).message}`);
    }
  }

  

  async loadComments(aid: number, isLoadMore: boolean = false) {
    if (this.isLoadingComments) return;
    this.isLoadingComments = true;

    try {
      let page = isLoadMore ? this.commentPage + 1 : 1;
      let result = await NovelRepository.getComments(aid, page);

      if (isLoadMore) {
        
        for (let item of result.list) {
          this.comments.push(item);
        }
      } else {
        this.comments = result.list;
        this.hotComments = result.hots;
      }
      this.commentTotal = result.page_info.count;
      this.commentPage = result.page_info.cur;
      this.commentHasMore = result.page_info.has_next === 1;
      FileLog.i('DetailVM', `评论加载完成: page=${page}, total=${this.commentTotal}, loaded=${this.comments.length}, hasMore=${this.commentHasMore}`);
    } catch (e) {
      FileLog.e('DetailVM', `loadComments 失败: ${(e as Error).message}`);
    } finally {
      this.isLoadingComments = false;
    }
  }

  

  private cloneInteraction(): ArticleInteraction {
    let c = new ArticleInteraction();
    c.hits = this.interaction.hits;
    c.likes = this.interaction.likes;
    c.coins = this.interaction.coins;
    c.favorites = this.interaction.favorites;
    c.comments = this.interaction.comments;
    c.already_like = this.interaction.already_like;
    c.already_fav = this.interaction.already_fav;
    c.already_follow = this.interaction.already_follow;
    c.already_coin = this.interaction.already_coin;
    c.author = this.interaction.author;
    c.time = this.interaction.time;
    return c;
  }

  
  async doLike(aid: number) {
    
    let oldInteraction = this.cloneInteraction();
    let isLiking = this.interaction.already_like === 0;

    
    let optimistic = this.cloneInteraction();
    if (isLiking) {
      optimistic.already_like = 1;
      optimistic.likes = this.interaction.likes + 1;
    } else {
      optimistic.already_like = 0;
      optimistic.likes = Math.max(0, this.interaction.likes - 1);
    }
    this.interaction = optimistic;

    
    let success = await NovelRepository.toggleLike(aid);
    if (success) {
      promptAction.openToast({ message: isLiking ? '点赞成功' : '已取消点赞' });
    } else {
      
      this.interaction = oldInteraction;
      promptAction.openToast({ message: '操作失败，请检查登录状态' });
    }
  }

  
  async doFavorite(aid: number) {
    
    let oldInteraction = this.cloneInteraction();
    let isFaving = this.interaction.already_fav === 0;

    
    let optimistic = this.cloneInteraction();
    if (isFaving) {
      optimistic.already_fav = 1;
      optimistic.favorites = this.interaction.favorites + 1;
    } else {
      optimistic.already_fav = 0;
      optimistic.favorites = Math.max(0, this.interaction.favorites - 1);
    }
    this.interaction = optimistic;

    
    let success = await NovelRepository.toggleFavorite(aid);
    if (success) {
      promptAction.openToast({ message: isFaving ? '收藏成功' : '已取消收藏' });
    } else {
      
      this.interaction = oldInteraction;
      promptAction.openToast({ message: '操作失败，请检查登录状态' });
    }
  }

  async doFollow() {
    let authorUid = this.interaction.author.uid;
    if (authorUid <= 0) {
      promptAction.openToast({ message: '无法获取作者信息' });
      return;
    }
    let act = this.interaction.already_follow === 0 ? 0 : 1; 
    let success = await NovelRepository.toggleFollow(authorUid, act);
    if (success) {
      let updated = this.cloneInteraction();
      if (this.interaction.already_follow === 0) {
        updated.already_follow = 1;
        promptAction.openToast({ message: `已关注 ${this.interaction.author.nickname}` });
      } else {
        updated.already_follow = 0;
        promptAction.openToast({ message: `已取消关注` });
      }
      this.interaction = updated;
    } else {
      promptAction.openToast({ message: '操作失败，请检查登录状态' });
    }
  }

  

  
  likedCommentTids: number[] = [];
  private static readonly LIKED_COMMENTS_KEY = 'liked_comment_tids';

  private isCommentLiked(tid: number): boolean {
    return this.likedCommentTids.indexOf(tid) >= 0;
  }

  
  async loadLikedComments() {
    let raw = await PreferenceManager.getString(DetailViewModel.LIKED_COMMENTS_KEY, '[]');
    try {
      let arr = JSON.parse(raw) as number[];
      if (Array.isArray(arr)) {
        this.likedCommentTids = arr;
      }
    } catch (e) {
      this.likedCommentTids = [];
    }
  }

  
  private saveLikedComments() {
    PreferenceManager.putString(DetailViewModel.LIKED_COMMENTS_KEY, JSON.stringify(this.likedCommentTids));
  }

  async doCommentLike(tid: number) {
    
    let isLiking = !this.isCommentLiked(tid);

    
    let updateInList = (list: CommentItem[]): boolean => {
      for (let i = 0; i < list.length; i++) {
        if (list[i].tid === tid) {
          if (isLiking) {
            list[i].likes = list[i].likes + 1;
          } else {
            list[i].likes = Math.max(0, list[i].likes - 1);
          }
          return true;
        }
      }
      return false;
    };

    
    let found = updateInList(this.comments);
    
    if (!found) {
      updateInList(this.hotComments);
    }

    if (isLiking) {
      this.likedCommentTids.push(tid);
    } else {
      let idx = this.likedCommentTids.indexOf(tid);
      if (idx >= 0) this.likedCommentTids.splice(idx, 1);
    }

    
    this.comments = [...this.comments];
    if (this.hotComments.length > 0) {
      this.hotComments = [...this.hotComments];
    }
    this.likedCommentTids = [...this.likedCommentTids];

    
    let success = await NovelRepository.toggleCommentLike(tid);
    if (success) {
      
      this.saveLikedComments();
    } else {
      
      let rollbackInList = (list: CommentItem[]) => {
        for (let i = 0; i < list.length; i++) {
          if (list[i].tid === tid) {
            if (isLiking) {
              list[i].likes = Math.max(0, list[i].likes - 1);
            } else {
              list[i].likes = list[i].likes + 1;
            }
            break;
          }
        }
      };
      rollbackInList(this.comments);
      rollbackInList(this.hotComments);
      if (isLiking) {
        let idx = this.likedCommentTids.indexOf(tid);
        if (idx >= 0) this.likedCommentTids.splice(idx, 1);
      } else {
        this.likedCommentTids.push(tid);
      }
      this.comments = [...this.comments];
      this.hotComments = [...this.hotComments];
      this.likedCommentTids = [...this.likedCommentTids];
      promptAction.openToast({ message: '操作失败，请检查登录状态' });
    }
  }

  async doPostComment(aid: number, content: string): Promise<boolean> {
    if (this.isPostingComment) return false;
    this.isPostingComment = true;
    try {
      let success = await NovelRepository.postComment(aid, content);
      if (success) {
        promptAction.openToast({ message: '评论发送成功' });
        
        await this.loadComments(aid);
        return true;
      } else {
        promptAction.openToast({ message: '评论发送失败' });
        return false;
      }
    } catch (e) {
      promptAction.openToast({ message: '评论发送失败' });
      return false;
    } finally {
      this.isPostingComment = false;
    }
  }
}