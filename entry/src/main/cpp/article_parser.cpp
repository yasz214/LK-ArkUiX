

#include <napi/native_api.h>
#include <vector>
#include <string>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <cstdint>
#include <algorithm>





struct RichSpanC {
    std::u16string text;
    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool lineThrough = false;
    std::u16string color;     
    int fontSize = 0;         
    std::u16string linkUrl;   
};

struct ContentItemC {
    int type = 0;             
    std::u16string value;
    std::u16string url;
    std::vector<RichSpanC> spans;
};


struct FormatStateC {
    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool lineThrough = false;
    std::u16string color;
    int fontSize = 0;
    std::u16string linkUrl;
};


static const int SIZE_MAP[7] = {12, 15, 0, 21, 24, 28, 34};





static inline bool u16_starts_with_ci(const char16_t* s, size_t sLen,
                                      const char16_t* prefix, size_t pLen) {
    if (sLen < pLen) return false;
    for (size_t i = 0; i < pLen; i++) {
        char16_t a = s[i], b = prefix[i];
        if (a >= u'A' && a <= u'Z') a += 32;
        if (b >= u'A' && b <= u'Z') b += 32;
        if (a != b) return false;
    }
    return true;
}

static inline char16_t u16_tolower(char16_t c) {
    return (c >= u'A' && c <= u'Z') ? (c + 32) : c;
}

static inline bool u16_eq_ci(const char16_t* a, size_t aLen,
                              const char16_t* b, size_t bLen) {
    if (aLen != bLen) return false;
    for (size_t i = 0; i < aLen; i++) {
        if (u16_tolower(a[i]) != u16_tolower(b[i])) return false;
    }
    return true;
}


static std::string u16_to_narrow(const char16_t* s, size_t len) {
    std::string r;
    r.reserve(len);
    for (size_t i = 0; i < len; i++) {
        if (s[i] < 128) r += (char)s[i];
        else r += '?';
    }
    return r;
}

static int hexChar(char16_t c) {
    if (c >= u'0' && c <= u'9') return c - u'0';
    if (c >= u'a' && c <= u'f') return c - u'a' + 10;
    if (c >= u'A' && c <= u'F') return c - u'A' + 10;
    return -1;
}







class JsonWriter {
public:
    std::string buf;

    JsonWriter() { buf.reserve(8192); }

    void beginArray() { buf += '['; }
    void endArray() { buf += ']'; }
    void beginObject() { buf += '{'; }
    void endObject() { buf += '}'; }
    void comma() { buf += ','; }

    void key(const char* k) {
        buf += '"';
        buf += k;
        buf += "\":";
    }

    void valStr(const std::u16string& s) {
        buf += '"';
        appendEscapedU16(s);
        buf += '"';
    }

    void valStr(const char* s) {
        buf += '"';
        buf += s;
        buf += '"';
    }

    void valInt(int v) {
        char tmp[16];
        snprintf(tmp, sizeof(tmp), "%d", v);
        buf += tmp;
    }

    void valBool(bool v) {
        buf += (v ? "true" : "false");
    }

private:
    void appendEscapedU16(const std::u16string& s) {
        for (size_t i = 0; i < s.size(); i++) {
            char16_t c = s[i];
            if (c == u'"') { buf += "\\\""; }
            else if (c == u'\\') { buf += "\\\\"; }
            else if (c == u'\n') { buf += "\\n"; }
            else if (c == u'\r') { buf += "\\r"; }
            else if (c == u'\t') { buf += "\\t"; }
            else if (c < 0x20) {
                char esc[8];
                snprintf(esc, sizeof(esc), "\\u%04x", (unsigned)c);
                buf += esc;
            }
            else if (c < 0x80) {
                buf += (char)c;
            }
            else if (c < 0x800) {
                buf += (char)(0xC0 | (c >> 6));
                buf += (char)(0x80 | (c & 0x3F));
            }
            else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.size()) {
                
                char16_t hi = c;
                char16_t lo = s[++i];
                if (lo >= 0xDC00 && lo <= 0xDFFF) {
                    uint32_t cp = 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00);
                    buf += (char)(0xF0 | (cp >> 18));
                    buf += (char)(0x80 | ((cp >> 12) & 0x3F));
                    buf += (char)(0x80 | ((cp >> 6) & 0x3F));
                    buf += (char)(0x80 | (cp & 0x3F));
                } else {
                    
                    char esc[8];
                    snprintf(esc, sizeof(esc), "\\u%04x", (unsigned)hi);
                    buf += esc;
                    i--; 
                }
            }
            else {
                buf += (char)(0xE0 | (c >> 12));
                buf += (char)(0x80 | ((c >> 6) & 0x3F));
                buf += (char)(0x80 | (c & 0x3F));
            }
        }
    }
};

static void serializeContentItems(const std::vector<ContentItemC>& items, JsonWriter& jw) {
    jw.beginArray();
    for (size_t i = 0; i < items.size(); i++) {
        if (i > 0) jw.comma();
        const auto& item = items[i];
        jw.beginObject();

        
        jw.key("type");
        if (item.type == 0) jw.valStr("text");
        else if (item.type == 1) jw.valStr("image");
        else jw.valStr("link");

        
        jw.comma(); jw.key("value"); jw.valStr(item.value);

        
        jw.comma(); jw.key("url"); jw.valStr(item.url);

        
        jw.comma(); jw.key("spans");
        jw.beginArray();
        for (size_t j = 0; j < item.spans.size(); j++) {
            if (j > 0) jw.comma();
            const auto& sp = item.spans[j];
            jw.beginObject();
            jw.key("text"); jw.valStr(sp.text);
            jw.comma(); jw.key("bold"); jw.valBool(sp.bold);
            jw.comma(); jw.key("italic"); jw.valBool(sp.italic);
            jw.comma(); jw.key("underline"); jw.valBool(sp.underline);
            jw.comma(); jw.key("lineThrough"); jw.valBool(sp.lineThrough);
            jw.comma(); jw.key("color"); jw.valStr(sp.color);
            jw.comma(); jw.key("fontSize"); jw.valInt(sp.fontSize);
            jw.comma(); jw.key("linkUrl"); jw.valStr(sp.linkUrl);
            jw.endObject();
        }
        jw.endArray();

        jw.endObject();
    }
    jw.endArray();
}





struct NamedColor { const char* name; const char16_t* hex; };

static const NamedColor NAMED_COLORS[] = {
    {"gray", u"#808080"}, {"grey", u"#808080"},
    {"red", u"#ff0000"}, {"green", u"#008000"}, {"blue", u"#0000ff"},
    {"black", u"#000000"}, {"white", u"#ffffff"},
    {"orange", u"#ffa500"}, {"yellow", u"#ffff00"}, {"purple", u"#800080"},
    {"pink", u"#ffc0cb"}, {"brown", u"#a52a2a"}, {"silver", u"#c0c0c0"},
    {"gold", u"#ffd700"}, {"darkgray", u"#a9a9a9"}, {"darkgrey", u"#a9a9a9"},
    {"lightgray", u"#d3d3d3"}, {"lightgrey", u"#d3d3d3"},
    {"dimgray", u"#696969"}, {"dimgrey", u"#696969"},
    {"darkred", u"#8b0000"}, {"darkblue", u"#00008b"}, {"darkgreen", u"#006400"},
    {"cyan", u"#00ffff"}, {"magenta", u"#ff00ff"}, {"navy", u"#000080"},
    {"teal", u"#008080"}, {"olive", u"#808000"}, {"maroon", u"#800000"},
    {"indianred", u"#cd5c5c"}, {"coral", u"#ff7f50"}, {"tomato", u"#ff6347"},
    {"crimson", u"#dc143c"}, {"firebrick", u"#b22222"},
    {"royalblue", u"#4169e1"}, {"steelblue", u"#4682b4"},
    {"deepskyblue", u"#00bfff"}, {"dodgerblue", u"#1e90ff"},
    {"sienna", u"#a0522d"}, {"chocolate", u"#d2691e"},
    {"sandybrown", u"#f4a460"}, {"darkorange", u"#ff8c00"},
    {"limegreen", u"#32cd32"}, {"seagreen", u"#2e8b57"},
    {nullptr, nullptr}
};

static std::u16string normalizeColor(const char16_t* raw, size_t len) {
    if (len == 0) return {};

    
    while (len > 0 && (raw[0] == u' ' || raw[0] == u'\t')) { raw++; len--; }
    while (len > 0 && (raw[len-1] == u' ' || raw[len-1] == u'\t')) { len--; }
    if (len == 0) return {};

    
    if (raw[0] == u'#') {
        if (len == 4) {
            
            std::u16string r = u"#";
            r += raw[1]; r += raw[1];
            r += raw[2]; r += raw[2];
            r += raw[3]; r += raw[3];
            return r;
        }
        return std::u16string(raw, len);
    }

    
    if (len >= 5 && u16_tolower(raw[0]) == u'r' && u16_tolower(raw[1]) == u'g' && u16_tolower(raw[2]) == u'b') {
        
        size_t start = 0;
        while (start < len && raw[start] != u'(') start++;
        start++;
        int vals[3] = {0, 0, 0};
        int vi = 0;
        int num = 0;
        bool hasNum = false;
        for (size_t i = start; i < len && vi < 3; i++) {
            if (raw[i] >= u'0' && raw[i] <= u'9') {
                num = num * 10 + (raw[i] - u'0');
                hasNum = true;
            } else if ((raw[i] == u',' || raw[i] == u')') && hasNum) {
                vals[vi++] = num;
                num = 0;
                hasNum = false;
            } else if (raw[i] == u' ') {
                continue;
            }
        }
        if (hasNum && vi < 3) vals[vi++] = num;
        if (vi >= 3) {
            char hex[10];
            snprintf(hex, sizeof(hex), "#%02x%02x%02x", vals[0] & 0xFF, vals[1] & 0xFF, vals[2] & 0xFF);
            std::u16string r;
            for (int i2 = 0; hex[i2]; i2++) r += (char16_t)hex[i2];
            return r;
        }
        return {};
    }

    
    std::string narrow = u16_to_narrow(raw, len);
    for (auto& ch : narrow) { if (ch >= 'A' && ch <= 'Z') ch += 32; }
    for (const NamedColor* nc = NAMED_COLORS; nc->name; nc++) {
        if (narrow == nc->name) {
            return std::u16string(nc->hex);
        }
    }

    
    return std::u16string(raw, len);
}





static int mapSize(const char16_t* raw, size_t len) {
    
    std::string s = u16_to_narrow(raw, len);
    
    size_t pos;
    while ((pos = s.find("px")) != std::string::npos) s.erase(pos, 2);
    while ((pos = s.find("pt")) != std::string::npos) s.erase(pos, 2);
    while ((pos = s.find("vp")) != std::string::npos) s.erase(pos, 2);
    
    while (!s.empty() && s[0] == ' ') s.erase(0, 1);
    while (!s.empty() && s.back() == ' ') s.pop_back();

    double n = atof(s.c_str());
    if (n <= 0) return 0;
    if (n <= 7 && n == (int)n) {
        int idx = (int)n - 1;
        if (idx >= 0 && idx < 7) return SIZE_MAP[idx];
    }
    return (int)round(n);
}





static std::u16string adaptColorForDarkMode(const char16_t* hexRaw, size_t hexLen, bool isDark) {
    if (!isDark || hexLen == 0) return std::u16string(hexRaw, hexLen);

    
    const char16_t* hex = hexRaw;
    size_t hLen = hexLen;
    if (hex[0] == u'#') { hex++; hLen--; }

    
    int r, g, b;
    if (hLen == 3) {
        int h0 = hexChar(hex[0]), h1 = hexChar(hex[1]), h2 = hexChar(hex[2]);
        if (h0 < 0 || h1 < 0 || h2 < 0) return std::u16string(hexRaw, hexLen);
        r = h0 * 17; g = h1 * 17; b = h2 * 17;
    } else if (hLen >= 6) {
        int h0 = hexChar(hex[0]), h1 = hexChar(hex[1]);
        int h2 = hexChar(hex[2]), h3 = hexChar(hex[3]);
        int h4 = hexChar(hex[4]), h5 = hexChar(hex[5]);
        if (h0 < 0 || h1 < 0 || h2 < 0 || h3 < 0 || h4 < 0 || h5 < 0)
            return std::u16string(hexRaw, hexLen);
        r = h0 * 16 + h1; g = h2 * 16 + h3; b = h4 * 16 + h5;
    } else {
        return std::u16string(hexRaw, hexLen);
    }

    double luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;

    int maxC = std::max({r, g, b});
    int minC = std::min({r, g, b});
    double saturation = maxC > 0 ? (double)(maxC - minC) / maxC : 0.0;

    
    if (saturation <= 0.12) {
        if (luminance >= 0.6) return std::u16string(hexRaw, hexLen);
        double targetL = 0.55 + (1.0 - luminance) * 0.35;
        int gray = (int)round(targetL * 255.0);
        if (gray < 160) gray = 160;
        if (gray > 245) gray = 245;
        char out[10];
        snprintf(out, sizeof(out), "#%02x%02x%02x", gray, gray, gray);
        std::u16string res;
        for (int i = 0; out[i]; i++) res += (char16_t)out[i];
        return res;
    }

    
    if (luminance >= 0.35) return std::u16string(hexRaw, hexLen);

    
    double rn = r / 255.0, gn = g / 255.0, bn = b / 255.0;
    double cmax = std::max({rn, gn, bn});
    double cmin = std::min({rn, gn, bn});
    double delta = cmax - cmin;

    double h = 0;
    if (delta > 0) {
        if (cmax == rn) h = 60.0 * fmod((gn - bn) / delta, 6.0);
        else if (cmax == gn) h = 60.0 * ((bn - rn) / delta + 2.0);
        else h = 60.0 * ((rn - gn) / delta + 4.0);
    }
    if (h < 0) h += 360.0;

    double l = (cmax + cmin) / 2.0;
    double s = delta == 0 ? 0 : delta / (1.0 - fabs(2.0 * l - 1.0));

    double targetLightness = l + 0.25;
    if (targetLightness < 0.55) targetLightness = 0.55;
    if (targetLightness > 0.78) targetLightness = 0.78;
    double targetSat = s < 0.85 ? s : 0.85;

    double c2 = (1.0 - fabs(2.0 * targetLightness - 1.0)) * targetSat;
    double x2 = c2 * (1.0 - fabs(fmod(h / 60.0, 2.0) - 1.0));
    double m2 = targetLightness - c2 / 2.0;

    double r1 = 0, g1 = 0, b1 = 0;
    if (h < 60) { r1 = c2; g1 = x2; }
    else if (h < 120) { r1 = x2; g1 = c2; }
    else if (h < 180) { g1 = c2; b1 = x2; }
    else if (h < 240) { g1 = x2; b1 = c2; }
    else if (h < 300) { r1 = x2; b1 = c2; }
    else { r1 = c2; b1 = x2; }

    int newR = (int)round((r1 + m2) * 255.0);
    int newG = (int)round((g1 + m2) * 255.0);
    int newB = (int)round((b1 + m2) * 255.0);
    if (newR < 0) newR = 0; if (newR > 255) newR = 255;
    if (newG < 0) newG = 0; if (newG > 255) newG = 255;
    if (newB < 0) newB = 0; if (newB > 255) newB = 255;

    char out[10];
    snprintf(out, sizeof(out), "#%02x%02x%02x", newR, newG, newB);
    std::u16string res;
    for (int i = 0; out[i]; i++) res += (char16_t)out[i];
    return res;
}






enum BBTagKind {
    TAG_NONE = 0,
    TAG_B, TAG_I, TAG_U, TAG_S,
    TAG_COLOR, TAG_SIZE, TAG_URL,
    TAG_FONT, TAG_ALIGN, TAG_QUOTE, TAG_CODE, TAG_CENTER,
    TAG_LEFT, TAG_RIGHT, TAG_JUSTIFY, TAG_INDENT,
    TAG_BACKCOLOR, TAG_SUP, TAG_SUB, TAG_HIDE, TAG_FREE,
    TAG_SPOILER, TAG_COLLAPSE, TAG_TABLE, TAG_TR, TAG_TD, TAG_TH,
    TAG_LIST, TAG_P, TAG_HR, TAG_MEDIA, TAG_FLASH, TAG_AUDIO,
    TAG_VIDEO, TAG_ATTACH, TAG_EMAIL, TAG_POSTBG, TAG_FLOAT,
    TAG_STRIKE, 
    TAG_IMG, TAG_RES, 
};

struct TagNameEntry { const char16_t* name; size_t len; BBTagKind kind; };


static inline bool isFormatTag(BBTagKind k) {
    return k == TAG_B || k == TAG_I || k == TAG_U || k == TAG_S
        || k == TAG_STRIKE || k == TAG_COLOR || k == TAG_SIZE || k == TAG_URL;
}


static BBTagKind lookupTag(const char16_t* s, size_t len) {
    if (len == 0) return TAG_NONE;
    char16_t first = u16_tolower(s[0]);

    
    if (len == 1) {
        switch (first) {
            case u'b': return TAG_B;
            case u'i': return TAG_I;
            case u'u': return TAG_U;
            case u's': return TAG_S;
            case u'p': return TAG_P;
        }
        return TAG_NONE;
    }

    
    char16_t lc[16];
    if (len > 15) return TAG_NONE;
    for (size_t i = 0; i < len; i++) lc[i] = u16_tolower(s[i]);

    #define CMP(lit) (len == (sizeof(lit)/2 - 1) && memcmp(lc, lit, len * 2) == 0)

    switch (first) {
        case u'a':
            if (CMP(u"align")) return TAG_ALIGN;
            if (CMP(u"attach")) return TAG_ATTACH;
            if (CMP(u"audio")) return TAG_AUDIO;
            break;
        case u'b':
            if (len == 1) return TAG_B;
            if (CMP(u"backcolor")) return TAG_BACKCOLOR;
            break;
        case u'c':
            if (CMP(u"color")) return TAG_COLOR;
            if (CMP(u"code")) return TAG_CODE;
            if (CMP(u"center")) return TAG_CENTER;
            if (CMP(u"collapse")) return TAG_COLLAPSE;
            break;
        case u'e':
            if (CMP(u"email")) return TAG_EMAIL;
            break;
        case u'f':
            if (CMP(u"font")) return TAG_FONT;
            if (CMP(u"flash")) return TAG_FLASH;
            if (CMP(u"free")) return TAG_FREE;
            if (CMP(u"float")) return TAG_FLOAT;
            break;
        case u'h':
            if (CMP(u"hide")) return TAG_HIDE;
            if (CMP(u"hr")) return TAG_HR;
            break;
        case u'i':
            if (len == 1) return TAG_I;
            if (CMP(u"img")) return TAG_IMG;
            if (CMP(u"indent")) return TAG_INDENT;
            break;
        case u'j':
            if (CMP(u"justify")) return TAG_JUSTIFY;
            break;
        case u'l':
            if (CMP(u"left")) return TAG_LEFT;
            if (CMP(u"list")) return TAG_LIST;
            break;
        case u'm':
            if (CMP(u"media")) return TAG_MEDIA;
            break;
        case u'p':
            if (len == 1) return TAG_P;
            if (CMP(u"postbg")) return TAG_POSTBG;
            break;
        case u'r':
            if (CMP(u"res")) return TAG_RES;
            if (CMP(u"right")) return TAG_RIGHT;
            break;
        case u's':
            if (len == 1) return TAG_S;
            if (CMP(u"size")) return TAG_SIZE;
            if (CMP(u"strike")) return TAG_STRIKE;
            if (CMP(u"spoiler")) return TAG_SPOILER;
            if (CMP(u"sub")) return TAG_SUB;
            if (CMP(u"sup")) return TAG_SUP;
            break;
        case u't':
            if (CMP(u"table")) return TAG_TABLE;
            if (CMP(u"tr")) return TAG_TR;
            if (CMP(u"td")) return TAG_TD;
            if (CMP(u"th")) return TAG_TH;
            break;
        case u'u':
            if (len == 1) return TAG_U;
            if (CMP(u"url")) return TAG_URL;
            break;
        case u'v':
            if (CMP(u"video")) return TAG_VIDEO;
            break;
    }
    #undef CMP
    return TAG_NONE;
}





static const char16_t HTTP_PREFIX[] = u"http://";
static const char16_t HTTPS_PREFIX[] = u"https://";

static bool isUrlTerminator(char16_t c) {
    
    if (c <= u' ') return true;
    switch (c) {
        case u'\u3000': case u'\uff0c': case u'\u3002': case u'\uff01':
        case u'\uff1f': case u'\uff1b': case u'\uff1a': case u'\u201c':
        case u'\u201d': case u'\u2018': case u'\u2019': case u'\u300a':
        case u'\u300b': case u'\u3010': case u'\u3011': case u'\uff08':
        case u'\uff09': case u'<': case u'>': case u'[': case u']':
        case u'(': case u')':
            return true;
    }
    return false;
}


static size_t findUrlAt(const char16_t* text, size_t pos, size_t textLen) {
    size_t remain = textLen - pos;
    bool isHttp = false;
    if (remain >= 7 && u16_starts_with_ci(text + pos, remain, HTTP_PREFIX, 7)) {
        isHttp = true;
    } else if (remain >= 8 && u16_starts_with_ci(text + pos, remain, HTTPS_PREFIX, 8)) {
        isHttp = true;
    }
    if (!isHttp) return 0;

    size_t end = pos;
    while (end < textLen && !isUrlTerminator(text[end])) end++;
    return end - pos;
}






static std::u16string extractSrcAttr(const char16_t* tag, size_t tagLen) {
    for (size_t i = 0; i + 3 < tagLen; i++) {
        if (u16_tolower(tag[i]) == u's' && u16_tolower(tag[i+1]) == u'r' &&
            u16_tolower(tag[i+2]) == u'c') {
            size_t j = i + 3;
            while (j < tagLen && tag[j] == u' ') j++;
            if (j < tagLen && tag[j] == u'=') {
                j++;
                while (j < tagLen && tag[j] == u' ') j++;
                if (j < tagLen && (tag[j] == u'"' || tag[j] == u'\'')) {
                    char16_t quote = tag[j];
                    j++;
                    size_t start = j;
                    while (j < tagLen && tag[j] != quote) j++;
                    return std::u16string(tag + start, j - start);
                }
            }
        }
    }
    return {};
}





static std::u16string extractDomain(const std::u16string& url) {
    size_t start = 0;
    
    if (url.size() > 8 && url[4] == u's') start = 8; 
    else if (url.size() > 7 && url[4] == u':') start = 7; 

    size_t end = start;
    while (end < url.size() && url[end] != u'/') end++;
    if (end > start) return url.substr(start, end - start);
    return url;
}





static void detectLinksInSpans(std::vector<RichSpanC>& spans) {
    std::vector<RichSpanC> result;
    result.reserve(spans.size());

    for (auto& span : spans) {
        if (!span.linkUrl.empty()) {
            result.push_back(std::move(span));
            continue;
        }

        const char16_t* text = span.text.data();
        size_t textLen = span.text.size();
        size_t lastIndex = 0;

        for (size_t pos = 0; pos < textLen; ) {
            size_t urlLen = findUrlAt(text, pos, textLen);
            if (urlLen == 0) { pos++; continue; }

            
            if (pos > lastIndex) {
                RichSpanC before;
                before.text = std::u16string(text + lastIndex, pos - lastIndex);
                before.bold = span.bold;
                before.italic = span.italic;
                before.underline = span.underline;
                before.lineThrough = span.lineThrough;
                before.color = span.color;
                before.fontSize = span.fontSize;
                result.push_back(std::move(before));
            }

            
            RichSpanC link;
            link.text = std::u16string(text + pos, urlLen);
            link.bold = span.bold;
            link.italic = span.italic;
            link.underline = true;
            link.lineThrough = span.lineThrough;
            
            link.fontSize = span.fontSize;
            link.linkUrl = link.text;
            result.push_back(std::move(link));

            lastIndex = pos + urlLen;
            pos = lastIndex;
        }

        
        if (lastIndex == 0) {
            
            result.push_back(std::move(span));
        } else if (lastIndex < textLen) {
            RichSpanC after;
            after.text = std::u16string(text + lastIndex, textLen - lastIndex);
            after.bold = span.bold;
            after.italic = span.italic;
            after.underline = span.underline;
            after.lineThrough = span.lineThrough;
            after.color = span.color;
            after.fontSize = span.fontSize;
            result.push_back(std::move(after));
        }
    }

    spans = std::move(result);
}





static std::vector<RichSpanC> parseBBCodeSpans(const char16_t* text, size_t textLen) {
    std::vector<RichSpanC> spans;
    if (textLen == 0) return spans;

    std::vector<FormatStateC> stateStack;
    FormatStateC current;
    size_t cursor = 0;

    
    size_t i = 0;
    while (i < textLen) {
        if (text[i] != u'[') { i++; continue; }

        
        size_t tagStart = i;
        i++; 
        if (i >= textLen) break;

        
        bool isClosing = false;
        if (text[i] == u'/') { isClosing = true; i++; }
        if (i >= textLen) { i = tagStart + 1; continue; }

        
        size_t nameStart = i;
        while (i < textLen && text[i] != u']' && text[i] != u'=' && text[i] != u' ') i++;
        size_t nameLen = i - nameStart;
        if (nameLen == 0 || i >= textLen) { i = tagStart + 1; continue; }

        BBTagKind kind = lookupTag(text + nameStart, nameLen);
        if (kind == TAG_NONE) { i = tagStart + 1; continue; }

        
        const char16_t* paramStart = nullptr;
        size_t paramLen = 0;
        if (text[i] == u'=') {
            i++; 
            paramStart = text + i;
            while (i < textLen && text[i] != u']') i++;
            paramLen = (text + i) - paramStart;
        }

        
        while (i < textLen && text[i] != u']') i++;
        if (i >= textLen) { i = tagStart + 1; continue; }
        i++; 

        size_t tagEnd = i;

        
        
        

        
        if (kind == TAG_STRIKE) kind = TAG_S;

        
        if (tagStart > cursor) {
            RichSpanC span;
            span.text = std::u16string(text + cursor, tagStart - cursor);
            span.bold = current.bold;
            span.italic = current.italic;
            span.underline = current.underline;
            span.lineThrough = current.lineThrough;
            span.color = current.color;
            span.fontSize = current.fontSize;
            span.linkUrl = current.linkUrl;
            if (!span.text.empty()) spans.push_back(std::move(span));
        }
        cursor = tagEnd;

        
        if (isFormatTag(kind)) {
            if (!isClosing) {
                
                stateStack.push_back(current);
                switch (kind) {
                    case TAG_B: current.bold = true; break;
                    case TAG_I: current.italic = true; break;
                    case TAG_U: current.underline = true; break;
                    case TAG_S: case TAG_STRIKE: current.lineThrough = true; break;
                    case TAG_COLOR:
                        if (paramLen > 0)
                            current.color = normalizeColor(paramStart, paramLen);
                        break;
                    case TAG_SIZE:
                        if (paramLen > 0)
                            current.fontSize = mapSize(paramStart, paramLen);
                        break;
                    case TAG_URL:
                        if (paramLen > 0)
                            current.linkUrl = std::u16string(paramStart, paramLen);
                        break;
                    default: break;
                }
            } else {
                
                if (kind == TAG_URL && current.linkUrl.empty()) {
                    if (!spans.empty()) {
                        auto& lastSpan = spans.back();
                        if (lastSpan.linkUrl.empty() && !stateStack.empty()) {
                            auto& t = lastSpan.text;
                            if (t.size() > 7 &&
                                (u16_starts_with_ci(t.data(), t.size(), HTTP_PREFIX, 7) ||
                                 u16_starts_with_ci(t.data(), t.size(), HTTPS_PREFIX, 8))) {
                                lastSpan.linkUrl = t;
                            }
                        }
                    }
                }
                if (!stateStack.empty()) {
                    current = stateStack.back();
                    stateStack.pop_back();
                }
            }
        }
        
    }

    
    if (cursor < textLen) {
        RichSpanC span;
        span.text = std::u16string(text + cursor, textLen - cursor);
        span.bold = current.bold;
        span.italic = current.italic;
        span.underline = current.underline;
        span.lineThrough = current.lineThrough;
        span.color = current.color;
        span.fontSize = current.fontSize;
        span.linkUrl = current.linkUrl;
        if (!span.text.empty()) spans.push_back(std::move(span));
    }

    
    spans.erase(std::remove_if(spans.begin(), spans.end(),
        [](const RichSpanC& s) { return s.text.empty(); }), spans.end());

    return spans;
}





static const char16_t RES_PREFIX[] = u"https://res.lightnovel.fun/";
static const size_t RES_PREFIX_LEN = 26;

static void extractImageUrls(const char16_t* json, size_t jsonLen,
                             std::vector<std::u16string>& out) {
    
    
    for (size_t i = 0; i + RES_PREFIX_LEN < jsonLen; ) {
        if (!u16_starts_with_ci(json + i, jsonLen - i, RES_PREFIX, RES_PREFIX_LEN)) {
            i++;
            continue;
        }

        
        size_t urlStart = i;
        size_t j = i + RES_PREFIX_LEN;
        while (j < jsonLen && json[j] != u'"' && json[j] != u'\'' &&
               json[j] != u'\\' && json[j] > u' ') j++;

        std::u16string url(json + urlStart, j - urlStart);

        
        bool hasImageExt = false;
        std::u16string lower;
        for (auto c : url) lower += u16_tolower(c);
        if (lower.find(u".jpg") != std::u16string::npos ||
            lower.find(u".jpeg") != std::u16string::npos ||
            lower.find(u".png") != std::u16string::npos ||
            lower.find(u".webp") != std::u16string::npos ||
            lower.find(u".gif") != std::u16string::npos) {
            hasImageExt = true;
        }

        
        bool hasPath = false;
        if (lower.find(u"/images/") != std::u16string::npos ||
            lower.find(u"/attach/") != std::u16string::npos) {
            hasPath = true;
        }

        if (hasImageExt && hasPath) {
            
            bool dup = false;
            for (const auto& existing : out) {
                if (existing == url) { dup = true; break; }
            }
            if (!dup) out.push_back(std::move(url));
        }

        i = j;
    }
}





static std::vector<ContentItemC> parseArticle(
    const char16_t* raw, size_t rawLen,
    const char16_t* fullJson, size_t jsonLen)
{
    std::vector<ContentItemC> items;
    if (rawLen == 0) return items;

    
    std::vector<std::u16string> imageUrls;
    if (jsonLen > 0) {
        extractImageUrls(fullJson, jsonLen, imageUrls);
    }
    size_t imageIndex = 0;

    
    

    struct Paragraph {
        int type;   
        std::u16string content;
    };
    std::vector<Paragraph> paragraphs;

    
    std::u16string currentPara;
    currentPara.reserve(256);

    auto flushPara = [&]() {
        
        size_t start = 0, end = currentPara.size();
        while (start < end && (currentPara[start] == u' ' || currentPara[start] == u'\t')) start++;
        while (end > start && (currentPara[end-1] == u' ' || currentPara[end-1] == u'\t')) end--;
        if (start < end) {
            Paragraph p;
            p.type = 0;
            p.content = currentPara.substr(start, end - start);
            paragraphs.push_back(std::move(p));
        }
        currentPara.clear();
    };

    auto pushImagePara = [&](const std::u16string& val) {
        flushPara();
        Paragraph p;
        p.type = 1;
        p.content = val;
        paragraphs.push_back(std::move(p));
    };

    auto pushLinkPara = [&](const std::u16string& url) {
        flushPara();
        Paragraph p;
        p.type = 2;
        p.content = url;
        paragraphs.push_back(std::move(p));
    };

    size_t pos = 0;
    while (pos < rawLen) {
        char16_t c = raw[pos];

        
        if (c == u'\n') {
            flushPara();
            pos++;
            continue;
        }
        if (c == u'\r') {
            pos++;
            if (pos < rawLen && raw[pos] == u'\n') pos++;
            flushPara();
            continue;
        }

        
        if (c == u'<') {
            size_t tagStart = pos;
            pos++; 

            
            bool htmlClosing = false;
            if (pos < rawLen && raw[pos] == u'/') { htmlClosing = true; pos++; }

            
            size_t htmlNameStart = pos;
            while (pos < rawLen && raw[pos] != u'>' && raw[pos] != u' ' &&
                   raw[pos] != u'/' && raw[pos] != u'\t') pos++;
            size_t htmlNameLen = pos - htmlNameStart;

            if (htmlNameLen == 0) {
                
                currentPara += u'<';
                pos = tagStart + 1;
                continue;
            }

            
            size_t closeAngle = pos;
            while (closeAngle < rawLen && raw[closeAngle] != u'>') closeAngle++;
            if (closeAngle >= rawLen) {
                
                currentPara += u'<';
                pos = tagStart + 1;
                continue;
            }

            
            size_t htmlTagLen = closeAngle - tagStart + 1;

            
            char16_t lcName[16];
            size_t lcLen = htmlNameLen < 15 ? htmlNameLen : 15;
            for (size_t k = 0; k < lcLen; k++) lcName[k] = u16_tolower(raw[htmlNameStart + k]);

            #define HTML_IS(lit) (lcLen == (sizeof(lit)/2 - 1) && memcmp(lcName, lit, lcLen * 2) == 0)

            if (HTML_IS(u"br")) {
                
                flushPara();
                pos = closeAngle + 1;
            }
            else if (HTML_IS(u"img")) {
                
                std::u16string src = extractSrcAttr(raw + tagStart, htmlTagLen);
                if (!src.empty()) {
                    pushImagePara(src);
                }
                pos = closeAngle + 1;
            }
            else if (HTML_IS(u"iframe")) {
                if (!htmlClosing) {
                    std::u16string src = extractSrcAttr(raw + tagStart, htmlTagLen);
                    
                    
                    size_t endIframe = closeAngle + 1;
                    
                    for (size_t k = endIframe; k + 8 < rawLen; k++) {
                        if (raw[k] == u'<' && raw[k+1] == u'/' &&
                            u16_tolower(raw[k+2]) == u'i' && u16_tolower(raw[k+3]) == u'f') {
                            
                            size_t kEnd = k;
                            while (kEnd < rawLen && raw[kEnd] != u'>') kEnd++;
                            endIframe = kEnd + 1;
                            break;
                        }
                    }
                    if (!src.empty()) {
                        std::u16string url = src;
                        if (url.size() >= 2 && url[0] == u'/' && url[1] == u'/') {
                            url = u"https:" + url;
                        }
                        pushLinkPara(url);
                    }
                    pos = endIframe;
                } else {
                    pos = closeAngle + 1;
                }
            }
            else if (HTML_IS(u"p") || HTML_IS(u"div") || HTML_IS(u"span") ||
                     HTML_IS(u"strong") || HTML_IS(u"em") ||
                     HTML_IS(u"b") || HTML_IS(u"i") || HTML_IS(u"u") ||
                     HTML_IS(u"s") || HTML_IS(u"del") || HTML_IS(u"ins") ||
                     HTML_IS(u"a") || HTML_IS(u"font") || HTML_IS(u"center") ||
                     HTML_IS(u"blockquote") || HTML_IS(u"pre") || HTML_IS(u"code") ||
                     HTML_IS(u"h1") || HTML_IS(u"h2") || HTML_IS(u"h3") ||
                     HTML_IS(u"h4") || HTML_IS(u"h5") || HTML_IS(u"h6")) {
                
                pos = closeAngle + 1;
            }
            else {
                
                currentPara += u'<';
                pos = tagStart + 1;
            }
            #undef HTML_IS
            continue;
        }

        
        if (c == u'[') {
            size_t bbStart = pos;
            pos++; 

            bool bbClosing = false;
            if (pos < rawLen && raw[pos] == u'/') { bbClosing = true; pos++; }

            size_t nameStart = pos;
            while (pos < rawLen && raw[pos] != u']' && raw[pos] != u'=') pos++;
            size_t nameLen = pos - nameStart;

            if (nameLen == 0 || pos >= rawLen) {
                currentPara += u'[';
                pos = bbStart + 1;
                continue;
            }

            
            const char16_t* paramPtr = nullptr;
            size_t paramLen = 0;
            if (raw[pos] == u'=') {
                pos++;
                paramPtr = raw + pos;
                while (pos < rawLen && raw[pos] != u']') pos++;
                paramLen = (raw + pos) - paramPtr;
            }

            if (pos >= rawLen || raw[pos] != u']') {
                currentPara += u'[';
                pos = bbStart + 1;
                continue;
            }
            pos++; 

            
            char16_t lcN[16];
            size_t lcNLen = nameLen < 15 ? nameLen : 15;
            for (size_t k = 0; k < lcNLen; k++) lcN[k] = u16_tolower(raw[nameStart + k]);

            #define BB_IS(lit) (lcNLen == (sizeof(lit)/2 - 1) && memcmp(lcN, lit, lcNLen * 2) == 0)

            if (!bbClosing && (BB_IS(u"img") || BB_IS(u"res"))) {
                
                
                size_t contentStart = pos;
                const char16_t* closeTag = BB_IS(u"img") ? u"[/img]" : u"[/res]";
                size_t closeTagLen = 6;
                size_t contentEnd = contentStart;
                bool found = false;
                for (size_t k = contentStart; k + closeTagLen <= rawLen; k++) {
                    if (raw[k] == u'[' && raw[k+1] == u'/' &&
                        u16_tolower(raw[k+2]) == closeTag[2] &&
                        u16_tolower(raw[k+3]) == closeTag[3] &&
                        u16_tolower(raw[k+4]) == closeTag[4] &&
                        raw[k+5] == u']') {
                        contentEnd = k;
                        found = true;
                        break;
                    }
                }
                if (found) {
                    std::u16string imgVal(raw + contentStart, contentEnd - contentStart);
                    pushImagePara(imgVal);
                    pos = contentEnd + closeTagLen;
                } else {
                    
                    currentPara.append(raw + bbStart, pos - bbStart);
                }
                continue;
            }

            if (!bbClosing && BB_IS(u"media")) {
                
                size_t contentStart = pos;
                size_t contentEnd = contentStart;
                bool found = false;
                for (size_t k = contentStart; k + 8 <= rawLen; k++) {
                    if (raw[k] == u'[' && raw[k+1] == u'/' &&
                        u16_tolower(raw[k+2]) == u'm' && u16_tolower(raw[k+3]) == u'e' &&
                        u16_tolower(raw[k+4]) == u'd' && u16_tolower(raw[k+5]) == u'i' &&
                        u16_tolower(raw[k+6]) == u'a' && raw[k+7] == u']') {
                        contentEnd = k;
                        found = true;
                        break;
                    }
                }
                if (found) {
                    std::u16string linkUrl(raw + contentStart, contentEnd - contentStart);
                    pushLinkPara(linkUrl);
                    pos = contentEnd + 8; 
                } else {
                    currentPara.append(raw + bbStart, pos - bbStart);
                }
                continue;
            }

            
            if (lcNLen == 1 && lcN[0] == u'*' && !bbClosing) {
                
                
                
                currentPara += u'\u2022';
                currentPara += u' ';
                continue;
            }

            #undef BB_IS

            
            
            currentPara.append(raw + bbStart, pos - bbStart);
            continue;
        }

        
        currentPara += c;
        pos++;
    }

    
    flushPara();

    
    for (auto& para : paragraphs) {
        if (para.type == 1) {
            
            ContentItemC item;
            item.type = 1;
            item.value = para.content;

            if (para.content.size() > 4 &&
                u16_tolower(para.content[0]) == u'h' &&
                u16_tolower(para.content[1]) == u't' &&
                u16_tolower(para.content[2]) == u't' &&
                u16_tolower(para.content[3]) == u'p') {
                
                item.url = u"https://wsrv.nl/?url=";
                
                
                for (auto ch : para.content) {
                    
                    if (ch == u' ') { item.url += u"%20"; }
                    else if (ch == u'#') { item.url += u"%23"; }
                    else if (ch == u'&') { item.url += u"%26"; }
                    else if (ch == u'?') { item.url += u"%3F"; }
                    else if (ch == u'=') { item.url += u"%3D"; }
                    else if (ch == u'+') { item.url += u"%2B"; }
                    else if (ch == u'%') { item.url += u"%25"; }
                    else item.url += ch;
                }
                items.push_back(std::move(item));
            } else if (imageIndex < imageUrls.size()) {
                item.url = imageUrls[imageIndex++];
                items.push_back(std::move(item));
            }
        }
        else if (para.type == 2) {
            
            std::u16string linkUrl = para.content;
            bool isUrl = false;
            if (linkUrl.size() >= 7 &&
                (u16_starts_with_ci(linkUrl.data(), linkUrl.size(), HTTP_PREFIX, 7) ||
                 u16_starts_with_ci(linkUrl.data(), linkUrl.size(), HTTPS_PREFIX, 8))) {
                isUrl = true;
            }
            if (linkUrl.size() >= 2 && linkUrl[0] == u'/' && linkUrl[1] == u'/') {
                linkUrl = u"https:" + linkUrl;
                isUrl = true;
            }
            if (isUrl) {
                ContentItemC item;
                item.type = 2;
                item.value = extractDomain(linkUrl);
                item.url = linkUrl;
                items.push_back(std::move(item));
            }
        }
        else {
            
            auto spans = parseBBCodeSpans(para.content.data(), para.content.size());
            if (!spans.empty()) {
                detectLinksInSpans(spans);

                ContentItemC item;
                item.type = 0;
                
                for (const auto& sp : spans) item.value += sp.text;
                item.spans = std::move(spans);
                items.push_back(std::move(item));
            }
        }
    }

    return items;
}





static std::vector<ContentItemC> parseComment(const char16_t* content, size_t contentLen) {
    if (contentLen == 0) return {};

    std::vector<ContentItemC> items;

    
    size_t lastIndex = 0;
    bool hasImg = false;

    
    for (size_t i = 0; i + 4 < contentLen; i++) {
        if (content[i] == u'<' &&
            u16_tolower(content[i+1]) == u'i' &&
            u16_tolower(content[i+2]) == u'm' &&
            u16_tolower(content[i+3]) == u'g') {
            hasImg = true;
            break;
        }
    }

    if (!hasImg) {
        
        
        std::u16string processed;
        processed.reserve(contentLen);
        for (size_t i = 0; i < contentLen; ) {
            if (content[i] == u'<' && i + 2 < contentLen &&
                u16_tolower(content[i+1]) == u'b' && u16_tolower(content[i+2]) == u'r') {
                
                size_t j = i + 3;
                while (j < contentLen && content[j] != u'>') j++;
                if (j < contentLen) j++; 
                processed += u'\n';
                i = j;
            } else {
                processed += content[i];
                i++;
            }
        }

        auto spans = parseBBCodeSpans(processed.data(), processed.size());
        if (!spans.empty()) {
            detectLinksInSpans(spans);
            ContentItemC item;
            item.type = 0;
            for (const auto& sp : spans) item.value += sp.text;
            item.spans = std::move(spans);
            items.push_back(std::move(item));
        }
        return items;
    }

    
    
    std::u16string processed;
    processed.reserve(contentLen);
    for (size_t i = 0; i < contentLen; ) {
        if (content[i] == u'<' && i + 2 < contentLen &&
            u16_tolower(content[i+1]) == u'b' && u16_tolower(content[i+2]) == u'r') {
            size_t j = i + 3;
            while (j < contentLen && content[j] != u'>') j++;
            if (j < contentLen) j++;
            processed += u'\n';
            i = j;
        } else {
            processed += content[i];
            i++;
        }
    }

    const char16_t* p = processed.data();
    size_t pLen = processed.size();
    lastIndex = 0;

    for (size_t i = 0; i < pLen; ) {
        if (p[i] != u'<' || i + 4 >= pLen) { i++; continue; }
        if (u16_tolower(p[i+1]) != u'i' || u16_tolower(p[i+2]) != u'm' || u16_tolower(p[i+3]) != u'g') {
            i++; continue;
        }

        
        size_t imgTagStart = i;

        
        if (imgTagStart > lastIndex) {
            std::u16string textPart(p + lastIndex, imgTagStart - lastIndex);
            
            size_t ts = 0, te = textPart.size();
            while (ts < te && (textPart[ts] == u' ' || textPart[ts] == u'\t' || textPart[ts] == u'\n')) ts++;
            while (te > ts && (textPart[te-1] == u' ' || textPart[te-1] == u'\t' || textPart[te-1] == u'\n')) te--;
            if (ts < te) {
                std::u16string trimmed = textPart.substr(ts, te - ts);
                auto spans = parseBBCodeSpans(trimmed.data(), trimmed.size());
                if (!spans.empty()) {
                    detectLinksInSpans(spans);
                    ContentItemC item;
                    item.type = 0;
                    for (const auto& sp : spans) item.value += sp.text;
                    item.spans = std::move(spans);
                    items.push_back(std::move(item));
                }
            }
        }

        
        size_t closeAngle = i;
        while (closeAngle < pLen && p[closeAngle] != u'>') closeAngle++;
        if (closeAngle >= pLen) { i++; continue; }

        
        std::u16string src = extractSrcAttr(p + imgTagStart, closeAngle - imgTagStart + 1);
        if (!src.empty()) {
            ContentItemC imgItem;
            imgItem.type = 1;
            imgItem.value = src;
            if (src.size() > 4 &&
                u16_tolower(src[0]) == u'h' && u16_tolower(src[1]) == u't') {
                imgItem.url = u"https://wsrv.nl/?url=";
                for (auto ch : src) {
                    if (ch == u' ') imgItem.url += u"%20";
                    else if (ch == u'#') imgItem.url += u"%23";
                    else if (ch == u'&') imgItem.url += u"%26";
                    else if (ch == u'?') imgItem.url += u"%3F";
                    else if (ch == u'=') imgItem.url += u"%3D";
                    else if (ch == u'+') imgItem.url += u"%2B";
                    else if (ch == u'%') imgItem.url += u"%25";
                    else imgItem.url += ch;
                }
            } else {
                imgItem.url = src;
            }
            items.push_back(std::move(imgItem));
        }

        lastIndex = closeAngle + 1;
        i = lastIndex;
    }

    
    if (lastIndex < pLen) {
        std::u16string textPart(p + lastIndex, pLen - lastIndex);
        size_t ts = 0, te = textPart.size();
        while (ts < te && (textPart[ts] == u' ' || textPart[ts] == u'\t' || textPart[ts] == u'\n')) ts++;
        while (te > ts && (textPart[te-1] == u' ' || textPart[te-1] == u'\t' || textPart[te-1] == u'\n')) te--;
        if (ts < te) {
            std::u16string trimmed = textPart.substr(ts, te - ts);
            auto spans = parseBBCodeSpans(trimmed.data(), trimmed.size());
            if (!spans.empty()) {
                detectLinksInSpans(spans);
                ContentItemC item;
                item.type = 0;
                for (const auto& sp : spans) item.value += sp.text;
                item.spans = std::move(spans);
                items.push_back(std::move(item));
            }
        }
    }

    return items;
}





static napi_value NapiParseArticle(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    
    size_t rawLen = 0;
    if (argc < 1 || napi_get_value_string_utf16(env, args[0], nullptr, 0, &rawLen) != napi_ok || rawLen == 0) {
        napi_value empty;
        napi_create_string_utf8(env, "[]", 2, &empty);
        return empty;
    }

    std::unique_ptr<char16_t[]> rawBuf(new char16_t[rawLen + 1]);
    napi_get_value_string_utf16(env, args[0], rawBuf.get(), rawLen + 1, &rawLen);

    
    size_t jsonLen = 0;
    std::unique_ptr<char16_t[]> jsonBuf;
    if (argc >= 2 && napi_get_value_string_utf16(env, args[1], nullptr, 0, &jsonLen) == napi_ok && jsonLen > 0) {
        jsonBuf.reset(new char16_t[jsonLen + 1]);
        napi_get_value_string_utf16(env, args[1], jsonBuf.get(), jsonLen + 1, &jsonLen);
    }

    auto items = parseArticle(rawBuf.get(), rawLen,
                              jsonBuf ? jsonBuf.get() : nullptr, jsonLen);

    JsonWriter jw;
    serializeContentItems(items, jw);

    napi_value result;
    napi_create_string_utf8(env, jw.buf.c_str(), jw.buf.size(), &result);
    return result;
}





static napi_value NapiParseComment(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t contentLen = 0;
    if (argc < 1 || napi_get_value_string_utf16(env, args[0], nullptr, 0, &contentLen) != napi_ok || contentLen == 0) {
        napi_value empty;
        napi_create_string_utf8(env, "[]", 2, &empty);
        return empty;
    }

    std::unique_ptr<char16_t[]> buf(new char16_t[contentLen + 1]);
    napi_get_value_string_utf16(env, args[0], buf.get(), contentLen + 1, &contentLen);

    auto items = parseComment(buf.get(), contentLen);

    JsonWriter jw;
    serializeContentItems(items, jw);

    napi_value result;
    napi_create_string_utf8(env, jw.buf.c_str(), jw.buf.size(), &result);
    return result;
}





static napi_value NapiAdaptColor(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) return args[0];

    bool isDark = false;
    napi_get_value_bool(env, args[1], &isDark);

    size_t hexLen = 0;
    if (napi_get_value_string_utf16(env, args[0], nullptr, 0, &hexLen) != napi_ok || hexLen == 0) {
        return args[0];
    }

    std::unique_ptr<char16_t[]> hexBuf(new char16_t[hexLen + 1]);
    napi_get_value_string_utf16(env, args[0], hexBuf.get(), hexLen + 1, &hexLen);

    std::u16string result = adaptColorForDarkMode(hexBuf.get(), hexLen, isDark);

    napi_value jsResult;
    napi_create_string_utf16(env, result.c_str(), result.size(), &jsResult);
    return jsResult;
}





static napi_value NapiParseBBCode(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t textLen = 0;
    if (argc < 1 || napi_get_value_string_utf16(env, args[0], nullptr, 0, &textLen) != napi_ok || textLen == 0) {
        napi_value empty;
        napi_create_string_utf8(env, "[]", 2, &empty);
        return empty;
    }

    std::unique_ptr<char16_t[]> buf(new char16_t[textLen + 1]);
    napi_get_value_string_utf16(env, args[0], buf.get(), textLen + 1, &textLen);

    auto spans = parseBBCodeSpans(buf.get(), textLen);
    detectLinksInSpans(spans);

    
    JsonWriter jw;
    jw.beginArray();
    for (size_t i = 0; i < spans.size(); i++) {
        if (i > 0) jw.comma();
        const auto& sp = spans[i];
        jw.beginObject();
        jw.key("text"); jw.valStr(sp.text);
        jw.comma(); jw.key("bold"); jw.valBool(sp.bold);
        jw.comma(); jw.key("italic"); jw.valBool(sp.italic);
        jw.comma(); jw.key("underline"); jw.valBool(sp.underline);
        jw.comma(); jw.key("lineThrough"); jw.valBool(sp.lineThrough);
        jw.comma(); jw.key("color"); jw.valStr(sp.color);
        jw.comma(); jw.key("fontSize"); jw.valInt(sp.fontSize);
        jw.comma(); jw.key("linkUrl"); jw.valStr(sp.linkUrl);
        jw.endObject();
    }
    jw.endArray();

    napi_value result;
    napi_create_string_utf8(env, jw.buf.c_str(), jw.buf.size(), &result);
    return result;
}





extern "C" {
static napi_value Init(napi_env env, napi_value exports) {
    napi_value parseArticleFn, parseCommentFn, adaptColorFn, parseBBCodeFn;
    napi_create_function(env, "parseArticle", NAPI_AUTO_LENGTH, NapiParseArticle, nullptr, &parseArticleFn);
    napi_create_function(env, "parseComment", NAPI_AUTO_LENGTH, NapiParseComment, nullptr, &parseCommentFn);
    napi_create_function(env, "adaptColor", NAPI_AUTO_LENGTH, NapiAdaptColor, nullptr, &adaptColorFn);
    napi_create_function(env, "parseBBCode", NAPI_AUTO_LENGTH, NapiParseBBCode, nullptr, &parseBBCodeFn);

    
    napi_set_named_property(env, exports, "parseArticle", parseArticleFn);
    napi_set_named_property(env, exports, "parseComment", parseCommentFn);
    napi_set_named_property(env, exports, "adaptColor", adaptColorFn);
    napi_set_named_property(env, exports, "parseBBCode", parseBBCodeFn);

    
    napi_value newExports;
    napi_create_object(env, &newExports);
    napi_property_descriptor props[] = {
        {"parseArticle", nullptr, NapiParseArticle, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"parseComment", nullptr, NapiParseComment, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"adaptColor", nullptr, NapiAdaptColor, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"parseBBCode", nullptr, NapiParseBBCode, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
    };
    napi_define_properties(env, newExports, 4, props);

    return newExports;
}
}

static napi_module articleParserModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "article_parser",
    .nm_priv = ((void*)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterArticleParserModule(void) {
    napi_module_register(&articleParserModule);
}
