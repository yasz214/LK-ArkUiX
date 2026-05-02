

import { font } from '@kit.ArkUI';
import fs from '@ohos.file.fs';
import bridge from '@arkui-x.bridge';
import { FileLog } from './FileLog';
import { PreferenceManager } from './PreferenceManager';

const TAG = 'FontManager';


export interface FontEntry {
  familyName: string;
  source: string;       
  registered: boolean;
  error: string;
}


interface UserFontRecord {
  familyName: string;
  fileName: string;     
}


let fontBridgeObj: ESObject = null;
let fontBridgeChecked: boolean = false;
let fontBridgeAvailable: boolean = false;

function initFontBridge(): boolean {
  if (fontBridgeChecked) return fontBridgeAvailable;
  fontBridgeChecked = true;
  try {
    fontBridgeObj = bridge.createBridge('FontBridge');
    fontBridgeAvailable = true;
    FileLog.i(TAG, 'FontBridge 初始化成功');
  } catch (e) {
    let err = e as Error;
    FileLog.w(TAG, `FontBridge 不可用 (可能在HarmonyOS上): ${err.message}`);
    fontBridgeAvailable = false;
  }
  return fontBridgeAvailable;
}

export class FontManager {
  static readonly READING_FONT: string = 'ReadingFont';

  private static fontEntries: FontEntry[] = [];
  private static initialized: boolean = false;
  private static fontsDir: string = '';  

  static init() {
    if (FontManager.initialized) return;
    FontManager.initialized = true;
    FileLog.i(TAG, '字体管理器初始化完成');
  }

  
  static async initUserFonts(filesDir: string) {
    FontManager.fontsDir = filesDir + '/fonts';

    
    try {
      if (!fs.accessSync(FontManager.fontsDir)) {
        fs.mkdirSync(FontManager.fontsDir);
      }
    } catch (e) {
      try {
        fs.mkdirSync(FontManager.fontsDir);
      } catch (e2) {
        FileLog.e(TAG, `创建字体目录失败: ${(e2 as Error).message}`);
      }
    }

    FileLog.i(TAG, `字体目录: ${FontManager.fontsDir}`);

    
    let recordStr = await PreferenceManager.getString('user_fonts', '');
    if (recordStr) {
      try {
        let records: UserFontRecord[] = (JSON.parse(recordStr) as Object[]).map(obj => {
          let rec = obj as Record<string, string>;
          let r: UserFontRecord = { familyName: rec['familyName'], fileName: rec['fileName'] };
          return r;
        });
        FileLog.i(TAG, `找到 ${records.length} 条用户字体记录`);
        for (let rec of records) {
          let fontPath = `${FontManager.fontsDir}/${rec.fileName}`;
          try {
            if (fs.accessSync(fontPath)) {
              FontManager.registerFontFromPath(rec.familyName, fontPath);
            } else {
              FileLog.w(TAG, `用户字体文件不存在: ${fontPath}`);
            }
          } catch (e) {
            FileLog.w(TAG, `检查用户字体文件失败: ${rec.fileName}`);
          }
        }
      } catch (e) {
        FileLog.e(TAG, `解析用户字体记录失败: ${(e as Error).message}`);
      }
    }

    
    
    
    
    let currentFont = AppStorage.get<string>('custom_reading_font') || '';
    if (currentFont !== '' && FontManager.isFontRegistered(currentFont)) {
      FileLog.i(TAG, `字体 "${currentFont}" 已注册，强制触发 UI 刷新`);
      
      AppStorage.setOrCreate('custom_reading_font', '');
      AppStorage.setOrCreate('custom_reading_font', currentFont);
    } else if (currentFont !== '') {
      FileLog.w(TAG, `字体偏好 "${currentFont}" 未能注册成功`);
    }
  }

  
  static registerFontFromPath(familyName: string, fontPath: string): boolean {
    FileLog.i(TAG, `注册字体: familyName=${familyName}, path=${fontPath}`);

    if (FontManager.isFontRegistered(familyName)) {
      FileLog.i(TAG, `字体已注册，跳过: ${familyName}`);
      return true;
    }

    
    try {
      if (!fs.accessSync(fontPath)) {
        FileLog.e(TAG, `字体文件不存在: ${fontPath}`);
        return false;
      }
      let stat = fs.statSync(fontPath);
      FileLog.i(TAG, `字体文件确认存在: ${fontPath}, 大小=${stat.size} bytes`);
    } catch (e) {
      FileLog.e(TAG, `检查字体文件失败: ${fontPath}, ${(e as Error).message}`);
    }

    let entry: FontEntry = {
      familyName: familyName,
      source: 'user',
      registered: false,
      error: ''
    };

    
    
    
    
    let pathsToTry: string[] = [];

    
    if (!fontPath.startsWith('file://')) {
      pathsToTry.push(`file://${fontPath}`);
      pathsToTry.push(fontPath);
    } else {
      pathsToTry.push(fontPath);
      pathsToTry.push(fontPath.replace('file://', ''));
    }

    for (let tryPath of pathsToTry) {
      try {
        FileLog.i(TAG, `尝试 font.registerFont: familyName=${familyName}, familySrc=${tryPath}`);
        font.registerFont({
          familyName: familyName,
          familySrc: tryPath
        });
        FileLog.i(TAG, `font.registerFont 调用完成 (无异常): ${tryPath}`);
        entry.registered = true;
        
        break;
      } catch (e) {
        let err = e as Error;
        FileLog.w(TAG, `font.registerFont 失败 (${tryPath}): ${err.message}`);
        if (!entry.registered) {
          entry.error = err.message || '未知错误';
        }
      }
    }

    if (entry.registered) {
      FileLog.i(TAG, `字体注册完成: ${familyName}`);
    } else {
      FileLog.e(TAG, `字体注册最终失败: ${familyName}, 所有方法均失败`);
    }

    FontManager.fontEntries.push(entry);
    return entry.registered;
  }

  
  static async queryFontFileName(contentUri: string): Promise<string> {
    if (!contentUri.startsWith('content://')) return '';
    if (!initFontBridge() || !fontBridgeObj) return '';

    try {
      let message = `queryName||${contentUri}`;
      let result: ESObject = await fontBridgeObj.sendMessage(message);
      let resultStr = String(result);
      FileLog.i(TAG, `queryFontFileName 结果: ${resultStr}`);
      if (resultStr.startsWith('name:')) {
        return resultStr.substring(5); 
      }
    } catch (e) {
      FileLog.w(TAG, `queryFontFileName 异常: ${(e as Error).message}`);
    }
    return '';
  }

  
  static async importUserFont(srcPath: string, fileName: string): Promise<string> {
    
    let familyName = fileName.replace(/\.(ttf|otf)$/i, '');

    
    let destPath = `${FontManager.fontsDir}/${fileName}`;

    
    try {
      if (fs.accessSync(destPath)) {
        fs.unlinkSync(destPath);
      }
    } catch (e) {  }

    
    if (srcPath.startsWith('content://')) {
      FileLog.i(TAG, `检测到 content:// URI，尝试通过 FontBridge 复制`);
      if (initFontBridge() && fontBridgeObj) {
        try {
          let message = `${srcPath}||${destPath}`;
          let result: ESObject = await fontBridgeObj.sendMessage(message);
          let resultStr = String(result);
          FileLog.i(TAG, `FontBridge 返回: ${resultStr}`);
          if (resultStr !== 'ok') {
            throw new Error(`Bridge复制失败: ${resultStr}`);
          }
        } catch (e) {
          let err = e as Error;
          FileLog.e(TAG, `FontBridge 调用失败: ${err.message}`);
          throw err;
        }
      } else {
        
        FileLog.e(TAG, 'FontBridge 不可用，无法复制 content:// URI');
        throw new Error('字体导入功能在此平台上不可用');
      }
    } else {
      
      
      
      try {
        FileLog.i(TAG, `HarmonyOS 字体复制: srcPath=${srcPath}`);
        let srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
        FileLog.i(TAG, `源文件已打开: fd=${srcFile.fd}`);
        let destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        FileLog.i(TAG, `目标文件已打开: fd=${destFile.fd}`);

        
        let buf = new ArrayBuffer(65536); 
        let totalWritten = 0;
        let readLen = fs.readSync(srcFile.fd, buf);
        while (readLen > 0) {
          
          fs.writeSync(destFile.fd, buf, { offset: totalWritten, length: readLen });
          totalWritten += readLen;
          readLen = fs.readSync(srcFile.fd, buf);
        }

        fs.closeSync(srcFile);
        fs.closeSync(destFile);

        
        let destStat = fs.statSync(destPath);
        FileLog.i(TAG, `字体文件复制完成: ${destPath}, 写入=${totalWritten} bytes, 文件大小=${destStat.size} bytes`);
        if (destStat.size === 0) {
          FileLog.e(TAG, `⚠️ 目标文件大小为 0！复制失败`);
          throw new Error('字体文件复制后大小为 0');
        }
      } catch (e) {
        let err = e as Error;
        FileLog.e(TAG, `复制字体文件失败: ${err.message}`);
        throw err;
      }
    }

    
    FontManager.registerFontFromPath(familyName, destPath);

    
    await FontManager.saveUserFontRecord(familyName, fileName);

    return familyName;
  }

  
  static async removeUserFont(familyName: string) {
    
    FontManager.fontEntries = FontManager.fontEntries.filter(e => e.familyName !== familyName);

    
    let recordStr = await PreferenceManager.getString('user_fonts', '');
    if (recordStr) {
      try {
        let records: UserFontRecord[] = (JSON.parse(recordStr) as Object[]).map(obj => {
          let rec = obj as Record<string, string>;
          let r: UserFontRecord = { familyName: rec['familyName'], fileName: rec['fileName'] };
          return r;
        });

        let toDelete = records.find(r => r.familyName === familyName);
        if (toDelete) {
          let filePath = `${FontManager.fontsDir}/${toDelete.fileName}`;
          try { fs.unlinkSync(filePath); } catch (e) {  }
        }

        let remaining = records.filter(r => r.familyName !== familyName);
        await PreferenceManager.putString('user_fonts', JSON.stringify(remaining));
      } catch (e) {
        FileLog.e(TAG, `删除字体记录失败: ${(e as Error).message}`);
      }
    }

    
    let currentFont = AppStorage.get<string>('custom_reading_font') || '';
    if (currentFont === familyName) {
      AppStorage.setOrCreate('custom_reading_font', '');
      await PreferenceManager.putString('custom_reading_font', '');
    }

    FileLog.i(TAG, `字体已删除: ${familyName}`);
  }

  private static async saveUserFontRecord(familyName: string, fileName: string) {
    let recordStr = await PreferenceManager.getString('user_fonts', '');
    let records: UserFontRecord[] = [];
    if (recordStr) {
      try {
        records = (JSON.parse(recordStr) as Object[]).map(obj => {
          let rec = obj as Record<string, string>;
          let r: UserFontRecord = { familyName: rec['familyName'], fileName: rec['fileName'] };
          return r;
        });
      } catch (e) {  }
    }

    
    records = records.filter(r => r.familyName !== familyName);
    let newRecord: UserFontRecord = { familyName: familyName, fileName: fileName };
    records.push(newRecord);

    await PreferenceManager.putString('user_fonts', JSON.stringify(records));
    FileLog.i(TAG, `字体记录已保存: ${familyName}`);
  }

  static getRegisteredFonts(): FontEntry[] {
    return FontManager.fontEntries;
  }

  
  static getAvailableFontNames(): string[] {
    let names: string[] = [];
    for (let e of FontManager.fontEntries) {
      if (e.registered) {
        names.push(e.familyName);
      }
    }
    return names;
  }

  static isFontRegistered(familyName: string): boolean {
    for (let i = 0; i < FontManager.fontEntries.length; i++) {
      if (FontManager.fontEntries[i].familyName === familyName && FontManager.fontEntries[i].registered) {
        return true;
      }
    }
    return false;
  }

  static getReadingFontFamily(): string {
    let customFont = AppStorage.get<string>('custom_reading_font');
    if (customFont && customFont !== '' && FontManager.isFontRegistered(customFont)) {
      return customFont;
    }
    return '';
  }

  static getSystemFontList(): string[] {
    try {
      return font.getSystemFontList();
    } catch (e) {
      FileLog.w(TAG, `获取系统字体列表失败: ${(e as Error).message}`);
      return [];
    }
  }
}
