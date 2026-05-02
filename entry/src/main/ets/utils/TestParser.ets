import { ContentItem, RichSpan } from '../models/DataModels';

export function testParse(): ContentItem[] {
  let json = '[{"type":"text","value":"hello","spans":[{"text":"hello","bold":true}]}]';
  let items = JSON.parse(json) as ContentItem[];
  return items;
}
