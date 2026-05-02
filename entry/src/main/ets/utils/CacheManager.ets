import { CachedArticle } from '../models/DataModels';

export class ArticleCache {
  private static cache: Map<number, CachedArticle> = new Map();
  static has(aid: number): boolean { return ArticleCache.cache.has(aid); }
  static get(aid: number): CachedArticle | undefined { return ArticleCache.cache.get(aid); }
  static set(aid: number, data: CachedArticle): void { ArticleCache.cache.set(aid, data); }
}