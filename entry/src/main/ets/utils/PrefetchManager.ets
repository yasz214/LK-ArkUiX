import { hilog } from '@kit.PerformanceAnalysisKit';
import { NovelRepository } from '../repository/NovelRepository';
import { ArticleCache } from './CacheManager';
import { NativeArticleParser } from './NativeArticleParser';
import { CachedArticle, ContentItem } from '../models/DataModels';
import { T2SEngine } from './T2SEngine';

export class PrefetchManager {
  static queue: number[] = [];
  static isFetching: boolean = false;

  static add(aid: number) {
    if (!ArticleCache.has(aid) && PrefetchManager.queue.indexOf(aid) === -1) {
      PrefetchManager.queue.push(aid);
      PrefetchManager.process();
    }
  }

  static async process() {
    if (PrefetchManager.isFetching || PrefetchManager.queue.length === 0) return;
    PrefetchManager.isFetching = true;
    let aid: number | undefined = PrefetchManager.queue.shift();

    if (aid !== undefined) {
      try {
        let result = await NovelRepository.getArticleDetail(aid);
        let rawContent: string = result.data.content || '';
        let title: string = result.data.title ?? '';

        let parsedItems: ContentItem[] = NativeArticleParser.parse(rawContent, result.rawJson);

        let cached = new CachedArticle();
        cached.title = title;
        cached.rawContent = rawContent;
        cached.parsedItems = parsedItems;

        let autoSimp = AppStorage.get<boolean>('autoSimp') ?? false;
        if (autoSimp) {
          cached.simpTitle = T2SEngine.convert(title);
          
          cached.simpItems = await T2SEngine.convertItemsAsync(parsedItems);
        }

        ArticleCache.set(aid, cached);
      } catch (error) {
        hilog.error(0x0000, 'Prefetch', 'Prefetch Error');
      }
    }

    setTimeout(() => {
      PrefetchManager.isFetching = false;
      PrefetchManager.process();
    }, 1500);
  }
}