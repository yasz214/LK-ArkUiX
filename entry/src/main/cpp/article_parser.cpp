

#ifndef __ANDROID__
#include "bisheng_fix.h"
#endif
#include <memory>
#include <vector>
#include <string>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <ctime>
#include <algorithm>
#include <napi/native_api.h>

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
    
    void reserveFor(size_t inputChars) { buf.reserve(inputChars * 3); }

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
        appendEscapedU16(s.data(), s.size());
        buf += '"';
    }

    void valEmptyStr() {
        buf += "\"\"";
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

    
    

    
    
    void appendEscapedU16(const char16_t* s, size_t len) {
        size_t i = 0;
        while (i < len) {
            char16_t c = s[i];

            
            if (c >= 0x20 && c < 0x80 && c != u'"' && c != u'\\') {
                size_t runStart = i;
                i++;
                while (i < len) {
                    c = s[i];
                    if (c < 0x20 || c >= 0x80 || c == u'"' || c == u'\\') break;
                    i++;
                }
                size_t runLen = i - runStart;
                size_t oldSize = buf.size();
                buf.resize(oldSize + runLen);
                char* dst = &buf[oldSize];
                const char16_t* src = &s[runStart];
                for (size_t k = 0; k < runLen; k++) dst[k] = (char)src[k];
                continue;
            }

            
            if (c >= 0x80 && !(c >= 0xD800 && c <= 0xDFFF)) {
                size_t runStart = i;
                i++;
                while (i < len) {
                    c = s[i];
                    if (c < 0x80 || (c >= 0xD800 && c <= 0xDFFF)) break;
                    i++;
                }
                size_t runLen = i - runStart;
                size_t oldSize = buf.size();
                buf.resize(oldSize + runLen * 3);
                char* dst = &buf[oldSize];
                size_t w = 0;
                for (size_t k = 0; k < runLen; k++) {
                    char16_t ch = s[runStart + k];
                    if (ch < 0x800) {
                        dst[w++] = (char)(0xC0 | (ch >> 6));
                        dst[w++] = (char)(0x80 | (ch & 0x3F));
                    } else {
                        dst[w++] = (char)(0xE0 | (ch >> 12));
                        dst[w++] = (char)(0x80 | ((ch >> 6) & 0x3F));
                        dst[w++] = (char)(0x80 | (ch & 0x3F));
                    }
                }
                buf.resize(oldSize + w);
                continue;
            }

            
            if (c == u'"') { buf += "\\\""; }
            else if (c == u'\\') { buf += "\\\\"; }
            else if (c == u'\n') { buf += "\\n"; }
            else if (c == u'\r') { buf += "\\r"; }
            else if (c == u'\t') { buf += "\\t"; }
            else if (c < 0x20) {
                char esc[8]; snprintf(esc, sizeof(esc), "\\u%04x", (unsigned)c);
                buf += esc;
            }
            else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < len) {
                char16_t hi = c;
                char16_t lo = s[++i];
                if (lo >= 0xDC00 && lo <= 0xDFFF) {
                    uint32_t cp = 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00);
                    buf += (char)(0xF0 | (cp >> 18));
                    buf += (char)(0x80 | ((cp >> 12) & 0x3F));
                    buf += (char)(0x80 | ((cp >> 6) & 0x3F));
                    buf += (char)(0x80 | (cp & 0x3F));
                } else {
                    char esc[8]; snprintf(esc, sizeof(esc), "\\u%04x", (unsigned)hi);
                    buf += esc;
                    i--;
                }
            }
            else {
                char esc[8]; snprintf(esc, sizeof(esc), "\\u%04x", (unsigned)c);
                buf += esc;
            }
            i++;
        }
    }

    void valStr(const char16_t* s, size_t len) {
        buf += '"';
        appendEscapedU16(s, len);
        buf += '"';
    }
};

static napi_value createEmptyString(napi_env env) {
    napi_value strValue;
    napi_create_string_utf8(env, "[]", NAPI_AUTO_LENGTH, &strValue);
    return strValue;
}


static const char16_t HEX_DIGITS[] = u"0123456789abcdef";

static inline std::u16string makeHexColor(int r, int g, int b) {
    std::u16string res(7, u'#');
    res[1] = HEX_DIGITS[(r >> 4) & 0xF]; res[2] = HEX_DIGITS[r & 0xF];
    res[3] = HEX_DIGITS[(g >> 4) & 0xF]; res[4] = HEX_DIGITS[g & 0xF];
    res[5] = HEX_DIGITS[(b >> 4) & 0xF]; res[6] = HEX_DIGITS[b & 0xF];
    return res;
}





struct NamedColor { const char16_t* name; size_t nameLen; const char16_t* hex; };



static const NamedColor NC_B[] = {
    {u"black", 5, u"#000000"}, {u"blue", 4, u"#0000ff"}, {u"brown", 5, u"#a52a2a"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_C[] = {
    {u"cyan", 4, u"#00ffff"}, {u"coral", 5, u"#ff7f50"}, {u"crimson", 7, u"#dc143c"},
    {u"chocolate", 9, u"#d2691e"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_D[] = {
    {u"darkgray", 8, u"#a9a9a9"}, {u"darkgrey", 8, u"#a9a9a9"},
    {u"darkred", 7, u"#8b0000"}, {u"darkblue", 8, u"#00008b"}, {u"darkgreen", 9, u"#006400"},
    {u"darkorange", 10, u"#ff8c00"}, {u"dimgray", 7, u"#696969"}, {u"dimgrey", 7, u"#696969"},
    {u"deepskyblue", 11, u"#00bfff"}, {u"dodgerblue", 10, u"#1e90ff"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_F[] = {
    {u"firebrick", 9, u"#b22222"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_G[] = {
    {u"gray", 4, u"#808080"}, {u"grey", 4, u"#808080"}, {u"green", 5, u"#008000"},
    {u"gold", 4, u"#ffd700"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_I[] = {
    {u"indianred", 9, u"#cd5c5c"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_L[] = {
    {u"lightgray", 9, u"#d3d3d3"}, {u"lightgrey", 9, u"#d3d3d3"},
    {u"limegreen", 9, u"#32cd32"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_M[] = {
    {u"magenta", 7, u"#ff00ff"}, {u"maroon", 6, u"#800000"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_N[] = {
    {u"navy", 4, u"#000080"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_O[] = {
    {u"orange", 6, u"#ffa500"}, {u"olive", 5, u"#808000"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_P[] = {
    {u"purple", 6, u"#800080"}, {u"pink", 4, u"#ffc0cb"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_R[] = {
    {u"red", 3, u"#ff0000"}, {u"royalblue", 9, u"#4169e1"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_S[] = {
    {u"silver", 6, u"#c0c0c0"}, {u"sienna", 6, u"#a0522d"},
    {u"sandybrown", 10, u"#f4a460"}, {u"steelblue", 9, u"#4682b4"},
    {u"seagreen", 8, u"#2e8b57"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_T[] = {
    {u"teal", 4, u"#008080"}, {u"tomato", 6, u"#ff6347"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_W[] = {
    {u"white", 5, u"#ffffff"},
    {nullptr, 0, nullptr}
};
static const NamedColor NC_Y[] = {
    {u"yellow", 6, u"#ffff00"},
    {nullptr, 0, nullptr}
};

static const NamedColor* NC_BUCKETS[26] = {
    nullptr,  NC_B, NC_C, NC_D, nullptr, NC_F, NC_G, nullptr, NC_I,  
    nullptr, nullptr, NC_L, NC_M, NC_N, NC_O, NC_P, nullptr, NC_R,  
    NC_S, NC_T, nullptr, nullptr, NC_W, nullptr, NC_Y, nullptr       
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
            return makeHexColor(vals[0] & 0xFF, vals[1] & 0xFF, vals[2] & 0xFF);
        }
        return {};
    }

    
    char16_t firstLower = u16_tolower(raw[0]);
    if (firstLower >= u'a' && firstLower <= u'z') {
        const NamedColor* bucket = NC_BUCKETS[firstLower - u'a'];
        if (bucket) {
            for (const NamedColor* nc = bucket; nc->name; nc++) {
                if (nc->nameLen == len && u16_eq_ci(raw, len, nc->name, nc->nameLen)) {
                    return std::u16string(nc->hex);
                }
            }
        }
    }

    
    return std::u16string(raw, len);
}





static int mapSize(const char16_t* raw, size_t len) {
    
    
    while (len > 0 && (*raw == u' ' || *raw == u'\t')) { raw++; len--; }
    while (len > 0 && (raw[len-1] == u' ' || raw[len-1] == u'\t')) len--;
    if (len == 0) return 0;

    
    if (len >= 2) {
        char16_t s0 = u16_tolower(raw[len-2]);
        char16_t s1 = u16_tolower(raw[len-1]);
        if ((s0 == u'p' && (s1 == u'x' || s1 == u't')) ||
            (s0 == u'v' && s1 == u'p')) {
            len -= 2;
        }
    }
    
    while (len > 0 && (raw[len-1] == u' ' || raw[len-1] == u'\t')) len--;
    if (len == 0) return 0;

    
    int intPart = 0;
    bool hasDigit = false;
    size_t i = 0;
    
    if (i < len && raw[i] == u'-') i++;
    for (; i < len; i++) {
        if (raw[i] >= u'0' && raw[i] <= u'9') {
            intPart = intPart * 10 + (raw[i] - u'0');
            hasDigit = true;
        } else if (raw[i] == u'.') {
            
            i++;
            int fracFirst = 0;
            if (i < len && raw[i] >= u'0' && raw[i] <= u'9') {
                fracFirst = raw[i] - u'0';
            }
            if (fracFirst >= 5) intPart++;
            break;
        } else {
            break; 
        }
    }
    if (!hasDigit) return 0;

    
    if (intPart >= 1 && intPart <= 7) {
        
        return SIZE_MAP[intPart - 1];
    }
    if (intPart <= 0) return 0;
    return intPart;
}









struct ColorCacheEntry {
    uint32_t keyHash;
    std::u16string input;
    std::u16string output;
};

static constexpr size_t COLOR_CACHE_BUCKETS = 128;  
static ColorCacheEntry g_colorCache[COLOR_CACHE_BUCKETS];
static bool g_colorCacheDark = false;  


static inline uint32_t colorHash(const char16_t* s, size_t len) {
    uint32_t h = 0x811c9dc5U;
    for (size_t i = 0; i < len; i++) {
        h ^= (uint32_t)s[i];
        h *= 0x01000193U;
    }
    return h;
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
        return makeHexColor(gray, gray, gray);
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

    return makeHexColor(newR, newG, newB);
}


static std::u16string adaptColorCached(const char16_t* hexRaw, size_t hexLen, bool isDark) {
    if (!isDark || hexLen == 0) return std::u16string(hexRaw, hexLen);

    
    if (g_colorCacheDark != isDark) {
        memset(g_colorCache, 0, sizeof(g_colorCache));
        g_colorCacheDark = isDark;
    }

    uint32_t h = colorHash(hexRaw, hexLen);
    size_t bucket = h & (COLOR_CACHE_BUCKETS - 1);
    ColorCacheEntry& entry = g_colorCache[bucket];

    
    if (entry.keyHash == h && entry.input.size() == hexLen &&
        memcmp(entry.input.data(), hexRaw, hexLen * sizeof(char16_t)) == 0) {
        return entry.output;
    }

    
    std::u16string result = adaptColorForDarkMode(hexRaw, hexLen, isDark);
    entry.keyHash = h;
    entry.input = std::u16string(hexRaw, hexLen);
    entry.output = result;
    return result;
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
    TAG_RUBY, 
};

struct TagNameEntry { const char16_t* name; size_t len; BBTagKind kind; };


static inline bool isFormatTag(BBTagKind k) {
    return k == TAG_B || k == TAG_I || k == TAG_U || k == TAG_S
        || k == TAG_STRIKE || k == TAG_COLOR || k == TAG_SIZE || k == TAG_URL
        || k == TAG_RUBY;
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
            if (CMP(u"ruby")) return TAG_RUBY;
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





static const char16_t RES_PREFIX[] = u"https://res.lightnovel.fun/";

static const size_t RES_PREFIX_LEN = 27; 

static void extractImageUrls(const char16_t* json, size_t jsonLen,
                             std::vector<std::u16string>& out) {
    
    constexpr size_t DEDUP_BUCKETS = 64;
    size_t dedupHashes[DEDUP_BUCKETS];
    memset(dedupHashes, 0, sizeof(dedupHashes));

    auto fnvHash = [](const char16_t* s, size_t len) -> size_t {
        size_t h = 0xcbf29ce484222325ULL;
        for (size_t i = 0; i < len; i++) {
            h ^= (size_t)s[i];
            h *= 0x100000001b3ULL;
        }
        return h;
    };

    
    
    
    auto hasImageExt = [](const char16_t* url, size_t len) -> bool {
        if (len < 4) return false;
        for (size_t i = 0; i + 3 < len; i++) {
            if (url[i] == u'.') {
                size_t rem = len - i - 1;
                
                if (rem >= 3) {
                    char16_t c1 = u16_tolower(url[i+1]);
                    char16_t c2 = u16_tolower(url[i+2]);
                    char16_t c3 = u16_tolower(url[i+3]);
                    if ((c1 == u'j' && c2 == u'p' && c3 == u'g') ||
                        (c1 == u'p' && c2 == u'n' && c3 == u'g') ||
                        (c1 == u'g' && c2 == u'i' && c3 == u'f')) {
                        return true;
                    }
                }
                
                if (rem >= 4) {
                    char16_t c1 = u16_tolower(url[i+1]);
                    char16_t c2 = u16_tolower(url[i+2]);
                    char16_t c3 = u16_tolower(url[i+3]);
                    char16_t c4 = u16_tolower(url[i+4]);
                    if ((c1 == u'j' && c2 == u'p' && c3 == u'e' && c4 == u'g') ||
                        (c1 == u'w' && c2 == u'e' && c3 == u'b' && c4 == u'p')) {
                        return true;
                    }
                }
            }
        }
        return false;
    };

    
    auto hasRequiredPath = [](const char16_t* url, size_t len) -> bool {
        if (len < 8) return false;
        for (size_t i = 0; i + 7 < len; i++) {
            if (url[i] == u'/') {
                if (i + 7 < len &&
                    u16_tolower(url[i+1]) == u'i' && u16_tolower(url[i+2]) == u'm' &&
                    u16_tolower(url[i+3]) == u'a' && u16_tolower(url[i+4]) == u'g' &&
                    u16_tolower(url[i+5]) == u'e' && u16_tolower(url[i+6]) == u's' &&
                    url[i+7] == u'/') return true;
                if (i + 7 < len &&
                    u16_tolower(url[i+1]) == u'a' && u16_tolower(url[i+2]) == u't' &&
                    u16_tolower(url[i+3]) == u't' && u16_tolower(url[i+4]) == u'a' &&
                    u16_tolower(url[i+5]) == u'c' && u16_tolower(url[i+6]) == u'h' &&
                    url[i+7] == u'/') return true;
            }
        }
        return false;
    };

    for (size_t i = 0; i + RES_PREFIX_LEN < jsonLen; ) {
        if (!u16_starts_with_ci(json + i, jsonLen - i, RES_PREFIX, RES_PREFIX_LEN)) {
            i++;
            continue;
        }

        size_t urlStart = i;
        size_t j = i + RES_PREFIX_LEN;
        while (j < jsonLen && json[j] != u'"' && json[j] != u'\'' &&
               json[j] != u'\\' && json[j] > u' ') j++;

        size_t urlLen = j - urlStart;

        
        if (hasImageExt(json + urlStart, urlLen) && hasRequiredPath(json + urlStart, urlLen)) {
            size_t h = fnvHash(json + urlStart, urlLen);
            size_t bucket = h & (DEDUP_BUCKETS - 1);
            bool dup = false;
            
            for (size_t probe = 0; probe < 4; probe++) {
                size_t idx = (bucket + probe) & (DEDUP_BUCKETS - 1);
                if (dedupHashes[idx] == 0) {
                    dedupHashes[idx] = h | 1; 
                    break;
                }
                if (dedupHashes[idx] == (h | 1)) {
                    for (const auto& existing : out) {
                        if (existing.size() == urlLen &&
                            memcmp(existing.data(), json + urlStart, urlLen * sizeof(char16_t)) == 0) {
                            dup = true;
                            break;
                        }
                    }
                    break;
                }
            }
            if (!dup) {
                out.emplace_back(json + urlStart, urlLen);
            }
        }

        i = j;
    }
}











struct FmtState {
    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool lineThrough = false;
    int fontSize = 0;
    
    char16_t color[8] = {};
    int colorLen = 0;
    
    const char16_t* linkUrlPtr = nullptr;
    size_t linkUrlLen = 0;
    std::u16string linkUrlOwned; 
    
    const char16_t* rubyPtr = nullptr;
    size_t rubyLen = 0;
    std::u16string rubyOwned;

    void setColor(const std::u16string& s) {
        size_t n = s.size() < 7 ? s.size() : 7;
        memcpy(color, s.data(), n * sizeof(char16_t));
        colorLen = (int)n;
    }
    void clearColor() { colorLen = 0; }
};




static inline void emitFmtAttribs(JsonWriter& jw, const FmtState& st) {
    if (st.bold)         { jw.comma(); jw.key("bold");        jw.valBool(true); }
    if (st.italic)       { jw.comma(); jw.key("italic");      jw.valBool(true); }
    if (st.underline)    { jw.comma(); jw.key("underline");   jw.valBool(true); }
    if (st.lineThrough)  { jw.comma(); jw.key("lineThrough"); jw.valBool(true); }
    if (st.fontSize > 0) { jw.comma(); jw.key("fontSize");    jw.valInt(st.fontSize); }
    jw.comma(); jw.key("color");
    if (st.colorLen > 0) jw.valStr(st.color, st.colorLen); else jw.valEmptyStr();
    jw.comma(); jw.key("linkUrl");
    if (st.linkUrlLen > 0) jw.valStr(st.linkUrlPtr, st.linkUrlLen); else jw.valEmptyStr();
    jw.comma(); jw.key("rubyText");
    if (st.rubyLen > 0) jw.valStr(st.rubyPtr, st.rubyLen); else jw.valEmptyStr();
}



static int emitPlainSpansWithUrls(JsonWriter& jw, const char16_t* text, size_t len,
                                   const FmtState& st, bool firstSpanInItem,
                                   std::string& valueAccum) {
    int written = 0;
    size_t lastIndex = 0;

    
    bool mayHaveUrl = false;
    if (!st.linkUrlLen) { 
        for (size_t k = 0; k + 3 < len; k++) {
            char16_t c0 = text[k];
            if (c0 == u'h' || c0 == u'H') {
                char16_t c1 = u16_tolower(text[k+1]);
                char16_t c2 = u16_tolower(text[k+2]);
                char16_t c3 = u16_tolower(text[k+3]);
                if (c1 == u't' && c2 == u't' && c3 == u'p') { mayHaveUrl = true; break; }
            }
        }
    }

    auto emitSpanSegment = [&](const char16_t* segText, size_t segLen,
                                bool isUrl, const char16_t* urlPtr, size_t urlLen) {
        if (segLen == 0) return;
        if (!firstSpanInItem || written > 0) jw.comma();
        jw.beginObject();
        jw.key("text"); jw.valStr(segText, segLen);
        if (isUrl) {
            jw.comma(); jw.key("underline"); jw.valBool(true);
            if (st.bold)        { jw.comma(); jw.key("bold");        jw.valBool(true); }
            if (st.italic)      { jw.comma(); jw.key("italic");      jw.valBool(true); }
            if (st.lineThrough) { jw.comma(); jw.key("lineThrough"); jw.valBool(true); }
            if (st.fontSize > 0){ jw.comma(); jw.key("fontSize");    jw.valInt(st.fontSize); }
            jw.comma(); jw.key("color");
            if (st.colorLen > 0) jw.valStr(st.color, st.colorLen); else jw.valEmptyStr();
            jw.comma(); jw.key("linkUrl"); jw.valStr(urlPtr, urlLen);
            jw.comma(); jw.key("rubyText");
            if (st.rubyLen > 0) jw.valStr(st.rubyPtr, st.rubyLen); else jw.valEmptyStr();
        } else {
            emitFmtAttribs(jw, st);
        }
        jw.endObject();
        
        for (size_t k = 0; k < segLen; k++) {
            char16_t c = segText[k];
            if (c < 0x80) {
                valueAccum += (char)c;
            } else if (c < 0x800) {
                valueAccum += (char)(0xC0 | (c >> 6));
                valueAccum += (char)(0x80 | (c & 0x3F));
            } else if (c >= 0xD800 && c <= 0xDBFF && k + 1 < segLen) {
                char16_t lo = segText[k + 1];
                if (lo >= 0xDC00 && lo <= 0xDFFF) {
                    uint32_t cp = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00);
                    valueAccum += (char)(0xF0 | (cp >> 18));
                    valueAccum += (char)(0x80 | ((cp >> 12) & 0x3F));
                    valueAccum += (char)(0x80 | ((cp >> 6) & 0x3F));
                    valueAccum += (char)(0x80 | (cp & 0x3F));
                    k++;
                }
            } else {
                valueAccum += (char)(0xE0 | (c >> 12));
                valueAccum += (char)(0x80 | ((c >> 6) & 0x3F));
                valueAccum += (char)(0x80 | (c & 0x3F));
            }
        }
        written++;
    };

    if (!mayHaveUrl) {
        emitSpanSegment(text, len, false, nullptr, 0);
        return written;
    }

    for (size_t pos = 0; pos < len; ) {
        size_t urlLen = findUrlAt(text, pos, len);
        if (urlLen == 0) { pos++; continue; }

        if (pos > lastIndex) {
            emitSpanSegment(text + lastIndex, pos - lastIndex, false, nullptr, 0);
        }
        emitSpanSegment(text + pos, urlLen, true, text + pos, urlLen);
        lastIndex = pos + urlLen;
        pos = lastIndex;
    }
    if (lastIndex == 0) {
        
        emitSpanSegment(text, len, false, nullptr, 0);
    } else if (lastIndex < len) {
        emitSpanSegment(text + lastIndex, len - lastIndex, false, nullptr, 0);
    }
    return written;
}



static int parseBBCodeSpansDirectJson(JsonWriter& jw, const char16_t* text, size_t textLen,
                                      std::string& valueAccum) {
    if (textLen == 0) return 0;

    static const int MAX_STACK = 20;
    FmtState stack[MAX_STACK];
    FmtState current;
    int stackDepth = 0;
    size_t cursor = 0;
    int totalSpans = 0;

    auto emitText = [&](size_t from, size_t to) {
        if (to <= from) return;
        bool first = (totalSpans == 0);
        int n = emitPlainSpansWithUrls(jw, text + from, to - from, current, first, valueAccum);
        totalSpans += n;
    };

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
        if (i < textLen && text[i] == u'=') {
            i++;
            paramStart = text + i;
            while (i < textLen && text[i] != u']') i++;
            paramLen = (text + i) - paramStart;
        }
        while (i < textLen && text[i] != u']') i++;
        if (i >= textLen) { i = tagStart + 1; continue; }
        i++;

        if (kind == TAG_STRIKE) kind = TAG_S;

        
        emitText(cursor, tagStart);
        cursor = i;

        if (isFormatTag(kind)) {
            if (!isClosing) {
                if (stackDepth < MAX_STACK) stack[stackDepth++] = current;
                switch (kind) {
                    case TAG_B: current.bold = true; break;
                    case TAG_I: current.italic = true; break;
                    case TAG_U: current.underline = true; break;
                    case TAG_S: current.lineThrough = true; break;
                    case TAG_COLOR:
                        if (paramLen > 0) {
                            auto nc = normalizeColor(paramStart, paramLen);
                            current.setColor(nc);
                        }
                        break;
                    case TAG_SIZE:
                        if (paramLen > 0) current.fontSize = mapSize(paramStart, paramLen);
                        break;
                    case TAG_URL:
                        if (paramLen > 0) {
                            current.linkUrlOwned.assign(paramStart, paramLen);
                            current.linkUrlPtr = current.linkUrlOwned.data();
                            current.linkUrlLen = paramLen;
                        }
                        break;
                    case TAG_RUBY:
                        if (paramLen > 0) {
                            current.rubyOwned.assign(paramStart, paramLen);
                            current.rubyPtr = current.rubyOwned.data();
                            current.rubyLen = paramLen;
                        }
                        break;
                    default: break;
                }
            } else {
                if (stackDepth > 0) {
                    current = stack[--stackDepth];
                }
            }
        }
    }
    emitText(cursor, textLen);
    return totalSpans;
}


static void parseArticleDirectJson(
    const char16_t* raw, size_t rawLen,
    const char16_t* fullJson, size_t jsonLen,
    JsonWriter& jw)
{
    jw.beginArray();
    if (rawLen == 0) { jw.endArray(); return; }

    
    std::vector<std::u16string> imageUrls;
    size_t imageIndex = 0;
    bool imageUrlsLoaded = false;
    auto ensureImageUrls = [&]() {
        if (!imageUrlsLoaded && jsonLen > 0 && fullJson) {
            extractImageUrls(fullJson, jsonLen, imageUrls);
            imageUrlsLoaded = true;
        }
    };

    
    
    
    std::string paraUtf8;  
    paraUtf8.reserve(512);

    
    
    std::u16string currentPara;
    currentPara.reserve(512);

    int itemCount = 0;

    
    auto pushImageJson = [&](const char16_t* val, size_t valLen) {
        if (itemCount > 0) jw.comma();
        itemCount++;
        jw.beginObject();
        jw.key("type"); jw.valStr("image");
        jw.comma(); jw.key("value"); jw.valStr(val, valLen);

        
        bool isHttp = valLen >= 4 &&
            (u16_tolower(val[0]) == u'h' && u16_tolower(val[1]) == u't' &&
             u16_tolower(val[2]) == u't' && u16_tolower(val[3]) == u'p');

        if (isHttp) {
            jw.comma(); jw.key("url"); jw.buf += '"';
            jw.buf += "https://wsrv.nl/?url=";
            for (size_t k = 0; k < valLen; k++) {
                char16_t c = val[k];
                
                if ((c >= u'A' && c <= u'Z') || (c >= u'a' && c <= u'z') ||
                    (c >= u'0' && c <= u'9') || c == u'-' || c == u'_' ||
                    c == u'.' || c == u'!' || c == u'~' || c == u'*' ||
                    c == u'\'' || c == u'(' || c == u')') {
                    jw.buf += (char)c;
                } else if (c < 0x80) {
                    char esc[4]; snprintf(esc, sizeof(esc), "%%%02X", (unsigned)(uint8_t)c);
                    jw.buf += esc;
                } else if (c < 0x800) {
                    uint8_t b0 = 0xC0 | (c >> 6), b1 = 0x80 | (c & 0x3F);
                    char esc[7]; snprintf(esc, sizeof(esc), "%%%02X%%%02X", b0, b1);
                    jw.buf += esc;
                } else if (c >= 0xD800 && c <= 0xDBFF && k + 1 < valLen) {
                    char16_t lo = val[k + 1];
                    if (lo >= 0xDC00 && lo <= 0xDFFF) {
                        uint32_t cp = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00);
                        uint8_t b0 = 0xF0 | (cp >> 18), b1 = 0x80 | ((cp >> 12) & 0x3F);
                        uint8_t b2 = 0x80 | ((cp >> 6) & 0x3F), b3 = 0x80 | (cp & 0x3F);
                        char esc[13]; snprintf(esc, sizeof(esc), "%%%02X%%%02X%%%02X%%%02X", b0, b1, b2, b3);
                        jw.buf += esc;
                        k++;
                    }
                } else {
                    uint8_t b0 = 0xE0 | (c >> 12), b1 = 0x80 | ((c >> 6) & 0x3F), b2 = 0x80 | (c & 0x3F);
                    char esc[10]; snprintf(esc, sizeof(esc), "%%%02X%%%02X%%%02X", b0, b1, b2);
                    jw.buf += esc;
                }
            }
            jw.buf += '"';
        } else {
            ensureImageUrls();
            if (imageIndex < imageUrls.size()) {
                jw.comma(); jw.key("url");
                jw.valStr(imageUrls[imageIndex++]);
            } else {
                jw.comma(); jw.key("url"); jw.valEmptyStr();
            }
        }
        jw.comma(); jw.key("spans"); jw.beginArray(); jw.endArray();
        jw.endObject();
    };

    
    auto pushLinkJson = [&](std::u16string linkUrl) {
        bool isUrl = linkUrl.size() >= 7 &&
            (u16_starts_with_ci(linkUrl.data(), linkUrl.size(), HTTP_PREFIX, 7) ||
             u16_starts_with_ci(linkUrl.data(), linkUrl.size(), HTTPS_PREFIX, 8));
        if (linkUrl.size() >= 2 && linkUrl[0] == u'/' && linkUrl[1] == u'/') {
            linkUrl = u"https:" + linkUrl;
            isUrl = true;
        }
        if (!isUrl) return;

        if (itemCount > 0) jw.comma();
        itemCount++;
        jw.beginObject();
        jw.key("type"); jw.valStr("link");
        jw.comma(); jw.key("value"); jw.valStr(extractDomain(linkUrl));
        jw.comma(); jw.key("url"); jw.valStr(linkUrl);
        jw.comma(); jw.key("spans"); jw.beginArray(); jw.endArray();
        jw.endObject();
    };

    
    auto flushTextPara = [&]() {
        size_t start = 0, end = currentPara.size();
        while (start < end && (currentPara[start] == u' ' || currentPara[start] == u'\t')) start++;
        while (end > start && (currentPara[end-1] == u' ' || currentPara[end-1] == u'\t')) end--;
        if (start >= end) { currentPara.clear(); return; }

        const char16_t* data = currentPara.data() + start;
        size_t dataLen = end - start;

        
        
        size_t checkpoint = jw.buf.size();
        size_t itemCountCheckpoint = itemCount;

        if (itemCount > 0) jw.comma();
        itemCount++;
        jw.beginObject();
        jw.key("type"); jw.valStr("text");

        
        jw.comma(); jw.key("spans"); jw.beginArray();
        paraUtf8.clear();
        int spanCount = parseBBCodeSpansDirectJson(jw, data, dataLen, paraUtf8);
        jw.endArray();

        if (spanCount == 0) {
            
            jw.buf.resize(checkpoint);
            itemCount = itemCountCheckpoint;
            currentPara.clear();
            return;
        }

        
        jw.comma(); jw.key("value"); jw.buf += '"';
        for (char ch : paraUtf8) {
            if (ch == '"')       jw.buf += "\\\"";
            else if (ch == '\\') jw.buf += "\\\\";
            else if (ch == '\n') jw.buf += "\\n";
            else if (ch == '\r') jw.buf += "\\r";
            else                 jw.buf += ch;
        }
        jw.buf += '"';
        jw.comma(); jw.key("url"); jw.valEmptyStr();

        jw.endObject();
        currentPara.clear();
    };

    size_t pos = 0;
    while (pos < rawLen) {
        char16_t c = raw[pos];

        if (c == u'\n') {
            flushTextPara();
            pos++;
            continue;
        }
        if (c == u'\r') {
            pos++;
            if (pos < rawLen && raw[pos] == u'\n') pos++;
            flushTextPara();
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

            if (htmlNameLen == 0) { currentPara += u'<'; pos = tagStart + 1; continue; }

            size_t closeAngle = pos;
            while (closeAngle < rawLen && raw[closeAngle] != u'>') closeAngle++;
            if (closeAngle >= rawLen) { currentPara += u'<'; pos = tagStart + 1; continue; }

            size_t htmlTagLen = closeAngle - tagStart + 1;
            char16_t lcName[16];
            size_t lcLen = htmlNameLen < 15 ? htmlNameLen : 15;
            for (size_t k = 0; k < lcLen; k++) lcName[k] = u16_tolower(raw[htmlNameStart + k]);

            #define HTML_IS(lit) (lcLen == (sizeof(lit)/2 - 1) && memcmp(lcName, lit, lcLen * 2) == 0)

            if (HTML_IS(u"br")) {
                flushTextPara();
                pos = closeAngle + 1;
            } else if (HTML_IS(u"img")) {
                std::u16string src = extractSrcAttr(raw + tagStart, htmlTagLen);
                if (!src.empty()) {
                    flushTextPara();
                    pushImageJson(src.data(), src.size());
                }
                pos = closeAngle + 1;
            } else if (HTML_IS(u"iframe")) {
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
                        flushTextPara();
                        pushLinkJson(src);
                    }
                    pos = endIframe;
                } else {
                    pos = closeAngle + 1;
                }
            } else if (HTML_IS(u"p") || HTML_IS(u"div") || HTML_IS(u"span") ||
                       HTML_IS(u"strong") || HTML_IS(u"em") ||
                       HTML_IS(u"b") || HTML_IS(u"i") || HTML_IS(u"u") ||
                       HTML_IS(u"s") || HTML_IS(u"del") || HTML_IS(u"ins") ||
                       HTML_IS(u"a") || HTML_IS(u"font") || HTML_IS(u"center") ||
                       HTML_IS(u"blockquote") || HTML_IS(u"pre") || HTML_IS(u"code") ||
                       HTML_IS(u"h1") || HTML_IS(u"h2") || HTML_IS(u"h3") ||
                       HTML_IS(u"h4") || HTML_IS(u"h5") || HTML_IS(u"h6")) {
                pos = closeAngle + 1;
            } else {
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
            if (nameLen == 0 || pos >= rawLen) { currentPara += u'['; pos = bbStart + 1; continue; }

            if (raw[pos] == u'=') { pos++; while (pos < rawLen && raw[pos] != u']') pos++; }
            if (pos >= rawLen || raw[pos] != u']') { currentPara += u'['; pos = bbStart + 1; continue; }
            pos++;

            char16_t lcN[16];
            size_t lcNLen = nameLen < 15 ? nameLen : 15;
            for (size_t k = 0; k < lcNLen; k++) lcN[k] = u16_tolower(raw[nameStart + k]);

            #define BB_IS(lit) (lcNLen == (sizeof(lit)/2 - 1) && memcmp(lcN, lit, lcNLen * 2) == 0)

            if (!bbClosing && (BB_IS(u"img") || BB_IS(u"res"))) {
                size_t contentStart = pos;
                const char16_t* closeTag = BB_IS(u"img") ? u"[/img]" : u"[/res]";
                size_t contentEnd = contentStart;
                bool found = false;
                for (size_t k = contentStart; k + 6 <= rawLen; k++) {
                    if (raw[k] == u'[' && raw[k+1] == u'/' &&
                        u16_tolower(raw[k+2]) == closeTag[2] &&
                        u16_tolower(raw[k+3]) == closeTag[3] &&
                        u16_tolower(raw[k+4]) == closeTag[4] &&
                        raw[k+5] == u']') {
                        contentEnd = k; found = true; break;
                    }
                }
                if (found) {
                    flushTextPara();
                    pushImageJson(raw + contentStart, contentEnd - contentStart);
                    pos = contentEnd + 6;
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
                        contentEnd = k; found = true; break;
                    }
                }
                if (found) {
                    flushTextPara();
                    pushLinkJson(std::u16string(raw + contentStart, contentEnd - contentStart));
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

    flushTextPara();
    jw.endArray();
}





static void parseCommentDirectJson(const char16_t* content, size_t contentLen, JsonWriter& jw) {
    jw.beginArray();
    if (contentLen == 0) { jw.endArray(); return; }

    std::u16string textBuf;
    textBuf.reserve(contentLen);
    int itemCount = 0;
    std::string paraUtf8;
    paraUtf8.reserve(256);

    auto flushTextBuf = [&]() {
        if (textBuf.empty()) return;
        size_t ts = 0, te = textBuf.size();
        while (ts < te && (textBuf[ts] == u' ' || textBuf[ts] == u'\t' || textBuf[ts] == u'\n')) ts++;
        while (te > ts && (textBuf[te-1] == u' ' || textBuf[te-1] == u'\t' || textBuf[te-1] == u'\n')) te--;
        if (ts >= te) { textBuf.clear(); return; }

        size_t checkpoint = jw.buf.size();
        size_t cc = itemCount;

        if (itemCount > 0) jw.comma();
        itemCount++;
        jw.beginObject();
        jw.key("type"); jw.valStr("text");
        jw.comma(); jw.key("spans"); jw.beginArray();
        paraUtf8.clear();
        int spanCount = parseBBCodeSpansDirectJson(jw, textBuf.data() + ts, te - ts, paraUtf8);
        jw.endArray();

        if (spanCount == 0) {
            jw.buf.resize(checkpoint);
            itemCount = cc;
            textBuf.clear();
            return;
        }

        jw.comma(); jw.key("value"); jw.buf += '"';
        for (char ch : paraUtf8) {
            if (ch == '"')       jw.buf += "\\\"";
            else if (ch == '\\') jw.buf += "\\\\";
            else if (ch == '\n') jw.buf += "\\n";
            else if (ch == '\r') jw.buf += "\\r";
            else                 jw.buf += ch;
        }
        jw.buf += '"';
        jw.comma(); jw.key("url"); jw.valEmptyStr();
        jw.endObject();
        textBuf.clear();
    };

    size_t i = 0;
    while (i < contentLen) {
        if (content[i] == u'<' && i + 2 < contentLen &&
            u16_tolower(content[i+1]) == u'b' && u16_tolower(content[i+2]) == u'r') {
            size_t j = i + 3;
            while (j < contentLen && content[j] != u'>') j++;
            if (j < contentLen) j++;
            textBuf += u'\n';
            i = j;
            continue;
        }

        if (content[i] == u'<' && i + 4 < contentLen &&
            u16_tolower(content[i+1]) == u'i' && u16_tolower(content[i+2]) == u'm' &&
            u16_tolower(content[i+3]) == u'g') {
            flushTextBuf();
            size_t closeAngle = i;
            while (closeAngle < contentLen && content[closeAngle] != u'>') closeAngle++;
            if (closeAngle >= contentLen) { textBuf += content[i]; i++; continue; }
            std::u16string src = extractSrcAttr(content + i, closeAngle - i + 1);
            if (!src.empty()) {
                if (itemCount > 0) jw.comma();
                itemCount++;
                jw.beginObject();
                jw.key("type"); jw.valStr("image");
                jw.comma(); jw.key("value"); jw.valStr(src);
                bool isHttp = src.size() > 4 &&
                    u16_tolower(src[0]) == u'h' && u16_tolower(src[1]) == u't';
                if (isHttp) {
                    jw.comma(); jw.key("url"); jw.buf += '"';
                    jw.buf += "https://wsrv.nl/?url=";
                    for (auto ch : src) {
                        if ((ch >= u'A' && ch <= u'Z') || (ch >= u'a' && ch <= u'z') ||
                            (ch >= u'0' && ch <= u'9') || ch == u'-' || ch == u'_' ||
                            ch == u'.' || ch == u'!' || ch == u'~' || ch == u'*' ||
                            ch == u'\'' || ch == u'(' || ch == u')') {
                            jw.buf += (char)ch;
                        } else if (ch < 0x80) {
                            char esc[4]; snprintf(esc, sizeof(esc), "%%%02X", (unsigned)(uint8_t)ch);
                            jw.buf += esc;
                        } else {
                            uint8_t b0 = 0xE0 | (ch >> 12), b1 = 0x80 | ((ch >> 6) & 0x3F), b2 = 0x80 | (ch & 0x3F);
                            char esc[10]; snprintf(esc, sizeof(esc), "%%%02X%%%02X%%%02X", b0, b1, b2);
                            jw.buf += esc;
                        }
                    }
                    jw.buf += '"';
                } else {
                    jw.comma(); jw.key("url"); jw.valStr(src);
                }
                jw.comma(); jw.key("spans"); jw.beginArray(); jw.endArray();
                jw.endObject();
            }
            i = closeAngle + 1;
            continue;
        }

        textBuf += content[i];
        i++;
    }

    flushTextBuf();
    jw.endArray();
}





static napi_value NapiParseArticleJson(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t rawLen = 0;
    if (argc < 1 || napi_get_value_string_utf16(env, args[0], nullptr, 0, &rawLen) != napi_ok || rawLen == 0) {
        return createEmptyString(env);
    }

    std::unique_ptr<char16_t[]> rawBuf(new char16_t[rawLen + 1]);
    napi_get_value_string_utf16(env, args[0], rawBuf.get(), rawLen + 1, &rawLen);

    size_t jsonLen = 0;
    std::unique_ptr<char16_t[]> jsonBuf;
    if (argc >= 2 && napi_get_value_string_utf16(env, args[1], nullptr, 0, &jsonLen) == napi_ok && jsonLen > 0) {
        jsonBuf.reset(new char16_t[jsonLen + 1]);
        napi_get_value_string_utf16(env, args[1], jsonBuf.get(), jsonLen + 1, &jsonLen);
    }

    JsonWriter jw;
    jw.reserveFor(rawLen);
    parseArticleDirectJson(rawBuf.get(), rawLen,
                           jsonBuf ? jsonBuf.get() : nullptr, jsonLen, jw);

    napi_value result;
    napi_create_string_utf8(env, jw.buf.c_str(), jw.buf.size(), &result);
    return result;
}

static napi_value NapiParseCommentJson(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t contentLen = 0;
    if (argc < 1 || napi_get_value_string_utf16(env, args[0], nullptr, 0, &contentLen) != napi_ok || contentLen == 0) {
        return createEmptyString(env);
    }

    std::unique_ptr<char16_t[]> buf(new char16_t[contentLen + 1]);
    napi_get_value_string_utf16(env, args[0], buf.get(), contentLen + 1, &contentLen);

    JsonWriter jw;
    jw.reserveFor(contentLen);
    parseCommentDirectJson(buf.get(), contentLen, jw);

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

    std::u16string result = adaptColorCached(hexBuf.get(), hexLen, isDark);

    napi_value jsResult;
    napi_create_string_utf16(env, result.c_str(), result.size(), &jsResult);
    return jsResult;
}

static napi_value NapiParseBBCodeJson(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    size_t textLen = 0;
    if (argc < 1 || napi_get_value_string_utf16(env, args[0], nullptr, 0, &textLen) != napi_ok || textLen == 0) {
        return createEmptyString(env);
    }

    std::unique_ptr<char16_t[]> buf(new char16_t[textLen + 1]);
    napi_get_value_string_utf16(env, args[0], buf.get(), textLen + 1, &textLen);

    JsonWriter jw;
    jw.reserveFor(textLen);
    std::string valueAccum;
    jw.beginArray();
    parseBBCodeSpansDirectJson(jw, buf.get(), textLen, valueAccum);
    jw.endArray();

    napi_value result;
    napi_create_string_utf8(env, jw.buf.c_str(), jw.buf.size(), &result);
    return result;
}

static napi_value NapiBenchmark(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_value empty;
        napi_create_string_utf8(env, "{\"error\":\"need 3 args\"}", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    
    size_t rawLen = 0;
    if (napi_get_value_string_utf16(env, args[0], nullptr, 0, &rawLen) != napi_ok || rawLen == 0) {
        napi_value empty;
        napi_create_string_utf8(env, "{\"error\":\"empty input\"}", NAPI_AUTO_LENGTH, &empty);
        return empty;
    }

    size_t jsonLen = 0;
    std::unique_ptr<char16_t[]> jsonBuf;
    if (napi_get_value_string_utf16(env, args[1], nullptr, 0, &jsonLen) == napi_ok && jsonLen > 0) {
        jsonBuf.reset(new char16_t[jsonLen + 1]);
        napi_get_value_string_utf16(env, args[1], jsonBuf.get(), jsonLen + 1, &jsonLen);
    }

    int32_t iterations = 1;
    napi_get_value_int32(env, args[2], &iterations);
    if (iterations < 1) iterations = 1;
    if (iterations > 1000) iterations = 1000;

    std::unique_ptr<char16_t[]> rawBuf(new char16_t[rawLen + 1]);
    napi_get_value_string_utf16(env, args[0], rawBuf.get(), rawLen + 1, &rawLen);

    struct timespec start, end;

    
    JsonWriter jwSample;
    jwSample.reserveFor(rawLen);
    parseArticleDirectJson(rawBuf.get(), rawLen,
                           jsonBuf ? jsonBuf.get() : nullptr, jsonLen, jwSample);
    size_t jsonOutputLen = jwSample.buf.size();

    
    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int32_t i = 0; i < iterations; i++) {
        size_t rLen = 0;
        napi_get_value_string_utf16(env, args[0], nullptr, 0, &rLen);
        std::unique_ptr<char16_t[]> tmp(new char16_t[rLen + 1]);
        napi_get_value_string_utf16(env, args[0], tmp.get(), rLen + 1, &rLen);
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    double napiReadMs = (end.tv_sec - start.tv_sec) * 1000.0 +
                        (end.tv_nsec - start.tv_nsec) / 1000000.0;

    
    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int32_t i = 0; i < iterations; i++) {
        napi_value tmp;
        napi_create_string_utf8(env, jwSample.buf.c_str(), jwSample.buf.size(), &tmp);
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    double napiWriteMs = (end.tv_sec - start.tv_sec) * 1000.0 +
                         (end.tv_nsec - start.tv_nsec) / 1000000.0;

    
    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int32_t i = 0; i < iterations; i++) {
        JsonWriter jw;
        jw.reserveFor(rawLen);
        parseArticleDirectJson(rawBuf.get(), rawLen,
                               jsonBuf ? jsonBuf.get() : nullptr, jsonLen, jw);
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    double directMs = (end.tv_sec - start.tv_sec) * 1000.0 +
                      (end.tv_nsec - start.tv_nsec) / 1000000.0;

    
    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int32_t i = 0; i < iterations; i++) {
        size_t rLen2 = 0;
        napi_get_value_string_utf16(env, args[0], nullptr, 0, &rLen2);
        std::unique_ptr<char16_t[]> rb2(new char16_t[rLen2 + 1]);
        napi_get_value_string_utf16(env, args[0], rb2.get(), rLen2 + 1, &rLen2);
        JsonWriter jw2;
        jw2.reserveFor(rLen2);
        parseArticleDirectJson(rb2.get(), rLen2, jsonBuf ? jsonBuf.get() : nullptr, jsonLen, jw2);
        napi_value tmp2;
        napi_create_string_utf8(env, jw2.buf.c_str(), jw2.buf.size(), &tmp2);
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    double fullNapiMs = (end.tv_sec - start.tv_sec) * 1000.0 +
                        (end.tv_nsec - start.tv_nsec) / 1000000.0;

    char resultBuf[512];
    snprintf(resultBuf, sizeof(resultBuf),
        "{\"directMs\":%.3f,\"fullNapiMs\":%.3f,"
        "\"napiReadMs\":%.3f,\"napiWriteMs\":%.3f,\"jsonOutputBytes\":%zu,"
        "\"avgDirectUs\":%.3f,\"avgFullNapiUs\":%.3f,"
        "\"avgNapiReadUs\":%.3f,\"avgNapiWriteUs\":%.3f,"
        "\"iterations\":%d,\"charCount\":%zu}",
        directMs, fullNapiMs,
        napiReadMs, napiWriteMs, jsonOutputLen,
        (directMs * 1000.0) / iterations,
        (fullNapiMs * 1000.0) / iterations,
        (napiReadMs * 1000.0) / iterations,
        (napiWriteMs * 1000.0) / iterations,
        iterations, rawLen);

    napi_value result;
    napi_create_string_utf8(env, resultBuf, strlen(resultBuf), &result);
    return result;
}





extern "C" {
static napi_value Init(napi_env env, napi_value exports) {
    napi_value parseArticleJsonFn, parseCommentJsonFn,
        adaptColorFn, parseBBCodeJsonFn, benchmarkFn;
    napi_create_function(env, "parseArticleJson", NAPI_AUTO_LENGTH, NapiParseArticleJson, nullptr, &parseArticleJsonFn);
    napi_create_function(env, "parseCommentJson", NAPI_AUTO_LENGTH, NapiParseCommentJson, nullptr, &parseCommentJsonFn);
    napi_create_function(env, "adaptColor", NAPI_AUTO_LENGTH, NapiAdaptColor, nullptr, &adaptColorFn);
    napi_create_function(env, "parseBBCodeJson", NAPI_AUTO_LENGTH, NapiParseBBCodeJson, nullptr, &parseBBCodeJsonFn);
    napi_create_function(env, "benchmark", NAPI_AUTO_LENGTH, NapiBenchmark, nullptr, &benchmarkFn);

    napi_set_named_property(env, exports, "parseArticleJson", parseArticleJsonFn);
    napi_set_named_property(env, exports, "parseCommentJson", parseCommentJsonFn);
    napi_set_named_property(env, exports, "adaptColor", adaptColorFn);
    napi_set_named_property(env, exports, "parseBBCodeJson", parseBBCodeJsonFn);
    napi_set_named_property(env, exports, "benchmark", benchmarkFn);

    napi_value newExports;
    napi_create_object(env, &newExports);
    napi_property_descriptor props[] = {
        {"parseArticleJson", nullptr, NapiParseArticleJson, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"parseCommentJson", nullptr, NapiParseCommentJson, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"adaptColor", nullptr, NapiAdaptColor, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"parseBBCodeJson", nullptr, NapiParseBBCodeJson, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"benchmark", nullptr, NapiBenchmark, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
    };
    napi_define_properties(env, newExports, 5, props);

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
