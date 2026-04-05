import { ContentItem, RichSpan } from '../models/DataModels';
import { ArticleParser } from './ArticleParser';
import { FileLog } from './FileLog';
import { promptAction } from '@kit.ArkUI';


import * as parserNative from 'libarticle_parser.so';

interface IParserNative {
  parseArticle(rawContent: string, fullJsonString: string): string;
  parseComment(content: string): string;
  adaptColor(hexColor: string, isDark: boolean): string;
  parseBBCode(text: string): string;
}

let nativeParser: IParserNative | null = null;


let hasShownParserFallbackToast: boolean = false;


function resolveNativeModule(): IParserNative | null {
  if (nativeParser) return nativeParser;

  
  try {
    let modRec = parserNative as Object as Record<string, Object>;
    let hasArticle = typeof modRec['parseArticle'] === 'function';
    let hasComment = typeof modRec['parseComment'] === 'function';
    let hasColor = typeof modRec['adaptColor'] === 'function';
    let hasBBCode = typeof modRec['parseBBCode'] === 'function';
    FileLog.i('NativeParser', `[resolveNative] Method 1 检测: parseArticle=${hasArticle}, parseComment=${hasComment}, adaptColor=${hasColor}, parseBBCode=${hasBBCode}`);
    if (hasArticle && hasComment) {
      nativeParser = parserNative as Object as IParserNative;
      FileLog.i('NativeParser', `[resolveNative]  通过 Method 1 加载成功`);
      return nativeParser;
    }
  } catch (e) {
    FileLog.w('NativeParser', `[resolveNative] Method 1 异常: ${(e as Error).message}`);
  }

  
  try {
    let g = globalThis as Object as Record<string, Object>;
    let reqFn = g['requireNapi'];
    if (typeof reqFn === 'function') {
      let requireNapiFn = reqFn as (name: string) => Object;
      let mod = requireNapiFn('article_parser');
      if (mod) {
        let modRec = mod as Object as Record<string, Object>;
        let hasArticle = typeof modRec['parseArticle'] === 'function';
        let hasComment = typeof modRec['parseComment'] === 'function';
        FileLog.i('NativeParser', `[resolveNative] Method 2 检测: parseArticle=${hasArticle}, parseComment=${hasComment}`);
        if (hasArticle) {
          nativeParser = mod as Object as IParserNative;
          FileLog.i('NativeParser', `[resolveNative]  通过 Method 2 加载成功`);
          return nativeParser;
        }
      } else {
        FileLog.w('NativeParser', `[resolveNative] Method 2: requireNapi('article_parser') 返回 null`);
      }
    } else {
      FileLog.i('NativeParser', `[resolveNative] Method 2: requireNapi 不可用`);
    }
  } catch (e) {
    FileLog.w('NativeParser', `[resolveNative] Method 2 异常: ${(e as Error).message}`);
  }

  FileLog.e('NativeParser', '[resolveNative]  所有方法均失败，C++ 解析器不可用');
  return null;
}


function deserializeContentItems(json: string): ContentItem[] {
  if (!json || json === '[]') return [];

  let rawArray: Object[] = JSON.parse(json) as Object[];
  let items: ContentItem[] = [];

  for (let rawItem of rawArray) {
    let rec = rawItem as Record<string, Object>;
    let item = new ContentItem();

    let typeStr = rec['type'] as string;
    if (typeStr === 'image') item.type = 'image';
    else if (typeStr === 'link') item.type = 'link';
    else item.type = 'text';

    item.value = (rec['value'] as string) || '';
    item.url = (rec['url'] as string) || '';

    
    let rawSpans = rec['spans'] as Object[];
    if (rawSpans && rawSpans.length > 0) {
      let spans: RichSpan[] = [];
      for (let rawSpan of rawSpans) {
        let sr = rawSpan as Record<string, Object>;
        let span = new RichSpan();
        span.text = (sr['text'] as string) || '';
        span.bold = (sr['bold'] as boolean) || false;
        span.italic = (sr['italic'] as boolean) || false;
        span.underline = (sr['underline'] as boolean) || false;
        span.lineThrough = (sr['lineThrough'] as boolean) || false;
        span.color = (sr['color'] as string) || '';
        span.fontSize = (sr['fontSize'] as number) || 0;
        span.linkUrl = (sr['linkUrl'] as string) || '';
        spans.push(span);
      }
      item.spans = spans;
    }

    items.push(item);
  }

  return items;
}


function deserializeRichSpans(json: string): RichSpan[] {
  if (!json || json === '[]') return [];

  let rawArray: Object[] = JSON.parse(json) as Object[];
  let spans: RichSpan[] = [];

  for (let rawSpan of rawArray) {
    let sr = rawSpan as Record<string, Object>;
    let span = new RichSpan();
    span.text = (sr['text'] as string) || '';
    span.bold = (sr['bold'] as boolean) || false;
    span.italic = (sr['italic'] as boolean) || false;
    span.underline = (sr['underline'] as boolean) || false;
    span.lineThrough = (sr['lineThrough'] as boolean) || false;
    span.color = (sr['color'] as string) || '';
    span.fontSize = (sr['fontSize'] as number) || 0;
    span.linkUrl = (sr['linkUrl'] as string) || '';
    spans.push(span);
  }

  return spans;
}


export class NativeArticleParser {
  
  static init(): void {
    resolveNativeModule();
  }

  
  static isNativeAvailable(): boolean {
    return resolveNativeModule() !== null;
  }

  
  private static isNativeEnabled(): boolean {
    let useNative = AppStorage.get<boolean>('useNativeParser');
    
    return useNative !== false;
  }

  
  static parse(rawContent: string, fullJsonString: string): ContentItem[] {
    if (NativeArticleParser.isNativeEnabled()) {
      let mod = resolveNativeModule();
      if (mod) {
        try {
          let json = mod.parseArticle(rawContent, fullJsonString);
          return deserializeContentItems(json);
        } catch (e) {
          FileLog.e('NativeParser', `parseArticle C++ 异常, 回退 ArkTS: ${(e as Error).message}`);
          if (!hasShownParserFallbackToast) {
            hasShownParserFallbackToast = true;
            try { promptAction.openToast({ message: '文章解析：C++ 异常，已回退 ArkTS' }); } catch (_e) {}
          }
        }
      }
    }
    
    return ArticleParser.parse(rawContent, fullJsonString);
  }

  
  static parseCommentContent(content: string): ContentItem[] {
    if (NativeArticleParser.isNativeEnabled()) {
      let mod = resolveNativeModule();
      if (mod) {
        try {
          let json = mod.parseComment(content);
          return deserializeContentItems(json);
        } catch (e) {
          FileLog.e('NativeParser', `parseComment C++ 异常, 回退 ArkTS: ${(e as Error).message}`);
          if (!hasShownParserFallbackToast) {
            hasShownParserFallbackToast = true;
            try { promptAction.openToast({ message: '评论解析：C++ 异常，已回退 ArkTS' }); } catch (_e) {}
          }
        }
      }
    }
    return ArticleParser.parseCommentContent(content);
  }

  
  static adaptColorForDarkMode(hexColor: string, isDark: boolean): string {
    if (NativeArticleParser.isNativeEnabled()) {
      let mod = resolveNativeModule();
      if (mod) {
        try {
          return mod.adaptColor(hexColor, isDark);
        } catch (e) {
          
        }
      }
    }
    return ArticleParser.adaptColorForDarkMode(hexColor, isDark);
  }

  
  static parseBBCodeWithLinks(text: string): RichSpan[] {
    if (NativeArticleParser.isNativeEnabled()) {
      let mod = resolveNativeModule();
      if (mod) {
        try {
          let json = mod.parseBBCode(text);
          return deserializeRichSpans(json);
        } catch (e) {
          FileLog.e('NativeParser', `parseBBCode C++ 异常, 回退 ArkTS: ${(e as Error).message}`);
        }
      }
    }
    return ArticleParser.detectLinksInSpans(ArticleParser.parseBBCodeSpans(text));
  }
}
