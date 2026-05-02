import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';


export class CacheStatsData {
  totalFiles: number = 0;
  articleCount: number = 0;
  totalSizeBytes: number = 0;
  totalSizeStr: string = '0 B';
}

class SmartCacheCandidate {
  name: string = '';
  aid: number = 0;
  size: number = 0;
  mtime: number = 0;
  score: number = 0;
  protectedByHabit: boolean = false;
}

class ReadingHabitEntry {
  visits: number = 0;
  lastOpenAt: number = 0;
}

export class PreferenceManager {
  private static pref: dataPreferences.Preferences | null = null;
  private static readonly PREF_NAME = 'lightnovel_settings';
  public static contextDir: string = '';

  private static initPromise: Promise<void> | null = null;

  
  private static readonly FLUSH_DEBOUNCE_MS: number = 300;
  private static flushTimerId: number = -1;
  private static hasPendingWrites: boolean = false;

  static async init(context: common.UIAbilityContext) {
    if (!PreferenceManager.initPromise) {
      PreferenceManager.initPromise = new Promise(async (resolve) => {
        try {
          PreferenceManager.contextDir = context.filesDir;
          PreferenceManager.pref = await dataPreferences.getPreferences(context, PreferenceManager.PREF_NAME);
        } catch (e) {
          console.error("PreferenceManager 初始化失败", e);
        } finally {
          resolve();
        }
      });
    }
    await PreferenceManager.initPromise;
  }

  private static async getSafePref(): Promise<dataPreferences.Preferences | null> {
    if (!PreferenceManager.pref && PreferenceManager.initPromise) {
      await PreferenceManager.initPromise;
    }
    return PreferenceManager.pref;
  }

  
  private static formatSize(bytes: number): string {
    if (bytes === 0) return '0 B';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
  }

  
  static getCacheSizeStr(): string {
    let totalSize = 0;
    try {
      if (PreferenceManager.contextDir) {
        let files = fs.listFileSync(PreferenceManager.contextDir);
        for (let i = 0; i < files.length; i++) {
          if (files[i].startsWith('cache_')) {
            try {
              let stat = fs.statSync(PreferenceManager.contextDir + '/' + files[i]);
              totalSize += stat.size;
            } catch (e) {}
          }
        }
      }
    } catch (e) {}
    return PreferenceManager.formatSize(totalSize);
  }

  
  static getCacheStats(): CacheStatsData {
    let stats = new CacheStatsData();
    try {
      if (!PreferenceManager.contextDir) return stats;
      let files = fs.listFileSync(PreferenceManager.contextDir);
      let totalSize = 0;
      let articleCount = 0;
      let fileCount = 0;

      for (let i = 0; i < files.length; i++) {
        let fileName = files[i];
        if (fileName.startsWith('cache_')) {
          fileCount++;
          if (fileName.startsWith('cache_article_')) {
            articleCount++;
          }
          try {
            let stat = fs.statSync(PreferenceManager.contextDir + '/' + fileName);
            totalSize += stat.size;
          } catch (e) {}
        }
      }

      stats.totalFiles = fileCount;
      stats.articleCount = articleCount;
      stats.totalSizeBytes = totalSize;
      stats.totalSizeStr = PreferenceManager.formatSize(totalSize);
    } catch (e) {}
    return stats;
  }

  
  static getCacheTotalSizeBytes(): number {
    let totalSize = 0;
    try {
      if (PreferenceManager.contextDir) {
        let files = fs.listFileSync(PreferenceManager.contextDir);
        for (let i = 0; i < files.length; i++) {
          if (files[i].startsWith('cache_')) {
            try {
              let stat = fs.statSync(PreferenceManager.contextDir + '/' + files[i]);
              totalSize += stat.size;
            } catch (e) {}
          }
        }
      }
    } catch (e) {}
    return totalSize;
  }

  
  static evictOldestArticleCaches(targetSizeBytes: number) {
    try {
      if (!PreferenceManager.contextDir) return;
      let allFiles = fs.listFileSync(PreferenceManager.contextDir);

      
      let names: string[] = [];
      let sizes: number[] = [];
      let mtimes: number[] = [];
      let totalSize = 0;

      for (let i = 0; i < allFiles.length; i++) {
        if (allFiles[i].startsWith('cache_article_')) {
          try {
            let fullPath = PreferenceManager.contextDir + '/' + allFiles[i];
            let stat = fs.statSync(fullPath);
            names.push(allFiles[i]);
            sizes.push(stat.size);
            mtimes.push(stat.mtime);
            totalSize += stat.size;
          } catch (e) {}
        }
      }

      if (totalSize <= targetSizeBytes) return;

      
      for (let i = 0; i < names.length - 1; i++) {
        let minIdx = i;
        for (let j = i + 1; j < names.length; j++) {
          if (mtimes[j] < mtimes[minIdx]) minIdx = j;
        }
        if (minIdx !== i) {
          let tmpN = names[i]; names[i] = names[minIdx]; names[minIdx] = tmpN;
          let tmpS = sizes[i]; sizes[i] = sizes[minIdx]; sizes[minIdx] = tmpS;
          let tmpM = mtimes[i]; mtimes[i] = mtimes[minIdx]; mtimes[minIdx] = tmpM;
        }
      }

      
      let idx = 0;
      while (totalSize > targetSizeBytes && idx < names.length) {
        try {
          fs.unlinkSync(PreferenceManager.contextDir + '/' + names[idx]);
        } catch (e) {}
        totalSize -= sizes[idx];
        idx++;
      }
    } catch (e) {}
  }

  private static parseArticleAidFromCacheName(fileName: string): number {
    let prefix = 'cache_article_';
    if (!fileName.startsWith(prefix)) return 0;
    let end = fileName.indexOf('.json');
    if (end < 0) end = fileName.length;
    let idStr = fileName.substring(prefix.length, end);
    let aid = parseInt(idStr);
    if (isNaN(aid)) return 0;
    return aid;
  }

  private static extractHistoryAids(raw: string, maxCount: number): number[] {
    let aids: number[] = [];
    let pos = 0;
    while (aids.length < maxCount) {
      let keyPos = raw.indexOf('"aid"', pos);
      if (keyPos < 0) break;
      let colonPos = raw.indexOf(':', keyPos + 5);
      if (colonPos < 0) break;
      let start = colonPos + 1;
      while (start < raw.length && (raw.charAt(start) === ' ' || raw.charAt(start) === '"')) {
        start++;
      }
      let end = start;
      while (end < raw.length) {
        let c = raw.charAt(end);
        if (c < '0' || c > '9') break;
        end++;
      }
      if (end > start) {
        let aid = parseInt(raw.substring(start, end));
        if (!isNaN(aid) && aid > 0 && aids.indexOf(aid) < 0) {
          aids.push(aid);
        }
      }
      pos = end + 1;
    }
    return aids;
  }

  private static getProtectedAidsFromHistory(): number[] {
    try {
      if (!PreferenceManager.contextDir) return [];
      let path = PreferenceManager.contextDir + '/cache_history.json';
      let raw = fs.readTextSync(path);
      if (!raw || raw.length === 0) return [];
      return PreferenceManager.extractHistoryAids(raw, 30);
    } catch (e) {
      return [];
    }
  }

  private static getHabitEntry(aid: number): ReadingHabitEntry {
    let entry = new ReadingHabitEntry();
    if (!PreferenceManager.pref) return entry;
    try {
      let raw = PreferenceManager.pref.getSync('reading_habits_v1', '{}') as string;
      let parsed: Object = JSON.parse(raw);
      let obj = parsed as Record<string, Object>;
      let key = 'a' + aid;
      let rawEntry = obj[key] as Record<string, Object>;
      if (rawEntry) {
        if (rawEntry['visits'] !== undefined) entry.visits = rawEntry['visits'] as number;
        if (rawEntry['lastOpenAt'] !== undefined) entry.lastOpenAt = rawEntry['lastOpenAt'] as number;
      }
    } catch (e) {}
    return entry;
  }

  static recordArticleOpenHabit(aid: number) {
    if (aid <= 0 || !PreferenceManager.pref) return;
    try {
      let raw = PreferenceManager.pref.getSync('reading_habits_v1', '{}') as string;
      let parsed: Object = JSON.parse(raw);
      let obj = parsed as Record<string, Object>;
      let key = 'a' + aid;
      let entry = new ReadingHabitEntry();
      let rawEntry = obj[key] as Record<string, Object>;
      if (rawEntry) {
        if (rawEntry['visits'] !== undefined) entry.visits = rawEntry['visits'] as number;
        if (rawEntry['lastOpenAt'] !== undefined) entry.lastOpenAt = rawEntry['lastOpenAt'] as number;
      }
      let now = Date.now();
      if (now - entry.lastOpenAt < 10 * 60 * 1000) return;
      entry.visits = entry.visits + 1;
      entry.lastOpenAt = now;
      let savedEntry: Record<string, number> = {
        'visits': entry.visits,
        'lastOpenAt': entry.lastOpenAt
      };
      obj[key] = savedEntry;
      PreferenceManager.putString('reading_habits_v1', JSON.stringify(obj));
    } catch (e) {}
  }

  static evictSmartArticleCaches(targetSizeBytes: number) {
    try {
      if (!PreferenceManager.contextDir) return;
      let allFiles = fs.listFileSync(PreferenceManager.contextDir);
      let protectedAids = PreferenceManager.getProtectedAidsFromHistory();
      let candidates: SmartCacheCandidate[] = [];
      let totalSize = PreferenceManager.getCacheTotalSizeBytes();
      let now = Date.now();

      for (let i = 0; i < allFiles.length; i++) {
        if (allFiles[i].startsWith('cache_article_')) {
          try {
            let fullPath = PreferenceManager.contextDir + '/' + allFiles[i];
            let stat = fs.statSync(fullPath);
            let aid = PreferenceManager.parseArticleAidFromCacheName(allFiles[i]);
            let habit = PreferenceManager.getHabitEntry(aid);
            let ageHours = Math.max(1, (now - stat.mtime) / (60 * 60 * 1000));
            let c = new SmartCacheCandidate();
            c.name = allFiles[i];
            c.aid = aid;
            c.size = stat.size;
            c.mtime = stat.mtime;
            c.score = ageHours;
            if (protectedAids.indexOf(aid) >= 0) {
              c.protectedByHabit = true;
              c.score -= 100000;
            }
            if (habit.visits > 0) {
              c.protectedByHabit = true;
              c.score -= habit.visits * 3000;
              c.score -= Math.max(0, 72 - ((now - habit.lastOpenAt) / (60 * 60 * 1000))) * 100;
            }
            candidates.push(c);
          } catch (e) {}
        }
      }

      if (totalSize <= targetSizeBytes) return;

      for (let i = 0; i < candidates.length - 1; i++) {
        let maxIdx = i;
        for (let j = i + 1; j < candidates.length; j++) {
          let currentProtected = candidates[maxIdx].protectedByHabit;
          let nextProtected = candidates[j].protectedByHabit;
          if (currentProtected && !nextProtected) {
            maxIdx = j;
          } else if (currentProtected === nextProtected && candidates[j].score > candidates[maxIdx].score) {
            maxIdx = j;
          }
        }
        if (maxIdx !== i) {
          let tmp = candidates[i]; candidates[i] = candidates[maxIdx]; candidates[maxIdx] = tmp;
        }
      }

      let idx = 0;
      while (totalSize > targetSizeBytes && idx < candidates.length) {
        try {
          fs.unlinkSync(PreferenceManager.contextDir + '/' + candidates[idx].name);
        } catch (e) {}
        totalSize -= candidates[idx].size;
        idx++;
      }
    } catch (e) {}
  }

  
  static clearCache() {
    try {
      if (PreferenceManager.contextDir) {
        let files = fs.listFileSync(PreferenceManager.contextDir);
        for (let i = 0; i < files.length; i++) {
          if (files[i].startsWith('cache_')) {
            try {
              fs.unlinkSync(PreferenceManager.contextDir + '/' + files[i]);
            } catch (e) {}
          }
        }
      }
    } catch (e) {}

    if (PreferenceManager.pref) {
      try {
        PreferenceManager.pref.delete('time_home');
        PreferenceManager.pref.delete('time_history');
        PreferenceManager.pref.delete('time_collection');
        PreferenceManager.pref.flush();
      } catch (e) {}
    }
  }

  
  static clearArticleCache() {
    try {
      if (PreferenceManager.contextDir) {
        let files = fs.listFileSync(PreferenceManager.contextDir);
        for (let i = 0; i < files.length; i++) {
          if (files[i].startsWith('cache_article_')) {
            try {
              fs.unlinkSync(PreferenceManager.contextDir + '/' + files[i]);
            } catch (e) {}
          }
        }
      }
    } catch (e) {}
  }

  
  static async getBoolean(key: string, defValue: boolean): Promise<boolean> {
    let pref = await PreferenceManager.getSafePref();
    if (!pref) return defValue;
    try {
      let val = await pref.get(key, defValue);
      return val as boolean;
    } catch (e) { return defValue; }
  }

  static async getNumber(key: string, defValue: number): Promise<number> {
    let pref = await PreferenceManager.getSafePref();
    if (!pref) return defValue;
    try {
      let val = await pref.get(key, defValue);
      return val as number;
    } catch (e) { return defValue; }
  }

  
  static getNumberSync(key: string, defValue: number): number {
    if (!PreferenceManager.pref) return defValue;
    try {
      let val = PreferenceManager.pref.getSync(key, defValue);
      return val as number;
    } catch (e) { return defValue; }
  }

  
  static getBooleanSync(key: string, defValue: boolean): boolean {
    if (!PreferenceManager.pref) return defValue;
    try {
      let val = PreferenceManager.pref.getSync(key, defValue);
      return val as boolean;
    } catch (e) { return defValue; }
  }

  static async getString(key: string, defValue: string): Promise<string> {
    
    if (key.startsWith('cache_')) {
      try {
        let path = PreferenceManager.contextDir + '/' + key + '.json';
        let content = await fs.readText(path);
        
        if (content && content.length > 0) {
          return content;
        }
      } catch (e) { }
      return defValue;
    }

    let pref = await PreferenceManager.getSafePref();
    if (!pref) {
      console.error(`[致命警告] 尝试读取 ${key} 时首选项依然为 null`);
      return defValue;
    }
    try {
      let val = await pref.get(key, defValue);
      return val as string;
    } catch (e) { return defValue; }
  }

  

  
  private static scheduleDebouncedFlush() {
    PreferenceManager.hasPendingWrites = true;
    if (PreferenceManager.flushTimerId !== -1) return; 

    PreferenceManager.flushTimerId = setTimeout(async () => {
      PreferenceManager.flushTimerId = -1;
      PreferenceManager.hasPendingWrites = false;
      try {
        if (PreferenceManager.pref) {
          await PreferenceManager.pref.flush();
        }
      } catch (e) {}
    }, PreferenceManager.FLUSH_DEBOUNCE_MS);
  }

  
  static async forceFlush() {
    
    if (PreferenceManager.flushTimerId !== -1) {
      clearTimeout(PreferenceManager.flushTimerId);
      PreferenceManager.flushTimerId = -1;
    }
    PreferenceManager.hasPendingWrites = false;
    try {
      if (PreferenceManager.pref) {
        await PreferenceManager.pref.flush();
      }
    } catch (e) {}
  }

  

  
  static async putBoolean(key: string, value: boolean) {
    let pref = await PreferenceManager.getSafePref();
    if (!pref) return;
    await pref.put(key, value);
    PreferenceManager.scheduleDebouncedFlush();
  }

  static async putNumber(key: string, value: number) {
    let pref = await PreferenceManager.getSafePref();
    if (!pref) return;
    await pref.put(key, value);
    PreferenceManager.scheduleDebouncedFlush();
  }

  
  static async putBooleanImmediate(key: string, value: boolean) {
    let pref = await PreferenceManager.getSafePref();
    if (!pref) return;
    await pref.put(key, value);
    await PreferenceManager.forceFlush();
  }

  static async putStringImmediate(key: string, value: string) {
    let pref = await PreferenceManager.getSafePref();
    if (!pref) {
      console.error(`[致命警告] 尝试保存 ${key} 时首选项依然为 null`);
      return;
    }
    await pref.put(key, value);
    await PreferenceManager.forceFlush();
  }

  static async putString(key: string, value: string) {
    
    if (key.startsWith('cache_')) {
      try {
        let path = PreferenceManager.contextDir + '/' + key + '.json';
        let tempPath = path + '.tmp';
        let file = await fs.open(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        await fs.write(file.fd, value);
        await fs.close(file);
        
        await fs.rename(tempPath, path);
      } catch (e) {
        
        try {
          let path = PreferenceManager.contextDir + '/' + key + '.json';
          let file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          fs.writeSync(file.fd, value);
          fs.closeSync(file);
        } catch (e2) { }
      }
      return;
    }

    let pref = await PreferenceManager.getSafePref();
    if (!pref) {
      console.error(`[致命警告] 尝试保存 ${key} 时首选项依然为 null`);
      return;
    }
    await pref.put(key, value);
    PreferenceManager.scheduleDebouncedFlush();
  }
}
