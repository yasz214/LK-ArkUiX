import { ContentItem, RichSpan } from '../models/DataModels';
import { ArticleParser } from './ArticleParser';
import { FileLog } from './FileLog';
import { PlatformHelper } from './PlatformHelper';
import { promptAction } from '@kit.ArkUI';

import * as parserNative from 'libarticle_parser.so';

interface IParserNative {
  parseArticleJson(rawContent: string, fullJsonString: string): string;
  parseCommentJson(content: string): string;
  adaptColor(hexColor: string, isDark: boolean): string;
  parseBBCodeJson(text: string): string;
  benchmark(rawContent: string, fullJsonString: string, iterations: number): string;
}

let nativeParser: IParserNative | null = null;
let hasShownParserFallbackToast: boolean = false;

function parseItemsFromJson(json: string): ContentItem[] {
  if (json === '') return [];
  let parsed: Object = JSON.parse(json) as Object;
  if (!Array.isArray(parsed)) return [];
  return parsed as ContentItem[];
}

function parseSpansFromJson(json: string): RichSpan[] {
  if (json === '') return [];
  let parsed: Object = JSON.parse(json) as Object;
  if (!Array.isArray(parsed)) return [];
  return parsed as RichSpan[];
}

function resolveNativeModule(): IParserNative | null {
  if (nativeParser) return nativeParser;

  try {
    let modRec = parserNative as Object as Record<string, Object>;
    let hasArticleJson = typeof modRec['parseArticleJson'] === 'function';
    let hasCommentJson = typeof modRec['parseCommentJson'] === 'function';
    let hasColor = typeof modRec['adaptColor'] === 'function';
    FileLog.i('NativeParser', `[resolveNative] Method 1: parseArticleJson=${hasArticleJson}, parseCommentJson=${hasCommentJson}, adaptColor=${hasColor}`);
    if (hasArticleJson && hasCommentJson) {
      nativeParser = parserNative as Object as IParserNative;
      FileLog.i('NativeParser', '[resolveNative] Method 1 OK');
      return nativeParser;
    }
  } catch (e) {
    FileLog.w('NativeParser', `[resolveNative] Method 1 error: ${(e as Error).message}`);
  }

  try {
    let g = globalThis as Object as Record<string, Object>;
    let reqFn = g['requireNapi'];
    if (typeof reqFn === 'function') {
      let requireNapiFn = reqFn as (name: string) => Object;
      let mod = requireNapiFn('article_parser');
      if (mod) {
        let modRec = mod as Object as Record<string, Object>;
        let hasArticleJson = typeof modRec['parseArticleJson'] === 'function';
        let hasCommentJson = typeof modRec['parseCommentJson'] === 'function';
        FileLog.i('NativeParser', `[resolveNative] Method 2: parseArticleJson=${hasArticleJson}, parseCommentJson=${hasCommentJson}`);
        if (hasArticleJson) {
          nativeParser = mod as Object as IParserNative;
          FileLog.i('NativeParser', '[resolveNative] Method 2 OK');
          return nativeParser;
        }
      }
    }
  } catch (e) {
    FileLog.w('NativeParser', `[resolveNative] Method 2 error: ${(e as Error).message}`);
  }

  FileLog.e('NativeParser', '[resolveNative] all methods failed');
  return null;
}

export class NativeArticleParser {
  static init(): void {
    if (PlatformHelper.isAndroid()) return;
    resolveNativeModule();
  }

  static isNativeAvailable(): boolean {
    if (PlatformHelper.isAndroid()) return false;
    return resolveNativeModule() !== null;
  }

  private static isNativeEnabled(): boolean {
    if (PlatformHelper.isAndroid()) return false;
    let useNative = AppStorage.get<boolean>('useNativeParser');
    return useNative !== false;
  }

  static parse(rawContent: string, fullJsonString: string): ContentItem[] {
    if (NativeArticleParser.isNativeEnabled()) {
      let mod = resolveNativeModule();
      if (mod) {
        try {
          return parseItemsFromJson(mod.parseArticleJson(rawContent, fullJsonString));
        } catch (e) {
          FileLog.e('NativeParser', `parseArticle error, fallback ArkTS: ${(e as Error).message}`);
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
          return parseItemsFromJson(mod.parseCommentJson(content));
        } catch (e) {
          FileLog.e('NativeParser', `parseComment error, fallback ArkTS: ${(e as Error).message}`);
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
        } catch (_e) {}
      }
    }
    return ArticleParser.adaptColorForDarkMode(hexColor, isDark);
  }

  static parseBBCodeWithLinks(text: string): RichSpan[] {
    if (NativeArticleParser.isNativeEnabled()) {
      let mod = resolveNativeModule();
      if (mod) {
        try {
          return parseSpansFromJson(mod.parseBBCodeJson(text));
        } catch (e) {
          FileLog.e('NativeParser', `parseBBCode error, fallback ArkTS: ${(e as Error).message}`);
        }
      }
    }
    return ArticleParser.detectLinksInSpans(ArticleParser.parseBBCodeSpans(text));
  }

  static benchmarkNative(rawContent: string, fullJsonString: string, iterations: number): string {
    let mod = resolveNativeModule();
    if (!mod) return '{"error":"native not available"}';
    try {
      return mod.benchmark(rawContent, fullJsonString, iterations);
    } catch (e) {
      return `{"error":"${(e as Error).message}"}`;
    }
  }

  static runComparativeBenchmark(rawContent: string, fullJsonString: string,
    iterations: number): BenchmarkResult {
    let result = new BenchmarkResult();
    result.iterations = iterations;
    result.charCount = rawContent.length;

    let mod = resolveNativeModule();
    if (mod) {
      let nativeJson = NativeArticleParser.benchmarkNative(rawContent, fullJsonString, iterations);
      let nativeResult: Record<string, number> = JSON.parse(nativeJson) as Record<string, number>;
      result.cppDirectUs = nativeResult['avgDirectUs'] ?? 0;
      result.cppFullNapiUs = nativeResult['avgFullNapiUs'] ?? 0;
      result.napiReadUs = nativeResult['avgNapiReadUs'] ?? 0;
      result.napiWriteUs = nativeResult['avgNapiWriteUs'] ?? 0;
      result.jsonOutputBytes = (nativeResult['jsonOutputBytes'] ?? 0) as number;

      let fn = mod.parseArticleJson;

      let cppCallStart = Date.now();
      let lastJson: string = '';
      for (let i = 0; i < iterations; i++) {
        lastJson = fn(rawContent, fullJsonString);
      }
      let cppCallMs = Date.now() - cppCallStart;
      result.cppNapiCallUs = (cppCallMs * 1000.0) / iterations;

      let jsonParseStart = Date.now();
      for (let i = 0; i < iterations; i++) {
        JSON.parse(lastJson) as Object;
      }
      let jsonParseMs = Date.now() - jsonParseStart;
      result.arktsJsonParseUs = (jsonParseMs * 1000.0) / iterations;

      let e2eJsonStart = Date.now();
      for (let i = 0; i < iterations; i++) {
        try {
          parseItemsFromJson(fn(rawContent, fullJsonString));
        } catch (_e) {  }
      }
      let e2eJsonMs = Date.now() - e2eJsonStart;
      result.cppJsonE2EUs = (e2eJsonMs * 1000.0) / iterations;
    }

    let arktsStart = Date.now();
    let arktsItems: ContentItem[] = [];
    for (let i = 0; i < iterations; i++) {
      arktsItems = ArticleParser.parse(rawContent, fullJsonString);
    }
    let arktsMs = Date.now() - arktsStart;
    result.arktsUs = (arktsMs * 1000.0) / iterations;
    result.arktsItems = arktsItems.length;
    let arktsSpans = 0;
    for (let item of arktsItems) {
      if (item.spans) arktsSpans += item.spans.length;
    }
    result.arktsSpans = arktsSpans;

    if (result.cppDirectUs > 0) {
      result.speedupDirect = result.arktsUs / result.cppDirectUs;
    }
    if (result.cppJsonE2EUs > 0) {
      result.speedupJsonE2E = result.arktsUs / result.cppJsonE2EUs;
    }

    return result;
  }
}

export class BenchmarkResult {
  iterations: number = 0;
  charCount: number = 0;

  cppDirectUs: number = 0;
  cppFullNapiUs: number = 0;
  napiReadUs: number = 0;
  napiWriteUs: number = 0;
  jsonOutputBytes: number = 0;
  cppNapiCallUs: number = 0;
  cppJsonE2EUs: number = 0;

  arktsJsonParseUs: number = 0;
  arktsUs: number = 0;
  arktsItems: number = 0;
  arktsSpans: number = 0;

  speedupDirect: number = 0;
  speedupJsonE2E: number = 0;
}
