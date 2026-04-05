import common from '@ohos.app.ability.common';
import util from '@ohos.util';
import { ContentItem, RichSpan } from '../models/DataModels';
import { FileLog } from './FileLog';
import { promptAction } from '@kit.ArkUI';


import * as t2sNative from 'libt2s.so';

interface IT2SNative {
  initEngine(keys: string[], values: string[]): boolean;
  convertText(text: string): string;
  convertBatch(texts: string[]): string[];
}

let nativeT2S: IT2SNative | null = null;

let nativeLoadMethod: string = 'none';


let hasShownT2SFallbackToast: boolean = false;

function resolveNativeModule(): IT2SNative | null {
  if (nativeT2S) return nativeT2S;

  
  try {
    let modRec = t2sNative as Object as Record<string, Object>;
    let hasInit = typeof modRec['initEngine'] === 'function';
    let hasConvert = typeof modRec['convertText'] === 'function';
    let hasBatch = typeof modRec['convertBatch'] === 'function';
    FileLog.i('T2SEngine', `[resolveNative] Method A 检测: initEngine=${hasInit}, convertText=${hasConvert}, convertBatch=${hasBatch}`);
    if (hasInit && hasConvert) {
      nativeT2S = t2sNative as Object as IT2SNative;
      nativeLoadMethod = 'A(static import)';
      FileLog.i('T2SEngine', `[resolveNative]  通过 Method A 加载成功, convertBatch=${hasBatch}`);
      return nativeT2S;
    }
  } catch (e) {
    FileLog.w('T2SEngine', `[resolveNative] Method A 异常: ${(e as Error).message}`);
  }

  
  
  
  try {
    let g = globalThis as Object as Record<string, Object>;
    let reqFn = g['requireNapi'];
    if (typeof reqFn === 'function') {
      let requireNapiFn = reqFn as (name: string) => Object;
      let mod = requireNapiFn('t2s');
      if (mod) {
        let modRec = mod as Object as Record<string, Object>;
        let hasInit = typeof modRec['initEngine'] === 'function';
        let hasConvert = typeof modRec['convertText'] === 'function';
        let hasBatch = typeof modRec['convertBatch'] === 'function';
        FileLog.i('T2SEngine', `[resolveNative] Method B 检测: initEngine=${hasInit}, convertText=${hasConvert}, convertBatch=${hasBatch}`);
        if (hasInit) {
          nativeT2S = mod as Object as IT2SNative;
          nativeLoadMethod = 'B(requireNapi)';
          FileLog.i('T2SEngine', `[resolveNative]  通过 Method B 加载成功, convertBatch=${hasBatch}`);
          return nativeT2S;
        }
      } else {
        FileLog.w('T2SEngine', `[resolveNative] Method B: requireNapi('t2s') 返回 null`);
      }
    } else {
      FileLog.i('T2SEngine', `[resolveNative] Method B: requireNapi 不可用 (typeof=${typeof reqFn})`);
    }
  } catch (e) {
    FileLog.w('T2SEngine', `[resolveNative] Method B 异常: ${(e as Error).message}`);
  }

  FileLog.e('T2SEngine', '[resolveNative]  所有方法均失败，C++ 引擎不可用');
  return null;
}

export class T2SEngine {
  private static readonly FILE_NAME: string = 't2s.json';
  private static isInitialized: boolean = false;

  
  private static arktsDict: Map<string, string> | null = null;
  private static arktsInitialized: boolean = false;

  static init(context: common.UIAbilityContext) {
    if (T2SEngine.isInitialized && T2SEngine.arktsInitialized) return;

    try {
      let rawData = context.resourceManager.getRawFileContentSync(T2SEngine.FILE_NAME);
      let textDecoder = util.TextDecoder.create('utf-8');
      let content = textDecoder.decodeWithStream(rawData);
      let jsonObj: Record<string, string> = JSON.parse(content);

      let keys = Object.keys(jsonObj);
      let values = Object.values(jsonObj);

      
      if (!T2SEngine.arktsInitialized) {
        T2SEngine.arktsDict = new Map<string, string>();
        for (let i = 0; i < keys.length; i++) {
          T2SEngine.arktsDict.set(keys[i], values[i]);
        }
        T2SEngine.arktsInitialized = true;
        FileLog.i('T2SEngine', `ArkTS 字典初始化完成: ${keys.length} 条映射`);
      }

      
      if (!T2SEngine.isInitialized) {
        let mod = resolveNativeModule();
        if (mod) {
          let initResult = mod.initEngine(keys, values);
          T2SEngine.isInitialized = true;
          FileLog.i('T2SEngine', `C++ 引擎初始化完成: ${keys.length} 条映射, 方法=${nativeLoadMethod}, initResult=${initResult}`);

          
          try {
            let testSingle = mod.convertText('測試');
            FileLog.i('T2SEngine', `C++ convertText 验证: '測試' → '${testSingle}'`);
          } catch (e) {
            FileLog.e('T2SEngine', `C++ convertText 验证失败: ${(e as Error).message}`);
          }
          try {
            let testBatch = mod.convertBatch(['測試', '簡體']);
            FileLog.i('T2SEngine', `C++ convertBatch 验证: ['測試','簡體'] → ['${testBatch[0]}','${testBatch[1]}'], 返回长度=${testBatch.length}`);
          } catch (e) {
            FileLog.e('T2SEngine', `C++ convertBatch 验证失败! ${(e as Error).message}`);
            FileLog.e('T2SEngine', `convertBatch 不可用，标记 C++ 引擎为不可用，将回退到 ArkTS`);
            
            T2SEngine.isInitialized = false;
            nativeT2S = null;
            try { promptAction.openToast({ message: '繁简转换：C++ convertBatch 不可用，已回退 ArkTS' }); } catch (_e) {}
            hasShownT2SFallbackToast = true;
          }
        } else {
          FileLog.w('T2SEngine', 'C++ 模块加载失败，仅使用 ArkTS 字典');
        }
      }
    } catch (e) {
      FileLog.e('T2SEngine', `初始化异常: ${(e as Error).message}`);
    }
  }

  private static convertByArkTS(text: string): string {
    if (!T2SEngine.arktsDict || T2SEngine.arktsDict.size === 0) return text;
    let result = '';
    for (let i = 0; i < text.length; i++) {
      let ch = text[i];
      let mapped = T2SEngine.arktsDict.get(ch);
      if (mapped !== undefined) {
        result += mapped;
      } else {
        result += ch;
      }
    }
    return result;
  }

  static convert(text: string): string {
    if (!text) return text;

    let useNative = AppStorage.get<boolean>('useNativeT2S');
    if (useNative === false) {
      if (T2SEngine.arktsInitialized && T2SEngine.arktsDict) {
        return T2SEngine.convertByArkTS(text);
      }
      return text;
    }

    if (!T2SEngine.isInitialized || !nativeT2S) {
      if (T2SEngine.arktsInitialized && T2SEngine.arktsDict) {
        return T2SEngine.convertByArkTS(text);
      }
      return text;
    }
    return nativeT2S.convertText(text);
  }

  static async convertItemsAsync(items: ContentItem[]): Promise<ContentItem[]> {
    let useNative = AppStorage.get<boolean>('useNativeT2S');
    FileLog.i('T2SEngine', `convertItemsAsync: items=${items.length}, useNative=${useNative}, nativeT2S=${nativeT2S !== null}, loadMethod=${nativeLoadMethod}, arktsInit=${T2SEngine.arktsInitialized}`);

    if (useNative === false) {
      if (T2SEngine.arktsInitialized && T2SEngine.arktsDict) {
        FileLog.i('T2SEngine', 'convertItemsAsync: 用户选择 ArkTS 字典');
        return T2SEngine.convertItemsAsyncByArkTS(items);
      }
      return items;
    }

    if (!nativeT2S) {
      if (T2SEngine.arktsInitialized && T2SEngine.arktsDict) {
        FileLog.i('T2SEngine', 'convertItemsAsync: C++ 不可用, 回退 ArkTS');
        if (!hasShownT2SFallbackToast) {
          hasShownT2SFallbackToast = true;
          try { promptAction.openToast({ message: '繁简转换：C++ 不可用，已回退 ArkTS' }); } catch (_e) {}
        }
        return T2SEngine.convertItemsAsyncByArkTS(items);
      }
      return items;
    }

    try {
      let textsToConvert: string[] = [];
      let mapping: Array<[number, number]> = [];

      for (let i = 0; i < items.length; i++) {
        let item = items[i];
        if (item.type === 'text') {
          textsToConvert.push(item.value);
          mapping.push([i, -1]);
          if (item.spans) {
            for (let j = 0; j < item.spans.length; j++) {
              textsToConvert.push(item.spans[j].text);
              mapping.push([i, j]);
            }
          }
        }
      }

      if (textsToConvert.length === 0) return items;

      FileLog.i('T2SEngine', `convertItemsAsync: 收集了 ${textsToConvert.length} 条文本, 开始一次性 C++ 转换`);

      
      let converted = nativeT2S.convertBatch(textsToConvert);
      FileLog.i('T2SEngine', `C++ 转换完成, 输入=${textsToConvert.length}, 输出=${converted.length}`);

      let result: ContentItem[] = items.map((item) => {
        let newItem = new ContentItem();
        newItem.type = item.type;
        newItem.url = item.url;
        newItem.value = item.value;
        newItem.spans = item.spans ? item.spans.slice() : [];
        return newItem;
      });

      for (let k = 0; k < mapping.length; k++) {
        let itemIdx = mapping[k][0];
        let spanIdx = mapping[k][1];
        let convertedText = converted[k];
        if (spanIdx === -1) {
          result[itemIdx].value = convertedText;
        } else {
          let origSpan = items[itemIdx].spans[spanIdx];
          let ns = new RichSpan();
          ns.text = convertedText;
          ns.bold = origSpan.bold;
          ns.italic = origSpan.italic;
          ns.underline = origSpan.underline;
          ns.lineThrough = origSpan.lineThrough;
          ns.color = origSpan.color;
          ns.fontSize = origSpan.fontSize;
          ns.linkUrl = origSpan.linkUrl;
          result[itemIdx].spans[spanIdx] = ns;
        }
      }

      return result;
    } catch (e) {
      let err = e as Error;
      FileLog.e('T2SEngine', `convertItemsAsync C++ 路径异常: ${err.message}`);
      FileLog.e('T2SEngine', `异常详情: ${JSON.stringify(e)}`);
      FileLog.e('T2SEngine', `加载方法=${nativeLoadMethod}, nativeT2S类型=${typeof nativeT2S}`);
      
      if (T2SEngine.arktsInitialized && T2SEngine.arktsDict) {
        FileLog.i('T2SEngine', 'C++ 异常后回退 ArkTS 字典');
        if (!hasShownT2SFallbackToast) {
          hasShownT2SFallbackToast = true;
          try { promptAction.openToast({ message: '繁简转换：C++ 异常，已回退 ArkTS' }); } catch (_e) {}
        }
        return T2SEngine.convertItemsAsyncByArkTS(items);
      }
      return items;
    }
  }

  private static convertItemsAsyncByArkTS(items: ContentItem[]): ContentItem[] {
    let result: ContentItem[] = items.map((item) => {
      let newItem = new ContentItem();
      newItem.type = item.type;
      newItem.url = item.url;

      if (item.type === 'text') {
        newItem.value = T2SEngine.convertByArkTS(item.value);
        newItem.spans = item.spans.map((span) => {
          let ns = new RichSpan();
          ns.text = T2SEngine.convertByArkTS(span.text);
          ns.bold = span.bold;
          ns.italic = span.italic;
          ns.underline = span.underline;
          ns.lineThrough = span.lineThrough;
          ns.color = span.color;
          ns.fontSize = span.fontSize;
          ns.linkUrl = span.linkUrl;
          return ns;
        });
      } else {
        newItem.value = item.value;
        newItem.spans = item.spans.slice();
      }
      return newItem;
    });
    return result;
  }
}
