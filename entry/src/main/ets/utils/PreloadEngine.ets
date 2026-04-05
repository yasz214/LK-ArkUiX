import { NovelRepository } from '../repository/NovelRepository';
import { NativeArticleParser } from './NativeArticleParser';
import { ContentItem } from '../models/DataModels';
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

  
  maxConcurrent: number = 3;
  throttleMs: number = 200;
  cacheTtlMinutes: number = 0;        
  maxCacheCount: number = 100;        

  static applyPreset(config: PreloadConfig) {
    if (config.preset === 0) { config.maxConcurrent = 1; }
    else if (config.preset === 1) { config.maxConcurrent = 3; }
    else { config.maxConcurrent = 5; }
    config.throttleMs = 200;
    config.cacheTtlMinutes = 0;
    config.maxCacheCount = 100;
  }

  static fromRecord(obj: Record<string, Object>): PreloadConfig {
    let c = new PreloadConfig();
    if (obj['enabled'] !== undefined) c.enabled = obj['enabled'] as boolean;
    if (obj['preset'] !== undefined) c.preset = obj['preset'] as number;
    if (obj['depth'] !== undefined) c.depth = obj['depth'] as number;
    if (obj['maxCacheSizeMB'] !== undefined) c.maxCacheSizeMB = obj['maxCacheSizeMB'] as number;
    if (obj['wifiOnly'] !== undefined) c.wifiOnly = obj['wifiOnly'] as boolean;
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

  
  private static async fetchAndCache(aid: number) {
    try {
      let result = await NovelRepository.getArticleDetail(aid);
      let rawContent = result.data.content || '';
      let title = result.data.title || '';
      let parsedItems = NativeArticleParser.parse(rawContent, result.rawJson);

      
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
      PreferenceManager.evictOldestArticleCaches(limitBytes);
      FileLog.i(TAG, `磁盘缓存超限(${stats.totalSizeStr}>${PreloadEngine.config.maxCacheSizeMB}MB)，已自动清理`);
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
