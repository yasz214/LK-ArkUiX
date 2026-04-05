#include <napi/native_api.h>
#include <vector>
#include <string>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <memory>




#pragma pack(push, 4)
struct FlatNode {
    uint32_t childStart;  
    uint16_t childCount;  
    uint16_t valLen;      
    union {
        uint32_t valOffset;    
        char16_t inlineVal[2]; 
    };
};
#pragma pack(pop)

static std::vector<FlatNode> g_nodes;


static std::vector<char16_t> g_edge_chars;
static std::vector<uint32_t> g_edge_nexts;
static std::vector<char16_t> g_stringPool;


static uint32_t g_root_children[65536] = {0};


static uint64_t g_first_char_bitmap[1024] = {0};


constexpr uint32_t TAG_SINGLE_CHAR = 0x80000000;



struct BuildNode {
    std::u16string value;
    std::vector<std::pair<char16_t, BuildNode*>> children;
    ~BuildNode() {
        for (auto& pair : children) delete pair.second;
    }
};

static uint32_t FlattenTree(BuildNode* node) {
    if (!node) return 0;

    uint32_t nodeIdx = (uint32_t)g_nodes.size();
    FlatNode dummy;
    std::memset(&dummy, 0, sizeof(dummy));
    g_nodes.push_back(dummy);

    uint32_t childStart = 0;
    uint16_t childCount = 0;

    if (!node->children.empty()) {
        std::sort(node->children.begin(), node->children.end(),
                  [](const auto& a, const auto& b) { return a.first < b.first; });

        childStart = (uint32_t)g_edge_chars.size();
        childCount = (uint16_t)node->children.size();
        g_edge_chars.resize(childStart + childCount);
        g_edge_nexts.resize(childStart + childCount);

        for (uint16_t i = 0; i < childCount; i++) {
            char16_t c = node->children[i].first;
            uint32_t nextIdx = FlattenTree(node->children[i].second);
            g_edge_chars[childStart + i] = c;
            g_edge_nexts[childStart + i] = nextIdx;
        }
    }

    FlatNode& flat = g_nodes[nodeIdx];
    flat.childStart = childStart;
    flat.childCount = childCount;
    flat.valLen = (uint16_t)node->value.length();

    if (flat.valLen == 1) {
        flat.inlineVal[0] = node->value[0];
    } else if (flat.valLen == 2) {
        flat.inlineVal[0] = node->value[0];
        flat.inlineVal[1] = node->value[1];
    } else if (flat.valLen > 2) {
        flat.valOffset = (uint32_t)g_stringPool.size();
        g_stringPool.insert(g_stringPool.end(), node->value.begin(), node->value.end());
    }

    return nodeIdx;
}


__attribute__((always_inline)) inline uint32_t FindChild(uint32_t nodeIdx, char16_t c) {
    const FlatNode& node = g_nodes[nodeIdx];
    uint16_t count = node.childCount;
    if (count == 0) return 0;

    uint32_t start = node.childStart;
    const char16_t* chars = g_edge_chars.data() + start;

    
    if (count <= 8) {
        for (uint16_t i = 0; i < count; i++) {
            if (chars[i] == c) return g_edge_nexts[start + i];
        }
        return 0;
    }

    
    int left = 0, right = count - 1;
    while (left <= right) {
        int mid = left + ((right - left) >> 1);
        char16_t midC = chars[mid];
        if (midC == c) return g_edge_nexts[start + mid];
        if (midC < c) left = mid + 1;
        else right = mid - 1;
    }
    return 0;
}



static napi_value InitEngine(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) return nullptr;

    uint32_t length = 0;
    napi_get_array_length(env, args[0], &length);

    g_nodes.clear();
    g_edge_chars.clear();
    g_edge_nexts.clear();
    g_stringPool.clear();
    std::memset(g_first_char_bitmap, 0, sizeof(g_first_char_bitmap));
    std::memset(g_root_children, 0, sizeof(g_root_children));

    g_nodes.reserve(length * 2);
    g_edge_chars.reserve(length * 3);
    g_edge_nexts.reserve(length * 3);
    g_stringPool.reserve(length);

    FlatNode dummy; std::memset(&dummy, 0, sizeof(dummy));
    g_nodes.push_back(dummy);

    std::vector<BuildNode*> tempRootChildren(65536, nullptr);

    for (uint32_t i = 0; i < length; i++) {
        napi_value jsKey, jsVal;
        napi_get_element(env, args[0], i, &jsKey);
        napi_get_element(env, args[1], i, &jsVal);

        size_t keyLen = 0, valLen = 0;
        napi_get_value_string_utf16(env, jsKey, nullptr, 0, &keyLen);
        napi_get_value_string_utf16(env, jsVal, nullptr, 0, &valLen);
        if (keyLen == 0) continue;

        std::u16string key(keyLen, u'\0');
        std::u16string val(valLen, u'\0');
        napi_get_value_string_utf16(env, jsKey, (char16_t*)&key[0], keyLen + 1, &keyLen);
        napi_get_value_string_utf16(env, jsVal, (char16_t*)&val[0], valLen + 1, &valLen);

        char16_t firstChar = key[0];
        if (!tempRootChildren[firstChar]) {
            tempRootChildren[firstChar] = new BuildNode();
            g_first_char_bitmap[firstChar >> 6] |= (1ULL << (firstChar & 63));
        }

        BuildNode* curr = tempRootChildren[firstChar];
        for (size_t j = 1; j < key.length(); j++) {
            char16_t c = key[j];
            BuildNode* nextNode = nullptr;
            for (auto& pair : curr->children) {
                if (pair.first == c) { nextNode = pair.second; break; }
            }
            if (!nextNode) {
                nextNode = new BuildNode();
                curr->children.push_back({c, nextNode});
            }
            curr = nextNode;
        }
        curr->value = val;
    }

    for (int i = 0; i < 65536; i++) {
        if (tempRootChildren[i]) {
            
            if (tempRootChildren[i]->children.empty() && tempRootChildren[i]->value.length() == 1) {
                g_root_children[i] = TAG_SINGLE_CHAR | tempRootChildren[i]->value[0];
            } else {
                g_root_children[i] = FlattenTree(tempRootChildren[i]);
            }
            delete tempRootChildren[i];
        }
    }

    g_nodes.shrink_to_fit();
    g_edge_chars.shrink_to_fit();
    g_edge_nexts.shrink_to_fit();
    g_stringPool.shrink_to_fit();

    napi_value result;
    napi_get_boolean(env, true, &result);
    return result;
}






static char16_t* ConvertU16(const char16_t* p, size_t textLen, size_t& outLen) {
    const char16_t* end = p + textLen;
    const char16_t* lastUnmatched = p;
    bool hasConverted = false;

    char16_t* outBuf = nullptr;
    size_t outCap = 0;
    outLen = 0;

    while (p < end) {
        char16_t c = *p;

        
        if (!(g_first_char_bitmap[c >> 6] & (1ULL << (c & 63)))) {
            p++; continue;
        }

        uint32_t rootVal = g_root_children[c];
        if (rootVal == 0) {
            p++; continue;
        }

        
        if (rootVal & TAG_SINGLE_CHAR) {
            if (!hasConverted) {
                outCap = textLen + (textLen >> 2) + 64;
                outBuf = (char16_t*)malloc(outCap * sizeof(char16_t));
                if (!outBuf) return nullptr;
                hasConverted = true;
            }

            size_t unmatchedLen = p - lastUnmatched;
            if (outLen + unmatchedLen + 1 > outCap) {
                outCap = (outLen + unmatchedLen + 1) * 2;
                char16_t* newBuf = (char16_t*)realloc(outBuf, outCap * sizeof(char16_t));
                if (!newBuf) { free(outBuf); return nullptr; }
                outBuf = newBuf;
            }

            if (unmatchedLen > 0) {
                memcpy(outBuf + outLen, lastUnmatched, unmatchedLen * sizeof(char16_t));
                outLen += unmatchedLen;
            }

            outBuf[outLen++] = (char16_t)(rootVal & 0xFFFF);
            p++;
            lastUnmatched = p;
            continue;
        }

        
        size_t matchLen = 0;
        const FlatNode* matchedNode = nullptr;

        const FlatNode* node = &g_nodes[rootVal];
        if (node->valLen > 0) {
            matchLen = 1;
            matchedNode = node;
        }

        uint32_t nodeIdx = rootVal;
        const char16_t* searchPtr = p + 1;

        while (searchPtr < end) {
            nodeIdx = FindChild(nodeIdx, *searchPtr);
            if (nodeIdx == 0) break;

            node = &g_nodes[nodeIdx];
            if (node->valLen > 0) {
                matchLen = searchPtr - p + 1;
                matchedNode = node;
            }
            searchPtr++;
        }

        if (matchLen > 0) {
            if (!hasConverted) {
                outCap = textLen + (textLen >> 2) + 64;
                outBuf = (char16_t*)malloc(outCap * sizeof(char16_t));
                if (!outBuf) return nullptr;
                hasConverted = true;
            }

            size_t unmatchedLen = p - lastUnmatched;
            if (outLen + unmatchedLen + matchedNode->valLen > outCap) {
                outCap = (outLen + unmatchedLen + matchedNode->valLen) * 2;
                char16_t* newBuf = (char16_t*)realloc(outBuf, outCap * sizeof(char16_t));
                if (!newBuf) { free(outBuf); return nullptr; }
                outBuf = newBuf;
            }

            if (unmatchedLen > 0) {
                memcpy(outBuf + outLen, lastUnmatched, unmatchedLen * sizeof(char16_t));
                outLen += unmatchedLen;
            }

            
            if (matchedNode->valLen == 1) {
                outBuf[outLen] = matchedNode->inlineVal[0];
            } else if (matchedNode->valLen == 2) {
                outBuf[outLen] = matchedNode->inlineVal[0];
                outBuf[outLen + 1] = matchedNode->inlineVal[1];
            } else {
                memcpy(outBuf + outLen, g_stringPool.data() + matchedNode->valOffset, matchedNode->valLen * sizeof(char16_t));
            }

            outLen += matchedNode->valLen;
            p += matchLen;
            lastUnmatched = p;
        } else {
            p++;
        }
    }

    if (!hasConverted) return nullptr; 

    if (end > lastUnmatched) {
        size_t unmatchedLen = end - lastUnmatched;
        if (outLen + unmatchedLen > outCap) {
            outCap = outLen + unmatchedLen;
            char16_t* newBuf = (char16_t*)realloc(outBuf, outCap * sizeof(char16_t));
            if (!newBuf) { free(outBuf); return nullptr; }
            outBuf = newBuf;
        }
        memcpy(outBuf + outLen, lastUnmatched, unmatchedLen * sizeof(char16_t));
        outLen += unmatchedLen;
    }

    return outBuf;
}

static napi_value ConvertText(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1 || g_nodes.empty()) return args[0];

    size_t textLen = 0;
    if (napi_get_value_string_utf16(env, args[0], nullptr, 0, &textLen) != napi_ok || textLen == 0) {
        return args[0];
    }

    std::unique_ptr<char16_t[]> textData(new char16_t[textLen + 1]);
    napi_get_value_string_utf16(env, args[0], textData.get(), textLen + 1, &textLen);

    size_t outLen = 0;
    char16_t* outBuf = ConvertU16(textData.get(), textLen, outLen);

    if (!outBuf) return args[0]; 

    napi_value result;
    napi_create_string_utf16(env, outBuf, outLen, &result);
    free(outBuf);
    return result;
}



static napi_value ConvertBatch(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1 || g_nodes.empty()) return args[0];

    uint32_t length = 0;
    if (napi_get_array_length(env, args[0], &length) != napi_ok || length == 0) {
        return args[0];
    }

    napi_value resultArray;
    napi_create_array_with_length(env, length, &resultArray);

    for (uint32_t i = 0; i < length; i++) {
        napi_value jsStr;
        napi_get_element(env, args[0], i, &jsStr);

        size_t textLen = 0;
        if (napi_get_value_string_utf16(env, jsStr, nullptr, 0, &textLen) != napi_ok || textLen == 0) {
            
            napi_set_element(env, resultArray, i, jsStr);
            continue;
        }

        std::unique_ptr<char16_t[]> textData(new char16_t[textLen + 1]);
        napi_get_value_string_utf16(env, jsStr, textData.get(), textLen + 1, &textLen);

        size_t outLen = 0;
        char16_t* outBuf = ConvertU16(textData.get(), textLen, outLen);

        if (!outBuf) {
            
            napi_set_element(env, resultArray, i, jsStr);
        } else {
            napi_value converted;
            napi_create_string_utf16(env, outBuf, outLen, &converted);
            free(outBuf);
            napi_set_element(env, resultArray, i, converted);
        }
    }

    return resultArray;
}















extern "C" {
static napi_value Init(napi_env env, napi_value exports) {
    napi_value initEngineFn, convertTextFn, convertBatchFn;
    napi_create_function(env, "initEngine", NAPI_AUTO_LENGTH, InitEngine, nullptr, &initEngineFn);
    napi_create_function(env, "convertText", NAPI_AUTO_LENGTH, ConvertText, nullptr, &convertTextFn);
    napi_create_function(env, "convertBatch", NAPI_AUTO_LENGTH, ConvertBatch, nullptr, &convertBatchFn);

    
    napi_set_named_property(env, exports, "initEngine", initEngineFn);
    napi_set_named_property(env, exports, "convertText", convertTextFn);
    napi_set_named_property(env, exports, "convertBatch", convertBatchFn);

    
    napi_value newExports;
    napi_create_object(env, &newExports);
    napi_property_descriptor props[] = {
        {"initEngine", nullptr, InitEngine, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"convertText", nullptr, ConvertText, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
        {"convertBatch", nullptr, ConvertBatch, nullptr, nullptr, nullptr,
         napi_default_jsproperty, nullptr},
    };
    napi_define_properties(env, newExports, 3, props);

    return newExports;
}
}

static napi_module t2sModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "t2s",
    .nm_priv = ((void*)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterT2SModule(void) {
    napi_module_register(&t2sModule);
}
