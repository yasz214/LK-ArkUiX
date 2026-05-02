import { NovelRepository } from '../repository/NovelRepository';
import { NativeArticleParser } from './NativeArticleParser';
import { ContentItem, ArticleInteraction, AuthorInfo, UserLevel } from '../models/DataModels';
import { T2SEngine } from './T2SEngine';
import { PreferenceManager } from './PreferenceManager';
import { FileLog } from './FileLog';
import { WifiHelper } from './WifiHelper';

const TAG = 'PreloadEngine';


export const PRELOAD_STATS_ENABLED: boolean = true;


export class PreloadConfig {
  enabled: boolean = true;            
  preset: number = 2;                 
  depth: number = 3;                  
  maxCacheSizeMB: number = 10;        
  wifiOnly: boolean = false;          
  powerMode: boolean = false;         

  
  maxConcurrent: number = 5;
  throttleMs: number = 200;
  cacheTtlMinutes: number = 0;        
  maxCacheCount: number = 100;        

  static applyPreset(config: PreloadConfig) {
    if (config.powerMode) {
      
      config.maxConcurrent = 8;
      config.throttleMs = 100;
      config.depth = 3;
      config.wifiOnly = false;
      config.maxCacheCount = 200;
    } else {
      if (config.preset === 0) { config.maxConcurrent = 1; }
      else if (config.preset === 1) { config.maxConcurrent = 3; }
      else { config.maxConcurrent = 5; }
      config.throttleMs = 200;
      config.cacheTtlMinutes = 0;
      config.maxCacheCount = 100;
    }
  }

  static fromRecord(obj: Record<string, Object>): PreloadConfig {
    let c = new PreloadConfig();
    if (obj['enabled'] !== undefined) c.enabled = obj['enabled'] as boolean;
    if (obj['preset'] !== undefined) c.preset = obj['preset'] as number;
    if (obj['depth'] !== undefined) c.depth = obj['depth'] as number;
    if (obj['maxCacheSizeMB'] !== undefined) c.maxCacheSizeMB = obj['maxCacheSizeMB'] as number;
    if (obj['wifiOnly'] !== undefined) c.wifiOnly = obj['wifiOnly'] as boolean;
    if (obj['powerMode'] !== undefined) c.powerMode = obj['powerMode'] as boolean;
    PreloadConfig.applyPreset(c);
    return c;
  }
}


export class PreloadStats {
  totalPreloaded: number = 0;
  totalSavedBytes: number = 0;
  memCacheCount: number = 0;
  memCacheSizeBytes: number = 0;
  queueLength: number = 0;
  activeCount: number = 0;
}


class CacheEntry {
  aid: number;
  title: string;
  parsedItems: ContentItem[];
  navTitle: string;
  createdAt: number;
  lastAccess: number;
  sizeEstimate: number;

  constructor(aid: number, title: string, parsedItems: ContentItem[], navTitle: string) {
    this.aid = aid;
    this.title = title;
    this.parsedItems = parsedItems;
    this.navTitle = navTitle;
    let now = Date.now();
    this.createdAt = now;
    this.lastAccess = now;
    let size = title.length * 2 + navTitle.length * 2;
    for (let i = 0; i < parsedItems.length; i++) {
      size += parsedItems[i].value.length * 2;
      if (parsedItems[i].url) {
        size += (parsedItems[i].url as string).length * 2;
      }
    }
    this.sizeEstimate = size;
  }
}


class QueueItem {
  aid: number;
  priority: number;
  addedAt: number;

  constructor(aid: number, priority: number) {
    this.aid = aid;
    this.priority = priority;
    this.addedAt = Date.now();
  }
}


export class PreloadEngine {
  private static memCache: Map<number, CacheEntry> = new Map();
  
  private static lruOrder: number[] = [];
  private static queue: QueueItem[] = [];
  private static activeCount: number = 0;
  private static pending: Set<number> = new Set();
  private static config: PreloadConfig = new PreloadConfig();
  private static stats: PreloadStats = new PreloadStats();
  private static initialized: boolean = false;
  
  private static preloadsSinceCheck: number = 0;

  
  static async init() {
    if (PreloadEngine.initialized) return;
    PreloadEngine.initialized = true;
    try {
      let raw = await PreferenceManager.getString('preload_config', '');
      if (raw) {
        let obj = JSON.parse(raw) as Record<string, Object>;
        PreloadEngine.config = PreloadConfig.fromRecord(obj);
      }
    } catch (e) {
      FileLog.w(TAG, '读取预加载配置失败，使用默认值');
    }
    FileLog.i(TAG, `初始化完成: enabled=${PreloadEngine.config.enabled}, preset=${PreloadEngine.config.preset}`);

    
    let powerMode = AppStorage.get<boolean>('preloadPowerMode') ?? false;
    if (!powerMode) {
      powerMode = PreferenceManager.getBooleanSync('preloadPowerMode', false);
    }
    if (powerMode) {
      PreloadEngine.config.preset = 2;
      PreloadEngine.config.depth = 3;
      PreloadConfig.applyPreset(PreloadEngine.config);
      FileLog.i(TAG, '极致模式已激活: preset=2, depth=3, concurrent=5');
    }
  }

  static getConfig(): PreloadConfig {
    return PreloadEngine.config;
  }

  static async saveConfig(config: PreloadConfig) {
    PreloadConfig.applyPreset(config);
    PreloadEngine.config = config;
    let obj: Record<string, boolean | number> = {
      'enabled': config.enabled,
      'preset': config.preset,
      'depth': config.depth,
      'powerMode': config.powerMode,
      'maxCacheSizeMB': config.maxCacheSizeMB,
      'wifiOnly': config.wifiOnly
    };
    await PreferenceManager.putString('preload_config', JSON.stringify(obj));
    FileLog.i(TAG, `配置已保存: preset=${config.preset}, depth=${config.depth}, concurrent=${config.maxConcurrent}`);
  }

  
  static enqueue(aid: number, priority: number = 1) {
    if (!PreloadEngine.config.enabled) return;
    if (PreloadEngine.memCache.has(aid)) return;
    if (PreloadEngine.pending.has(aid)) return;

    PreloadEngine.pending.add(aid);

    let qItem = new QueueItem(aid, priority);
    let inserted = false;
    for (let i = 0; i < PreloadEngine.queue.length; i++) {
      if (PreloadEngine.queue[i].priority > priority) {
        PreloadEngine.queue.splice(i, 0, qItem);
        inserted = true;
        break;
      }
    }
    if (!inserted) {
      PreloadEngine.queue.push(qItem);
    }
    PreloadEngine.scheduleNext();
  }

  static enqueueBatch(aids: number[], priority: number = 2) {
    for (let i = 0; i < aids.length; i++) {
      PreloadEngine.enqueue(aids[i], priority);
    }
  }

  
  private static scheduleNext() {
    if (!PreloadEngine.config.enabled) return;
    if (PreloadEngine.activeCount >= PreloadEngine.config.maxConcurrent) return;
    if (PreloadEngine.queue.length === 0) return;

    
    if (PreloadEngine.config.wifiOnly) {
      PreloadEngine.checkWifiAndSchedule();
      return;
    }

    PreloadEngine.doScheduleNext();
  }

  
  private static checkWifiAndSchedule() {
    WifiHelper.isWifiConnected().then((isWifi: boolean) => {
      if (isWifi) {
        PreloadEngine.doScheduleNext();
      } else {
        FileLog.i(TAG, '当前非WiFi网络，暂停预加载');
      }
    }).catch(() => {
      
      FileLog.w(TAG, '获取WiFi状态失败，继续预加载');
      PreloadEngine.doScheduleNext();
    });
  }

  private static doScheduleNext() {
    let nextItem = PreloadEngine.queue.shift();
    if (!nextItem) return;

    let aidToFetch = nextItem.aid;
    PreloadEngine.activeCount++;
    PreloadEngine.fetchAndCache(aidToFetch).then(() => {
      PreloadEngine.activeCount--;
      if (PreloadEngine.config.throttleMs > 0 && PreloadEngine.queue.length > 0) {
        setTimeout(() => {
          PreloadEngine.scheduleNext();
        }, PreloadEngine.config.throttleMs);
      } else {
        PreloadEngine.scheduleNext();
      }
    }).catch(() => {
      PreloadEngine.activeCount--;
      PreloadEngine.pending.delete(aidToFetch);
      PreloadEngine.scheduleNext();
    });
  }

  
  private static extractSelfUid(): string {
    let securityKey = AppStorage.get<string>('security_key') ?? '';
    if (securityKey && securityKey.indexOf(':') > 0) {
      let parts = securityKey.split(':');
      if (parts.length >= 2) {
        return parts[1];
      }
    }
    return '0';
  }

  private static interactionCacheKey(aid: number): string {
    return `cache_interaction_article_${PreloadEngine.extractSelfUid()}_${aid}`;
  }

  private static rebuildInteraction(raw: Record<string, Object>): ArticleInteraction {
    let interaction = new ArticleInteraction();
    interaction.hits = (raw['hits'] as number) ?? 0;
    interaction.likes = (raw['likes'] as number) ?? 0;
    interaction.coins = (raw['coins'] as number) ?? 0;
    interaction.favorites = (raw['favorites'] as number) ?? 0;
    interaction.comments = (raw['comments'] as number) ?? 0;
    interaction.already_like = (raw['already_like'] as number) ?? 0;
    interaction.already_fav = (raw['already_fav'] as number) ?? 0;
    interaction.already_follow = (raw['already_follow'] as number) ?? 0;
    interaction.already_coin = (raw['already_coin'] as number) ?? 0;
    interaction.time = (raw['time'] as string) ?? '';

    let rawAuthor = raw['author'] as Record<string, Object>;
    if (rawAuthor) {
      let author = new AuthorInfo();
      author.uid = (rawAuthor['uid'] as number) ?? 0;
      author.nickname = (rawAuthor['nickname'] as string) ?? '';
      author.avatar = (rawAuthor['avatar'] as string) ?? '';
      author.passer = (rawAuthor['passer'] as number) ?? 0;
      author.sign = (rawAuthor['sign'] as string) ?? '';
      author.followers = (rawAuthor['followers'] as number) ?? 0;
      author.articles = (rawAuthor['articles'] as number) ?? 0;
      let rawLevel = rawAuthor['level'] as Record<string, Object>;
      if (rawLevel) {
        let level = new UserLevel();
        level.level = (rawLevel['level'] as number) ?? 0;
        level.name = (rawLevel['name'] as string) ?? '';
        level.exp = (rawLevel['exp'] as number) ?? 0;
        author.level = level;
      }
      interaction.author = author;
    }
    return interaction;
  }

  private static interactionToRecord(interaction: ArticleInteraction): Record<string, number | string | Object> {
    let levelRecord: Record<string, number | string> = {
      'level': interaction.author.level.level,
      'name': interaction.author.level.name,
      'exp': interaction.author.level.exp
    };
    let authorRecord: Record<string, number | string | Object> = {
      'uid': interaction.author.uid,
      'nickname': interaction.author.nickname,
      'avatar': interaction.author.avatar,
      'passer': interaction.author.passer,
      'sign': interaction.author.sign,
      'followers': interaction.author.followers,
      'articles': interaction.author.articles,
      'level': levelRecord
    };
    let record: Record<string, number | string | Object> = {
      'hits': interaction.hits,
      'likes': interaction.likes,
      'coins': interaction.coins,
      'favorites': interaction.favorites,
      'comments': interaction.comments,
      'already_like': interaction.already_like,
      'already_fav': interaction.already_fav,
      'already_follow': interaction.already_follow,
      'already_coin': interaction.already_coin,
      'time': interaction.time,
      'author': authorRecord
    };
    return record;
  }

  private static cacheInteractionFromRawJson(aid: number, rawJson: string) {
    try {
      if (PreloadEngine.extractSelfUid() === '0') return;
      let parsed: Object = JSON.parse(rawJson);
      let rawObj = parsed as Record<string, Object>;
      let dataObj = rawObj['data'] as Record<string, Object>;
      if (!dataObj) return;
      let interaction = PreloadEngine.rebuildInteraction(dataObj);
      if (interaction.author.uid <= 0) return;
      PreferenceManager.putString(PreloadEngine.interactionCacheKey(aid), JSON.stringify(PreloadEngine.interactionToRecord(interaction)));
    } catch (e) {}
  }

  private static async fetchAndCache(aid: number) {
    try {
      let result = await NovelRepository.getArticleDetail(aid);
      let rawContent = result.data.content || '';
      let title = result.data.title || '';
      let parsedItems = NativeArticleParser.parse(rawContent, result.rawJson);
      PreloadEngine.cacheInteractionFromRawJson(aid, result.rawJson);

      
      let navTitle = '';
      try {
        let rawObj = JSON.parse(result.rawJson) as Record<string, Object>;
        let dataObj = rawObj['data'] as Record<string, Object>;
        if (dataObj) {
          let rawTag = (dataObj['sort'] as string) || (dataObj['type'] as string) || (dataObj['category'] as string) || (dataObj['tag'] as string);
          if (rawTag) {
            let baseTag = String(rawTag).replace('阅读', '');
            navTitle = baseTag + '阅读';
          }
        }
      } catch (e) {}

      
      let autoSimp = AppStorage.get<boolean>('autoSimp') ?? false;
      let finalTitle = title;
      let finalItems = parsedItems;
      let finalNavTitle = navTitle;

      if (autoSimp) {
        finalTitle = T2SEngine.convert(title);
        finalItems = await T2SEngine.convertItemsAsync(parsedItems);
        if (navTitle) {
          finalNavTitle = T2SEngine.convert(navTitle);
        }
      }

      
      let entry = new CacheEntry(aid, finalTitle, finalItems, finalNavTitle);
      PreloadEngine.memCache.set(aid, entry);
      
      PreloadEngine.lruOrder.push(aid);

      
      let cacheObj: Record<string, string | ContentItem[]> = {
        'title': title,
        'parsedItems': parsedItems,
        'navTitle': navTitle
      };
      PreferenceManager.putString(`cache_article_${aid}`, JSON.stringify(cacheObj));
      PreferenceManager.putString(`time_article_${aid}`, PreloadEngine.formatTime());

      PreloadEngine.stats.totalPreloaded++;
      PreloadEngine.stats.totalSavedBytes += entry.sizeEstimate;

      
      PreloadEngine.evictIfNeeded();

      
      PreloadEngine.preloadsSinceCheck++;
      if (PreloadEngine.preloadsSinceCheck >= 5) {
        PreloadEngine.preloadsSinceCheck = 0;
        PreloadEngine.checkDiskCacheLimit();
      }

      
      
      
      
      if (PreloadEngine.config.depth >= 1) {
        
        try {
          await NovelRepository.getComments(aid, 1, 20);
        } catch (e) {  }
      }
      if (PreloadEngine.config.depth >= 2) {
        
        try {
          let rawObj = JSON.parse(result.rawJson) as Record<string, Object>;
          let dataObj = rawObj['data'] as Record<string, Object>;
          if (dataObj) {
            let authorObj = dataObj['author'] as Record<string, Object>;
            if (authorObj && authorObj['uid']) {
              let authorUid = authorObj['uid'] as number;
              if (authorUid > 0) {
                await NovelRepository.getUserProfile(authorUid);
              }
            }
          }
        } catch (e) {  }
      }
      if (PreloadEngine.config.depth >= 3) {
        
        try {
          let rawObj = JSON.parse(result.rawJson) as Record<string, Object>;
          let dataObj = rawObj['data'] as Record<string, Object>;
          if (dataObj) {
            let authorObj = dataObj['author'] as Record<string, Object>;
            if (authorObj && authorObj['uid']) {
              let authorUid = authorObj['uid'] as number;
              if (authorUid > 0) {
                await NovelRepository.getUserArticles(authorUid, 1, 0);
              }
            }
          }
        } catch (e) {  }
      }
    } catch (e) {
      
    } finally {
      PreloadEngine.pending.delete(aid);
    }
  }

  
  private static checkDiskCacheLimit() {
    if (PreloadEngine.config.maxCacheSizeMB <= 0) return;
    let limitBytes = PreloadEngine.config.maxCacheSizeMB * 1024 * 1024;
    let stats = PreferenceManager.getCacheStats();
    if (stats.totalSizeBytes > limitBytes) {
      let smartCleanup = AppStorage.get<boolean>('smartCacheCleanupEnabled') ?? PreferenceManager.getBooleanSync('smartCacheCleanupEnabled', true);
      if (smartCleanup) {
        PreferenceManager.evictSmartArticleCaches(limitBytes);
        FileLog.i(TAG, `磁盘缓存超限(${stats.totalSizeStr}>${PreloadEngine.config.maxCacheSizeMB}MB)，已按阅读习惯智能清理`);
      } else {
        PreferenceManager.evictOldestArticleCaches(limitBytes);
        FileLog.i(TAG, `磁盘缓存超限(${stats.totalSizeStr}>${PreloadEngine.config.maxCacheSizeMB}MB)，已自动清理`);
      }
    }
  }

  
  private static evictIfNeeded() {
    while (PreloadEngine.memCache.size > PreloadEngine.config.maxCacheCount && PreloadEngine.lruOrder.length > 0) {
      let oldestAid = PreloadEngine.lruOrder.shift()!; 
      PreloadEngine.memCache.delete(oldestAid);
    }
  }

  
  static getFromMemory(aid: number): CacheEntry | null {
    let entry = PreloadEngine.memCache.get(aid);
    if (entry) {
      if (PreloadEngine.config.cacheTtlMinutes > 0) {
        let ageMs = Date.now() - entry.createdAt;
        if (ageMs > PreloadEngine.config.cacheTtlMinutes * 60 * 1000) {
          PreloadEngine.memCache.delete(aid);
          
          let idx = PreloadEngine.lruOrder.indexOf(aid);
          if (idx !== -1) { PreloadEngine.lruOrder.splice(idx, 1); }
          return null;
        }
      }
      entry.lastAccess = Date.now();
      
      let idx = PreloadEngine.lruOrder.indexOf(aid);
      if (idx !== -1) { PreloadEngine.lruOrder.splice(idx, 1); }
      PreloadEngine.lruOrder.push(aid);
      return entry;
    }
    return null;
  }

  
  static getStats(): PreloadStats {
    let s = new PreloadStats();
    s.totalPreloaded = PreloadEngine.stats.totalPreloaded;
    s.totalSavedBytes = PreloadEngine.stats.totalSavedBytes;
    s.memCacheCount = PreloadEngine.memCache.size;
    s.queueLength = PreloadEngine.queue.length;
    s.activeCount = PreloadEngine.activeCount;
    let totalMem = 0;
    PreloadEngine.memCache.forEach((entry: CacheEntry) => {
      totalMem += entry.sizeEstimate;
    });
    s.memCacheSizeBytes = totalMem;
    return s;
  }

  static clearMemoryCache() {
    PreloadEngine.memCache.clear();
    PreloadEngine.lruOrder = [];
    PreloadEngine.queue = [];
    PreloadEngine.pending.clear();
    PreloadEngine.activeCount = 0;
    PreloadEngine.stats = new PreloadStats();
    FileLog.i(TAG, '内存缓存已清除');
  }

  static pause() {
    PreloadEngine.config.enabled = false;
  }

  static resume() {
    PreloadEngine.config.enabled = true;
    PreloadEngine.scheduleNext();
  }

  private static formatTime(): string {
    let d = new Date();
    let y = d.getFullYear();
    let m = (d.getMonth() + 1).toString().padStart(2, '0');
    let day = d.getDate().toString().padStart(2, '0');
    let h = d.getHours().toString().padStart(2, '0');
    let min = d.getMinutes().toString().padStart(2, '0');
    let s = d.getSeconds().toString().padStart(2, '0');
    return `${y}/${m}/${day} ${h}:${min}:${s}`;
  }
}
