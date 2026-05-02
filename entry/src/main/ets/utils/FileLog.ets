import fs from '@ohos.file.fs';
import { PreferenceManager } from './PreferenceManager';


export class FileLog {
  private static logPath: string = '';
  private static initialized: boolean = false;
  private static enabled: boolean = false;

  
  private static ringBuffer: string[] = [];
  private static readonly MAX_BUFFER_SIZE: number = 200;
  private static readonly FLUSH_INTERVAL_MS: number = 1500;
  private static flushTimerId: number = -1;
  private static isFlushing: boolean = false;

  
  private static earlyBuffer: string[] = [];

  static setEnabled(on: boolean) {
    FileLog.enabled = on;
  }

  static isEnabled(): boolean {
    return FileLog.enabled;
  }

  static init() {
    let dir = PreferenceManager.contextDir;
    if (dir && dir !== '') {
      FileLog.logPath = dir + '/debug_log.txt';
      FileLog.initialized = true;

      
      if (FileLog.earlyBuffer.length > 0) {
        for (let i = 0; i < FileLog.earlyBuffer.length; i++) {
          FileLog.ringBuffer.push(FileLog.earlyBuffer[i]);
        }
        FileLog.earlyBuffer = [];
        FileLog.scheduleFlush();
      }
    }
  }

  private static getTimestamp(): string {
    let d = new Date();
    let h = d.getHours().toString().padStart(2, '0');
    let m = d.getMinutes().toString().padStart(2, '0');
    let s = d.getSeconds().toString().padStart(2, '0');
    let ms = d.getMilliseconds().toString().padStart(3, '0');
    return `${h}:${m}:${s}.${ms}`;
  }

  
  private static async flushToFile() {
    if (FileLog.isFlushing || FileLog.ringBuffer.length === 0) return;
    FileLog.isFlushing = true;

    
    let batch = FileLog.ringBuffer.join('');
    FileLog.ringBuffer = [];

    try {
      let file = await fs.open(FileLog.logPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
      await fs.write(file.fd, batch);
      await fs.close(file);
    } catch (e) {
      
    } finally {
      FileLog.isFlushing = false;
    }
  }

  
  private static scheduleFlush() {
    if (FileLog.flushTimerId !== -1) return; 
    FileLog.flushTimerId = setTimeout(() => {
      FileLog.flushTimerId = -1;
      FileLog.flushToFile();
      
      if (FileLog.ringBuffer.length > 0) {
        FileLog.scheduleFlush();
      }
    }, FileLog.FLUSH_INTERVAL_MS);
  }

  private static write(level: string, tag: string, msg: string) {
    if (!FileLog.enabled) return;

    let line = `[${FileLog.getTimestamp()}] [${level}] [${tag}] ${msg}\n`;

    if (!FileLog.initialized) {
      FileLog.earlyBuffer.push(line);
      FileLog.init();
      return;
    }

    FileLog.ringBuffer.push(line);

    
    if (level === 'ERROR') {
      FileLog.flushToFile();
      return;
    }

    
    if (FileLog.ringBuffer.length >= FileLog.MAX_BUFFER_SIZE) {
      FileLog.flushToFile();
      return;
    }

    
    FileLog.scheduleFlush();
  }

  static i(tag: string, msg: string) {
    FileLog.write('INFO', tag, msg);
  }

  static e(tag: string, msg: string) {
    FileLog.write('ERROR', tag, msg);
  }

  static w(tag: string, msg: string) {
    FileLog.write('WARN', tag, msg);
  }

  
  static forceFlush() {
    if (FileLog.ringBuffer.length > 0) {
      FileLog.flushToFile();
    }
  }

  
  static clear() {
    if (!FileLog.initialized) return;
    try {
      let file = fs.openSync(FileLog.logPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, `=== 日志已清空 ${new Date().toLocaleString()} ===\n`);
      fs.closeSync(file);
    } catch (e) {}
  }

  
  static readAll(): string {
    if (!FileLog.initialized) return '(日志系统未初始化)';
    
    if (FileLog.ringBuffer.length > 0) {
      
      try {
        let remaining = FileLog.ringBuffer.join('');
        FileLog.ringBuffer = [];
        let file = fs.openSync(FileLog.logPath,
          fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
        fs.writeSync(file.fd, remaining);
        fs.closeSync(file);
      } catch (e) {}
    }
    try {
      if (fs.accessSync(FileLog.logPath)) {
        return fs.readTextSync(FileLog.logPath);
      }
    } catch (e) {}
    return '(无日志)';
  }

  
  static getPath(): string {
    return FileLog.logPath;
  }
}
