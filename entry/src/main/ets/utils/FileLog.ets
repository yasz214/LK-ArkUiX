import fs from '@ohos.file.fs';
import { PreferenceManager } from './PreferenceManager';


export class FileLog {
  private static logPath: string = '';
  private static initialized: boolean = false;
  private static buffer: string[] = [];
  private static enabled: boolean = false; 

  
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

      
      if (FileLog.buffer.length > 0) {
        let buffered = FileLog.buffer.join('');
        FileLog.buffer = [];
        FileLog.appendToFile(buffered);
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

  private static appendToFile(text: string) {
    try {
      let file = fs.openSync(FileLog.logPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
      fs.writeSync(file.fd, text);
      fs.closeSync(file);
    } catch (e) {
      
    }
  }

  private static write(level: string, tag: string, msg: string) {
    
    if (!FileLog.enabled) return;

    let line = `[${FileLog.getTimestamp()}] [${level}] [${tag}] ${msg}\n`;

    if (!FileLog.initialized) {
      FileLog.buffer.push(line);
      
      FileLog.init();
      return;
    }

    FileLog.appendToFile(line);
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
