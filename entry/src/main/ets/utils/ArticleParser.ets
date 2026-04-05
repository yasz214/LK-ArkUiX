import { ContentItem, RichSpan } from '../models/DataModels';
import { FileLog } from './FileLog';


class TagMatch {
  index: number = 0;      
  length: number = 0;     
  name: string = '';      
  isClosing: boolean = false;
  param: string = '';     
}


class FormatState {
  bold: boolean = false;
  italic: boolean = false;
  underline: boolean = false;
  lineThrough: boolean = false;
  color: string = '';
  fontSize: number = 0;
  linkUrl: string = '';    

  clone(): FormatState {
    let s = new FormatState();
    s.bold = this.bold;
    s.italic = this.italic;
    s.underline = this.underline;
    s.lineThrough = this.lineThrough;
    s.color = this.color;
    s.fontSize = this.fontSize;
    s.linkUrl = this.linkUrl;
    return s;
  }

  hasFormatting(): boolean {
    return this.bold || this.italic || this.underline || this.lineThrough
      || this.color !== '' || this.fontSize > 0 || this.linkUrl !== '';
  }
}

export class ArticleParser {
  
  
  
  private static readonly SIZE_MAP: number[] = [12, 15, 0, 21, 24, 28, 34];

  
  static mapSize(raw: string): number {
    let cleaned = raw.replace(/px|pt|vp/gi, '').trim();
    let n = parseFloat(cleaned);
    if (isNaN(n) || n <= 0) return 0;
    if (n <= 7 && Number.isInteger(n)) {
      let idx = Math.round(n) - 1;
      if (idx >= 0 && idx < ArticleParser.SIZE_MAP.length) {
        return ArticleParser.SIZE_MAP[idx];
      }
    }
    
    return Math.round(n);
  }

  
  static normalizeColor(raw: string): string {
    let c = raw.trim().toLowerCase();
    if (c === '') return '';

    
    if (c.startsWith('#')) {
      
      if (c.length === 4) {
        return '#' + c[1] + c[1] + c[2] + c[2] + c[3] + c[3];
      }
      return c;
    }

    
    if (c.startsWith('rgb')) {
      let nums = c.replace(/rgb\s*\(\s*/i, '').replace(/\s*\)/, '').split(',');
      if (nums.length >= 3) {
        let r = parseInt(nums[0].trim());
        let g = parseInt(nums[1].trim());
        let b = parseInt(nums[2].trim());
        if (!isNaN(r) && !isNaN(g) && !isNaN(b)) {
          let rHex = r.toString(16).padStart(2, '0');
          let gHex = g.toString(16).padStart(2, '0');
          let bHex = b.toString(16).padStart(2, '0');
          return `#${rHex}${gHex}${bHex}`;
        }
      }
      return '';
    }

    
    let colorMap: Record<string, string> = {
      'gray': '#808080', 'grey': '#808080',
      'red': '#FF0000', 'green': '#008000', 'blue': '#0000FF',
      'black': '#000000', 'white': '#FFFFFF',
      'orange': '#FFA500', 'yellow': '#FFFF00', 'purple': '#800080',
      'pink': '#FFC0CB', 'brown': '#A52A2A', 'silver': '#C0C0C0',
      'gold': '#FFD700', 'darkgray': '#A9A9A9', 'darkgrey': '#A9A9A9',
      'lightgray': '#D3D3D3', 'lightgrey': '#D3D3D3',
      'dimgray': '#696969', 'dimgrey': '#696969',
      'darkred': '#8B0000', 'darkblue': '#00008B', 'darkgreen': '#006400',
      'cyan': '#00FFFF', 'magenta': '#FF00FF', 'navy': '#000080',
      'teal': '#008080', 'olive': '#808000', 'maroon': '#800000',
      'indianred': '#CD5C5C', 'coral': '#FF7F50', 'tomato': '#FF6347',
      'crimson': '#DC143C', 'firebrick': '#B22222',
      'royalblue': '#4169E1', 'steelblue': '#4682B4',
      'deepskyblue': '#00BFFF', 'dodgerblue': '#1E90FF',
      'sienna': '#A0522D', 'chocolate': '#D2691E',
      'sandybrown': '#F4A460', 'darkorange': '#FF8C00',
      'limegreen': '#32CD32', 'seagreen': '#2E8B57',
    };

    let mapped = colorMap[c];
    if (mapped) return mapped;

    
    return c;
  }

  
  static findAllTags(text: string): TagMatch[] {
    let tags: TagMatch[] = [];
    let regex = /\[(\/?)(b|i|u|s|strike|color|size|font|align|url|quote|code|center|left|right|justify|indent|backcolor|sup|sub|hide|free|spoiler|collapse|table|tr|td|th|list|p|hr|media|flash|audio|video|attach|email|postbg|float)(?:=([^\]]*))?\]/gi;
    let match: RegExpExecArray | null = regex.exec(text);
    while (match !== null) {
      let tag = new TagMatch();
      tag.index = match.index;
      tag.length = match[0].length;
      tag.isClosing = match[1] === '/';
      tag.name = match[2].toLowerCase();
      tag.param = match[3] || '';
      
      if (tag.name === 'strike') tag.name = 's';
      tags.push(tag);
      match = regex.exec(text);
    }
    return tags;
  }

  
  static parseBBCodeSpans(text: string): RichSpan[] {
    let tags = ArticleParser.findAllTags(text);
    if (tags.length === 0) {
      
      if (text.length > 0) {
        let span = new RichSpan();
        span.text = text;
        return [span];
      }
      return [];
    }

    let spans: RichSpan[] = [];
    let stateStack: FormatState[] = [];
    let current = new FormatState();
    let cursor = 0;

    
    let formatTags: string[] = ['b', 'i', 'u', 's', 'color', 'size', 'url'];
    
    

    for (let t of tags) {
      
      if (t.index > cursor) {
        let chunk = text.substring(cursor, t.index);
        if (chunk.length > 0) {
          let span = new RichSpan();
          span.text = chunk;
          span.bold = current.bold;
          span.italic = current.italic;
          span.underline = current.underline;
          span.lineThrough = current.lineThrough;
          span.color = current.color;
          span.fontSize = current.fontSize;
          span.linkUrl = current.linkUrl;
          spans.push(span);
        }
      }
      cursor = t.index + t.length;

      
      if (formatTags.indexOf(t.name) >= 0) {
        if (!t.isClosing) {
          
          stateStack.push(current.clone());
          if (t.name === 'b') current.bold = true;
          else if (t.name === 'i') current.italic = true;
          else if (t.name === 'u') current.underline = true;
          else if (t.name === 's') current.lineThrough = true;
          else if (t.name === 'color') current.color = ArticleParser.normalizeColor(t.param);
          else if (t.name === 'size') {
            let mappedSize = ArticleParser.mapSize(t.param);
            current.fontSize = mappedSize;
            FileLog.i('ArticleParser', `[size=${t.param}] → mapped to ${mappedSize}vp`);
          }
          else if (t.name === 'url') {
            
            if (t.param) {
              current.linkUrl = t.param;
            }
          }
        } else {
          
          
          if (t.name === 'url' && current.linkUrl === '') {
            
            let lastSpanIndex = spans.length - 1;
            while (lastSpanIndex >= 0) {
              let lastSpan = spans[lastSpanIndex];
              if (lastSpan.linkUrl === '' && stateStack.length > 0) {
                let urlText = lastSpan.text.trim();
                if (urlText.startsWith('http://') || urlText.startsWith('https://')) {
                  lastSpan.linkUrl = urlText;
                }
              }
              
              break;
            }
          }
          if (stateStack.length > 0) {
            current = stateStack.pop() as FormatState;
          }
        }
      }
      
    }

    
    if (cursor < text.length) {
      let chunk = text.substring(cursor);
      if (chunk.length > 0) {
        let span = new RichSpan();
        span.text = chunk;
        span.bold = current.bold;
        span.italic = current.italic;
        span.underline = current.underline;
        span.lineThrough = current.lineThrough;
        span.color = current.color;
        span.fontSize = current.fontSize;
        span.linkUrl = current.linkUrl;
        spans.push(span);
      }
    }

    
    return spans.filter(s => s.text.length > 0);
  }


  
  private static extractDomain(url: string): string {
    try {
      let noProtocol = url.replace(/^https?:\/\
      let slashIdx = noProtocol.indexOf('/');
      if (slashIdx > 0) {
        return noProtocol.substring(0, slashIdx);
      }
      return noProtocol;
    } catch (e) {
      return url;
    }
  }

  
  static detectLinksInSpans(spans: RichSpan[]): RichSpan[] {
    let result: RichSpan[] = [];
    let urlRegex = /https?:\/\/[^\s\u3000\uff0c\u3002\uff01\uff1f\uff1b\uff1a\u201c\u201d\u2018\u2019\u300a\u300b\u3010\u3011\uff08\uff09<>\[\]()]+/g;

    for (let span of spans) {
      
      if (span.linkUrl !== '') {
        result.push(span);
        continue;
      }

      let text = span.text;
      let lastIndex = 0;
      let match: RegExpExecArray | null = urlRegex.exec(text);

      if (!match) {
        
        result.push(span);
        urlRegex.lastIndex = 0;
        continue;
      }

      
      urlRegex.lastIndex = 0;
      match = urlRegex.exec(text);

      while (match !== null) {
        
        if (match.index > lastIndex) {
          let beforeSpan = new RichSpan();
          beforeSpan.text = text.substring(lastIndex, match.index);
          beforeSpan.bold = span.bold;
          beforeSpan.italic = span.italic;
          beforeSpan.underline = span.underline;
          beforeSpan.lineThrough = span.lineThrough;
          beforeSpan.color = span.color;
          beforeSpan.fontSize = span.fontSize;
          result.push(beforeSpan);
        }

        
        let linkSpan = new RichSpan();
        linkSpan.text = match[0];
        linkSpan.bold = span.bold;
        linkSpan.italic = span.italic;
        linkSpan.underline = true;
        linkSpan.lineThrough = span.lineThrough;
        linkSpan.color = '';  
        linkSpan.fontSize = span.fontSize;
        linkSpan.linkUrl = match[0];
        result.push(linkSpan);

        lastIndex = match.index + match[0].length;
        match = urlRegex.exec(text);
      }

      
      if (lastIndex < text.length) {
        let afterSpan = new RichSpan();
        afterSpan.text = text.substring(lastIndex);
        afterSpan.bold = span.bold;
        afterSpan.italic = span.italic;
        afterSpan.underline = span.underline;
        afterSpan.lineThrough = span.lineThrough;
        afterSpan.color = span.color;
        afterSpan.fontSize = span.fontSize;
        result.push(afterSpan);
      }
    }

    return result;
  }

  
  static parse(rawContent: string, fullJsonString: string): ContentItem[] {
    let urlRegex = /https:\/\/res\.lightnovel\.fun\/[^"'\\]+\.(?:jpg|jpeg|png|webp|gif)[^"'\\]*/gi;
    let extractedUrls = fullJsonString.match(urlRegex) || [];
    let imageUrls = Array.from(new Set(extractedUrls.filter(url => url.includes('/images/') || url.includes('/attach/'))));

    // 兼容 [img] 和 [res] — 先转为安全占位符
    let processedContent = rawContent.replace(/\[img[^\]]*\](.*?)\[\/img\]/gi, '\n%%IMG_PH%%$1%%IMG_END%%\n');
    processedContent = processedContent.replace(/\[res\](.*?)\[\/res\]/gi, '\n%%IMG_PH%%$1%%IMG_END%%\n');

    // ✨ 兼容 HTML <img> 标签 — 提取 src 属性转为图片占位符
    // 支持: <img src="xx">, <img src="xx"/>, <img src="xx" />, <img src='xx'>, 带其他属性
    processedContent = processedContent.replace(/<img[^>]*src\s*=\s*["']([^"']+)["'][^>]*\/?>/gi, '\n%%IMG_PH%%$1%%IMG_END%%\n');

    // ✨ 处理 [media] 标签 — 转为链接占位符
    processedContent = processedContent.replace(/\[media[^\]]*\](.*?)\[\/media\]/gi, '\n%%LINK_PH%%$1%%LINK_END%%\n');

    // ✨ 处理 HTML <iframe> 标签 — 提取 src 并转为链接占位符
    processedContent = processedContent.replace(/<iframe[^>]*src\s*=\s*["']([^"']+)["'][^>]*>.*?<\/iframe>/gi, '\n%%LINK_PH%%$1%%LINK_END%%\n');
    // 自闭合 iframe
    processedContent = processedContent.replace(/<iframe[^>]*src\s*=\s*["']([^"']+)["'][^>]*\/?>/gi, '\n%%LINK_PH%%$1%%LINK_END%%\n');

    // 清除 [*] 列表项标记
    processedContent = processedContent.replace(/\[\*\]/g, '• ');

    // ✨ 处理 HTML <br> 换行标签 — 转为换行符
    processedContent = processedContent.replace(/<br\s*\/?>/gi, '\n');

    // ✨ 清除其他常见 HTML 标签（<p>, <div>, <span> 等），保留内容
    processedContent = processedContent.replace(/<\/?(?:p|div|span|strong|em|b|i|u|s|del|ins|a|font|center|blockquote|pre|code|h[1-6])[^>]*>/gi, '');

    let paragraphs = processedContent.split('\n').map(p => p.trim()).filter(p => p.length > 0);

    let parsedItems: ContentItem[] = [];
    let imageIndex = 0;

    for (let p of paragraphs) {
      if (p.startsWith('%%IMG_PH%%')) {
        let val = p.replace('%%IMG_PH%%', '').replace('%%IMG_END%%', '').trim();
        let item = new ContentItem();
        item.type = 'image';
        item.value = val;

        if (val.startsWith('http')) {
          item.url = `https://wsrv.nl/?url=${encodeURIComponent(val)}`;
          parsedItems.push(item);
        } else if (imageIndex < imageUrls.length) {
          item.url = imageUrls[imageIndex];
          imageIndex++;
          parsedItems.push(item);
        }
      } else if (p.startsWith('%%LINK_PH%%')) {
        // ✨ iframe/media 嵌入链接
        let linkUrl = p.replace('%%LINK_PH%%', '').replace('%%LINK_END%%', '').trim();
        if (linkUrl.startsWith('http:
          if (linkUrl.startsWith('//')) linkUrl = 'https:' + linkUrl;
          let item = new ContentItem();
          item.type = 'link';
          item.value = ArticleParser.extractDomain(linkUrl);
          item.url = linkUrl;
          parsedItems.push(item);
        }
      } else {
        
        let spans = ArticleParser.parseBBCodeSpans(p);
        if (spans.length > 0) {
          
          spans = ArticleParser.detectLinksInSpans(spans);

          let item = new ContentItem();
          item.type = 'text';
          
          item.value = spans.map(s => s.text).join('');
          item.spans = spans;
          parsedItems.push(item);
        }
      }
    }

    return parsedItems;
  }

  
  static parseCommentContent(content: string): ContentItem[] {
    if (!content || content.length === 0) return [];

    
    let processed = content.replace(/<br\s*\/?>/gi, '\n');

    let items: ContentItem[] = [];

    
    let imgRegex = /<img[^>]*src\s*=\s*["']([^"']+)["'][^>]*\/?>/gi;
    let lastIndex = 0;
    let match: RegExpExecArray | null = imgRegex.exec(processed);

    if (!match) {
      
      let spans = ArticleParser.parseBBCodeSpans(processed);
      if (spans.length > 0) {
        spans = ArticleParser.detectLinksInSpans(spans);
        let item = new ContentItem();
        item.type = 'text';
        item.value = spans.map(s => s.text).join('');
        item.spans = spans;
        items.push(item);
      }
      return items;
    }

    
    imgRegex.lastIndex = 0;
    match = imgRegex.exec(processed);

    while (match !== null) {
      
      if (match.index > lastIndex) {
        let textPart = processed.substring(lastIndex, match.index).trim();
        if (textPart.length > 0) {
          let spans = ArticleParser.parseBBCodeSpans(textPart);
          if (spans.length > 0) {
            spans = ArticleParser.detectLinksInSpans(spans);
            let item = new ContentItem();
            item.type = 'text';
            item.value = spans.map(s => s.text).join('');
            item.spans = spans;
            items.push(item);
          }
        }
      }

      
      let imgUrl = match[1];
      if (imgUrl && imgUrl.length > 0) {
        let imgItem = new ContentItem();
        imgItem.type = 'image';
        imgItem.value = imgUrl;
        if (imgUrl.startsWith('http')) {
          imgItem.url = `https://wsrv.nl/?url=${encodeURIComponent(imgUrl)}`;
        } else {
          imgItem.url = imgUrl;
        }
        items.push(imgItem);
      }

      lastIndex = match.index + match[0].length;
      match = imgRegex.exec(processed);
    }

    
    if (lastIndex < processed.length) {
      let textPart = processed.substring(lastIndex).trim();
      if (textPart.length > 0) {
        let spans = ArticleParser.parseBBCodeSpans(textPart);
        if (spans.length > 0) {
          spans = ArticleParser.detectLinksInSpans(spans);
          let item = new ContentItem();
          item.type = 'text';
          item.value = spans.map(s => s.text).join('');
          item.spans = spans;
          items.push(item);
        }
      }
    }

    return items;
  }

  
  static adaptColorForDarkMode(hexColor: string, isDark: boolean): string {
    if (!isDark || hexColor === '') return hexColor;

    
    let hex = hexColor.replace('#', '');
    
    if (hex.length === 3) {
      hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    }
    
    if (hex.length < 6) return hexColor;
    hex = hex.substring(0, 6);

    let r = parseInt(hex.substring(0, 2), 16);
    let g = parseInt(hex.substring(2, 4), 16);
    let b = parseInt(hex.substring(4, 6), 16);
    if (isNaN(r) || isNaN(g) || isNaN(b)) return hexColor;

    
    let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    
    let maxC = Math.max(r, g, b);
    let minC = Math.min(r, g, b);
    let saturation = maxC > 0 ? (maxC - minC) / maxC : 0;

    
    
    
    if (saturation <= 0.12) {
      
      if (luminance >= 0.6) {
        return hexColor;
      }
      
      let targetL = 0.55 + (1 - luminance) * 0.35;  
      let gray = Math.round(targetL * 255);
      gray = Math.min(245, Math.max(160, gray));  
      let gHex = gray.toString(16).padStart(2, '0');
      return `#${gHex}${gHex}${gHex}`;
    }

    
    
    
    
    if (luminance >= 0.35) {
      return hexColor;
    }

    
    
    
    let rn = r / 255;
    let gn = g / 255;
    let bn = b / 255;
    let cmax = Math.max(rn, gn, bn);
    let cmin = Math.min(rn, gn, bn);
    let delta = cmax - cmin;

    
    let h = 0;
    if (delta > 0) {
      if (cmax === rn) {
        h = 60 * (((gn - bn) / delta) % 6);
      } else if (cmax === gn) {
        h = 60 * ((bn - rn) / delta + 2);
      } else {
        h = 60 * ((rn - gn) / delta + 4);
      }
    }
    if (h < 0) h += 360;

    
    let l = (cmax + cmin) / 2;
    let s = delta === 0 ? 0 : delta / (1 - Math.abs(2 * l - 1));

    
    let targetLightness = Math.max(0.55, l + 0.25);
    targetLightness = Math.min(0.78, targetLightness);  
    
    let targetSat = Math.min(s, 0.85);

    
    let c2 = (1 - Math.abs(2 * targetLightness - 1)) * targetSat;
    let x2 = c2 * (1 - Math.abs((h / 60) % 2 - 1));
    let m2 = targetLightness - c2 / 2;

    let r1 = 0, g1 = 0, b1 = 0;
    if (h < 60) { r1 = c2; g1 = x2; b1 = 0; }
    else if (h < 120) { r1 = x2; g1 = c2; b1 = 0; }
    else if (h < 180) { r1 = 0; g1 = c2; b1 = x2; }
    else if (h < 240) { r1 = 0; g1 = x2; b1 = c2; }
    else if (h < 300) { r1 = x2; g1 = 0; b1 = c2; }
    else { r1 = c2; g1 = 0; b1 = x2; }

    let newR = Math.round((r1 + m2) * 255);
    let newG = Math.round((g1 + m2) * 255);
    let newB = Math.round((b1 + m2) * 255);
    newR = Math.min(255, Math.max(0, newR));
    newG = Math.min(255, Math.max(0, newG));
    newB = Math.min(255, Math.max(0, newB));

    return `#${newR.toString(16).padStart(2, '0')}${newG.toString(16).padStart(2, '0')}${newB.toString(16).padStart(2, '0')}`;
  }
}
