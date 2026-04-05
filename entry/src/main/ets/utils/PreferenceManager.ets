import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';


export class CacheStatsData {
  totalFiles: number = 0;
  articleCount: number = 0;
  totalSizeBytes: number = 0;
  totalSizeStr: string = '0 B';
}

export class PreferenceManager {
  private static pref: dataPreferences.Preferences | null = null;
  private static readonly PREF_NAME = 'lightnovel_settings';
  public static contextDir: string = '';

  private static initPromise: Promise<void> | null = null;

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

  
  static async putBoolean(key: string, value: boolean) {
    let pref = await PreferenceManager.getSafePref();
    if (!pref) return;
    await pref.put(key, value);
    await pref.flush();
  }

  static async putNumber(key: string, value: number) {
    let pref = await PreferenceManager.getSafePref();
    if (!pref) return;
    await pref.put(key, value);
    await pref.flush();
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
    await pref.flush();
  }
}
