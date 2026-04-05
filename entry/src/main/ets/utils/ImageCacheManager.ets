import axios, { AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { FileLog } from './FileLog';



const TAG = 'ImageCacheManager';


const MAX_CACHE_COUNT = 200;


let cacheIndex: Map<string, string> = new Map();

let lruTimestamps: Map<string, number> = new Map();

let lruReverse: Map<number, string> = new Map();

let lruClock: number = 0;

let lruOldest: number = 0;

let downloadingPromises: Map<string, Promise<string>> = new Map();

let tempDir: string = '';

export class ImageCacheManager {
  
  static init(context: common.UIAbilityContext) {
    tempDir = context.tempDir;
    FileLog.i(TAG, `初始化完成, tempDir=${tempDir}`);
  }

  
  static preCacheImage(imageUrl: string) {
    if (!tempDir || !imageUrl) return;
    if (cacheIndex.has(imageUrl)) {
      
      ImageCacheManager.touchLru(imageUrl);
      return;
    }
    if (downloadingPromises.has(imageUrl)) return;

    let promise = ImageCacheManager.downloadToTemp(imageUrl).then((filePath: string) => {
      if (filePath) {
        cacheIndex.set(imageUrl, filePath);
        ImageCacheManager.touchLru(imageUrl);
        ImageCacheManager.evictIfNeeded();
        FileLog.i(TAG, `缓存成功: ${imageUrl.substring(imageUrl.length - 40)}`);
      }
      downloadingPromises.delete(imageUrl);
      return filePath;
    }).catch((): string => {
      downloadingPromises.delete(imageUrl);
      return '';
    });

    downloadingPromises.set(imageUrl, promise);
  }

  
  static getCachedBufferSync(imageUrl: string): ArrayBuffer | null {
    let filePath = cacheIndex.get(imageUrl);
    if (!filePath) return null;

    ImageCacheManager.touchLru(imageUrl);
    try {
      let stat = fs.statSync(filePath);
      if (stat.size === 0) {
        cacheIndex.delete(imageUrl);
        ImageCacheManager.removeLru(imageUrl);
        return null;
      }
      let file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      return buf;
    } catch (e) {
      FileLog.w(TAG, `读取缓存失败(sync): ${(e as Error).message}`);
      cacheIndex.delete(imageUrl);
      ImageCacheManager.removeLru(imageUrl);
      return null;
    }
  }

  
  static async getCachedBufferAsync(imageUrl: string): Promise<ArrayBuffer | null> {
    let filePath = cacheIndex.get(imageUrl);
    if (!filePath) return null;

    ImageCacheManager.touchLru(imageUrl);
    try {
      let stat = await fs.stat(filePath);
      if (stat.size === 0) {
        cacheIndex.delete(imageUrl);
        ImageCacheManager.removeLru(imageUrl);
        return null;
      }
      let file = await fs.open(filePath, fs.OpenMode.READ_ONLY);
      let buf = new ArrayBuffer(stat.size);
      await fs.read(file.fd, buf);
      await fs.close(file);
      return buf;
    } catch (e) {
      FileLog.w(TAG, `读取缓存失败(async): ${(e as Error).message}`);
      cacheIndex.delete(imageUrl);
      ImageCacheManager.removeLru(imageUrl);
      return null;
    }
  }

  
  static getCachedBuffer(imageUrl: string): ArrayBuffer | null {
    return ImageCacheManager.getCachedBufferSync(imageUrl);
  }

  
  static isCached(imageUrl: string): boolean {
    return cacheIndex.has(imageUrl);
  }

  
  static async waitAndGetBuffer(imageUrl: string): Promise<ArrayBuffer | null> {
    
    if (cacheIndex.has(imageUrl)) {
      return ImageCacheManager.getCachedBufferAsync(imageUrl);
    }

    
    let pending = downloadingPromises.get(imageUrl);
    if (pending) {
      FileLog.i(TAG, `等待下载完成: ${imageUrl.substring(imageUrl.length - 40)}`);
      await pending;
      return ImageCacheManager.getCachedBufferAsync(imageUrl);
    }

    
    FileLog.i(TAG, `主动触发缓存下载: ${imageUrl.substring(imageUrl.length - 40)}`);
    ImageCacheManager.preCacheImage(imageUrl);
    let newPending = downloadingPromises.get(imageUrl);
    if (newPending) {
      await newPending;
      return ImageCacheManager.getCachedBufferAsync(imageUrl);
    }

    return null;
  }

  
  static clearAll() {
    cacheIndex.forEach((filePath: string) => {
      try { fs.unlinkSync(filePath); } catch (_e) {}
    });
    cacheIndex.clear();
    lruTimestamps.clear();
    lruReverse.clear();
    lruClock = 0;
    lruOldest = 0;
    FileLog.i(TAG, '缓存已清空');
  }

  
  private static async downloadToTemp(imageUrl: string): Promise<string> {
    try {
      let config: AxiosRequestConfig<null> = {
        url: imageUrl,
        method: 'get',
        responseType: 'array_buffer',
        timeout: 30000
      };

      let res: AxiosResponse<ArrayBuffer> = await axios.request<ArrayBuffer, AxiosResponse<ArrayBuffer>, null>(config);
      let buffer: ArrayBuffer = res.data;

      if (buffer.byteLength === 0) return '';

      
      let hash = ImageCacheManager.betterHash(imageUrl);
      let ext = '.jpg';
      let urlLower = imageUrl.toLowerCase();
      if (urlLower.indexOf('.png') !== -1) ext = '.png';
      else if (urlLower.indexOf('.webp') !== -1) ext = '.webp';
      else if (urlLower.indexOf('.gif') !== -1) ext = '.gif';

      let filePath = `${tempDir}/imgcache_${hash}${ext}`;

      let file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, buffer);
      fs.closeSync(file);

      return filePath;
    } catch (e) {
      FileLog.w(TAG, `下载失败: ${(e as Error).message}`);
      return '';
    }
  }

  
  private static betterHash(str: string): string {
    let h1 = 0x811c9dc5; 
    let h2 = 0;
    for (let i = 0; i < str.length; i++) {
      let c = str.charCodeAt(i);
      h1 = (h1 ^ c) * 0x01000193; 
      h1 = h1 & 0x7FFFFFFF;
      h2 = ((h2 << 5) - h2 + c) & 0x7FFFFFFF;
    }
    return h1.toString(36) + '_' + h2.toString(36) + '_' + str.length.toString(36);
  }

  

  
  private static touchLru(url: string) {
    
    let oldTs = lruTimestamps.get(url);
    if (oldTs !== undefined) {
      lruReverse.delete(oldTs);
    }
    
    lruClock++;
    lruTimestamps.set(url, lruClock);
    lruReverse.set(lruClock, url);
  }

  
  private static removeLru(url: string) {
    let ts = lruTimestamps.get(url);
    if (ts !== undefined) {
      lruReverse.delete(ts);
      lruTimestamps.delete(url);
    }
  }

  
  private static evictIfNeeded() {
    while (cacheIndex.size > MAX_CACHE_COUNT) {
      
      while (lruOldest <= lruClock && !lruReverse.has(lruOldest)) {
        lruOldest++;
      }
      if (lruOldest > lruClock) break; 

      let oldestUrl = lruReverse.get(lruOldest);
      if (oldestUrl) {
        let oldPath = cacheIndex.get(oldestUrl);
        cacheIndex.delete(oldestUrl);
        lruTimestamps.delete(oldestUrl);
        lruReverse.delete(lruOldest);
        if (oldPath) {
          try { fs.unlinkSync(oldPath); } catch (_e) {}
        }
        FileLog.i(TAG, `LRU淘汰: ${oldestUrl.substring(oldestUrl.length - 40)}`);
      }
      lruOldest++;
    }
  }
}
