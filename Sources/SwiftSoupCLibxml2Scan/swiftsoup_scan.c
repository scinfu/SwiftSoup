#include "swiftsoup_scan.h"
#include <string.h>
#include <stdlib.h>

static uint8_t asciiLowerTable[256];
static uint8_t isWhitespaceTable[256];
static uint8_t isNameCharTable[256];
static uint8_t booleanAttrLengthLookup[32];
static uint8_t booleanAttrBucketStart[128];
static uint8_t booleanAttrBucketCount[128];
static uint8_t booleanAttrBucketIndices[32];
static int scanTablesInitialized = 0;

static const char *booleanAttrNames[] = {
    "allowfullscreen", "async", "autofocus", "checked", "compact", "controls", "declare", "default", "defer",
    "disabled", "formnovalidate", "hidden", "inert", "ismap", "itemscope", "multiple", "muted", "nohref",
    "noresize", "noshade", "novalidate", "nowrap", "open", "readonly", "required", "reversed", "seamless",
    "selected", "sortable", "truespeed", "typemustmatch"
};
static const uint8_t booleanAttrLengths[] = {
    14, 5, 9, 7, 7, 8, 7, 7, 5,
    8, 13, 6, 5, 5, 9, 8, 5, 6,
    8, 7, 10, 6, 4, 8, 8, 8, 8,
    8, 8, 9, 12
};
static const int booleanAttrCount = 31;

static void init_scan_tables(void) {
    if (scanTablesInitialized) {
        return;
    }
    for (int i = 0; i < 256; i++) {
        uint8_t b = (uint8_t)i;
        asciiLowerTable[i] = (b >= 65 && b <= 90) ? (uint8_t)(b + 32) : b;
        isWhitespaceTable[i] = 0;
        isNameCharTable[i] = 0;
    }
    isWhitespaceTable[0x20] = 1;
    isWhitespaceTable[0x09] = 1;
    isWhitespaceTable[0x0A] = 1;
    isWhitespaceTable[0x0D] = 1;

    for (int i = 65; i <= 90; i++) { isNameCharTable[i] = 1; }
    for (int i = 97; i <= 122; i++) { isNameCharTable[i] = 1; }
    isNameCharTable[0x3A] = 1; // :
    isNameCharTable[0x5F] = 1; // _
    for (int i = 48; i <= 57; i++) { isNameCharTable[i] = 1; }
    isNameCharTable[0x2D] = 1; // -
    isNameCharTable[0x2E] = 1; // .

    for (int i = 0; i < 32; i++) {
        booleanAttrLengthLookup[i] = 0;
    }
    for (int i = 0; i < 128; i++) {
        booleanAttrBucketStart[i] = 0;
        booleanAttrBucketCount[i] = 0;
    }
    for (int i = 0; i < booleanAttrCount; i++) {
        uint8_t len = booleanAttrLengths[i];
        if (len < 32) {
            booleanAttrLengthLookup[len] = 1;
        }
        uint8_t first = (uint8_t)booleanAttrNames[i][0];
        if (first < 128) {
            booleanAttrBucketCount[first] += 1;
        }
    }
    uint8_t running = 0;
    for (int i = 0; i < 128; i++) {
        booleanAttrBucketStart[i] = running;
        running = (uint8_t)(running + booleanAttrBucketCount[i]);
        booleanAttrBucketCount[i] = 0;
    }
    for (int i = 0; i < booleanAttrCount; i++) {
        uint8_t first = (uint8_t)booleanAttrNames[i][0];
        if (first < 128) {
            uint8_t offset = (uint8_t)(booleanAttrBucketStart[first] + booleanAttrBucketCount[first]);
            booleanAttrBucketIndices[offset] = (uint8_t)i;
            booleanAttrBucketCount[first] += 1;
        }
    }

    scanTablesInitialized = 1;
}

static int boolean_attribute_index(const uint8_t *bytes, int start, int end) {
    int length = end - start;
    if (length <= 0 || length >= 32 || !booleanAttrLengthLookup[length]) {
        return -1;
    }
    uint8_t first = bytes[start];
    if (first >= 0x80) {
        return -1;
    }
    uint8_t lowerFirst = asciiLowerTable[first];
    if (lowerFirst >= 128) {
        return -1;
    }
    uint8_t startOffset = booleanAttrBucketStart[lowerFirst];
    uint8_t count = booleanAttrBucketCount[lowerFirst];
    for (uint8_t idx = 0; idx < count; idx++) {
        uint8_t entryIndex = booleanAttrBucketIndices[startOffset + idx];
        if ((int)booleanAttrLengths[entryIndex] != length) {
            continue;
        }
        const char *target = booleanAttrNames[entryIndex];
        int matches = 1;
        for (int j = 0; j < length; j++) {
            uint8_t b = bytes[start + j];
            if (b >= 0x80) {
                return -1;
            }
            if (asciiLowerTable[b] != (uint8_t)target[j]) {
                matches = 0;
                break;
            }
        }
        if (matches) {
            return (int)entryIndex;
        }
    }
    return -1;
}

typedef struct {
    int32_t *data;
    int32_t count;
    int32_t capacity;
} boolean_occurrences_buf;

static void boolean_occurrences_init(boolean_occurrences_buf *buf) {
    buf->data = NULL;
    buf->count = 0;
    buf->capacity = 0;
}

static void boolean_occurrences_append(boolean_occurrences_buf *buf, int index, int isBoolean) {
    if (!buf) {
        return;
    }
    if (buf->count + 2 > buf->capacity) {
        int32_t newCap = (buf->capacity == 0) ? 64 : (buf->capacity * 2);
        int32_t *newData = (int32_t *)realloc(buf->data, sizeof(int32_t) * (size_t)newCap);
        if (!newData) {
            return;
        }
        buf->data = newData;
        buf->capacity = newCap;
    }
    buf->data[buf->count++] = (int32_t)index;
    buf->data[buf->count++] = (int32_t)isBoolean;
}

static void boolean_occurrences_finish(boolean_occurrences_buf *buf, int32_t **outPairs, int32_t *outCount) {
    if (outPairs) {
        *outPairs = buf ? buf->data : NULL;
    }
    if (outCount) {
        *outCount = buf ? (buf->count / 2) : 0;
    }
    if (buf) {
        buf->data = NULL;
        buf->count = 0;
        buf->capacity = 0;
    }
}

void swiftsoup_free_int32(int32_t *ptr) {
    if (ptr) {
        free(ptr);
    }
}

static void swiftsoup_scan_hints_internal(const uint8_t *bytes, int length,
                                          swiftsoup_record_selfclosing_fn recordSelfClosing,
                                          swiftsoup_record_boolean_index_fn recordBoolean,
                                          boolean_occurrences_buf *booleanBuf,
                                          void *ctx) {
    if (!bytes || length <= 0) {
        return;
    }
    init_scan_tables();
    int i = 0;
    while (i < length) {
        if (bytes[i] != 0x3C) { // '<'
            if (i + 1 >= length) {
                break;
            }
            const void *found = memchr(bytes + i + 1, 0x3C, (size_t)(length - (i + 1)));
            if (!found) {
                break;
            }
            i = (int)((const uint8_t *)found - bytes);
            continue;
        }
        if (i + 1 >= length) {
            break;
        }
        uint8_t next = bytes[i + 1];
        if (next == 0x21) { // !
            if (i + 3 < length && bytes[i + 2] == 0x2D && bytes[i + 3] == 0x2D) { // <!--
                int j = i + 4;
                while (j + 2 < length) {
                    if (bytes[j] == 0x2D && bytes[j + 1] == 0x2D && bytes[j + 2] == 0x3E) {
                        i = j + 3;
                        break;
                    }
                    j++;
                }
                if (j + 2 >= length) {
                    break;
                }
                continue;
            }
            int j = i + 2;
            while (j < length && bytes[j] != 0x3E) {
                j++;
            }
            i = (j + 1 <= length) ? (j + 1) : length;
            continue;
        }
        if (next == 0x2F) { // /
            int j = i + 2;
            while (j < length && bytes[j] != 0x3E) {
                j++;
            }
            i = (j + 1 <= length) ? (j + 1) : length;
            continue;
        }
        if (next == 0x3F) { // ?
            int j = i + 2;
            while (j + 1 < length) {
                if (bytes[j] == 0x3F && bytes[j + 1] == 0x3E) {
                    i = j + 2;
                    break;
                }
                j++;
            }
            if (j + 1 >= length) {
                break;
            }
            continue;
        }
        if (!isNameCharTable[next]) {
            i++;
            continue;
        }
        int nameStart = i + 1;
        int nameEnd = nameStart;
        while (nameEnd < length && isNameCharTable[bytes[nameEnd]]) {
            nameEnd++;
        }
        if (nameEnd == nameStart) {
            i++;
            continue;
        }

        int j = nameEnd;
        int isSelfClosing = 0;
        int quote = 0;
        int lastNonWhitespace = 0;
        while (j < length) {
            uint8_t b = bytes[j];
            if (quote) {
                if (b == (uint8_t)quote) {
                    quote = 0;
                }
            } else {
                if (b == 0x22 || b == 0x27) { // " or '
                    quote = b;
                } else if (b == 0x3E) { // >
                    if (lastNonWhitespace == 0x2F) {
                        isSelfClosing = 1;
                    }
                    break;
                } else if (!isWhitespaceTable[b]) {
                    lastNonWhitespace = b;
                }
            }
            j++;
        }
        if (recordSelfClosing) {
            recordSelfClosing(bytes + nameStart, nameEnd - nameStart, isSelfClosing, ctx);
        }

        int attrIndex = nameEnd;
        while (attrIndex < length) {
            while (attrIndex < length && isWhitespaceTable[bytes[attrIndex]]) {
                attrIndex++;
            }
            if (attrIndex >= length) {
                break;
            }
            if (bytes[attrIndex] == 0x3E) { // >
                attrIndex++;
                break;
            }
            if (bytes[attrIndex] == 0x2F && attrIndex + 1 < length && bytes[attrIndex + 1] == 0x3E) { // />
                attrIndex += 2;
                break;
            }
            int attrStart = attrIndex;
            while (attrIndex < length
                    && !isWhitespaceTable[bytes[attrIndex]]
                    && bytes[attrIndex] != 0x3D
                    && bytes[attrIndex] != 0x3E
                    && bytes[attrIndex] != 0x2F) {
                attrIndex++;
            }
            if (attrStart == attrIndex) {
                break;
            }
            int attrEnd = attrIndex;
            int isBoolean = 1;
            int booleanIndex = -1;
            if (recordBoolean || booleanBuf) {
                booleanIndex = boolean_attribute_index(bytes, attrStart, attrEnd);
            }
            while (attrIndex < length && isWhitespaceTable[bytes[attrIndex]]) {
                attrIndex++;
            }
            if (attrIndex < length && bytes[attrIndex] == 0x3D) { // =
                isBoolean = 0;
                attrIndex++;
                while (attrIndex < length && isWhitespaceTable[bytes[attrIndex]]) {
                    attrIndex++;
                }
                if (attrIndex >= length) {
                    break;
                }
                if (bytes[attrIndex] == 0x22 || bytes[attrIndex] == 0x27) {
                    uint8_t q = bytes[attrIndex];
                    attrIndex++;
                    if (attrIndex < length) {
                        const void *found = memchr(bytes + attrIndex, q, (size_t)(length - attrIndex));
                        if (!found) {
                            attrIndex = length;
                        } else {
                            attrIndex = (int)((const uint8_t *)found - bytes) + 1;
                        }
                    }
                } else {
                    while (attrIndex < length && !isWhitespaceTable[bytes[attrIndex]] && bytes[attrIndex] != 0x3E) {
                        attrIndex++;
                    }
                }
            }
            if (booleanIndex >= 0) {
                if (recordBoolean) {
                    recordBoolean(booleanIndex, isBoolean, ctx);
                }
                if (booleanBuf) {
                    boolean_occurrences_append(booleanBuf, booleanIndex, isBoolean);
                }
            }
        }
        i = (j + 1 <= length) ? (j + 1) : length;
    }
}

void swiftsoup_scan_hints(const uint8_t *bytes, int length,
                          swiftsoup_record_selfclosing_fn recordSelfClosing,
                          swiftsoup_record_boolean_index_fn recordBoolean,
                          void *ctx) {
    swiftsoup_scan_hints_internal(bytes, length, recordSelfClosing, recordBoolean, NULL, ctx);
}

void swiftsoup_scan_hints_collect(const uint8_t *bytes, int length,
                                  swiftsoup_record_selfclosing_fn recordSelfClosing,
                                  void *ctx,
                                  int32_t **outBooleanPairs,
                                  int32_t *outBooleanCount) {
    boolean_occurrences_buf booleanBuf;
    boolean_occurrences_init(&booleanBuf);
    swiftsoup_scan_hints_internal(bytes, length, recordSelfClosing, NULL, &booleanBuf, ctx);
    boolean_occurrences_finish(&booleanBuf, outBooleanPairs, outBooleanCount);
}

typedef enum {
    TAG_NONE = 0,
    TAG_A,
    TAG_B,
    TAG_I,
    TAG_U,
    TAG_P,
    TAG_EM,
    TAG_STRONG,
    TAG_FONT,
    TAG_H1,
    TAG_H2,
    TAG_H3,
    TAG_H4,
    TAG_H5,
    TAG_H6,
    TAG_TABLE,
    TAG_TBODY,
    TAG_THEAD,
    TAG_TFOOT,
    TAG_TR,
    TAG_TD,
    TAG_TH,
    TAG_CAPTION,
    TAG_COLGROUP,
    TAG_COL,
    TAG_BASE,
    TAG_META,
    TAG_TITLE,
    TAG_STYLE,
    TAG_SCRIPT,
    TAG_LINK,
    TAG_BR,
    TAG_HR,
    TAG_IMG,
    TAG_EMBED,
    TAG_INPUT,
    TAG_WBR,
    TAG_AREA,
    TAG_PARAM,
    TAG_TRACK,
    TAG_SOURCE,
    TAG_NOSCRIPT,
    TAG_HGROUP,
    TAG_HTML,
    TAG_HEAD,
    TAG_BODY,
    TAG_TEXTAREA,
    TAG_SELECT
} tag_id;

static int matches_tag(const uint8_t *bytes, int start, int end, const char *tag, int length) {
    if (end - start != length) {
        return 0;
    }
    for (int i = 0; i < length; i++) {
        uint8_t b = bytes[start + i];
        if (b >= 0x80) {
            return 0;
        }
        if (asciiLowerTable[b] != (uint8_t)tag[i]) {
            return 0;
        }
    }
    return 1;
}

static tag_id tag_id_for_ascii_lowercase(const uint8_t *bytes, int start, int end) {
    int length = end - start;
    if (length <= 0) {
        return TAG_NONE;
    }
    uint8_t first = asciiLowerTable[bytes[start]];
    switch (length) {
        case 1:
            switch (first) {
                case 'a': return TAG_A;
                case 'b': return TAG_B;
                case 'i': return TAG_I;
                case 'p': return TAG_P;
                case 'u': return TAG_U;
                default: return TAG_NONE;
            }
        case 2:
            if (first == 'e' && matches_tag(bytes, start, end, "em", 2)) return TAG_EM;
            if (first == 't') {
                uint8_t second = asciiLowerTable[bytes[start + 1]];
                if (second == 'r') return TAG_TR;
                if (second == 'd') return TAG_TD;
                if (second == 'h') return TAG_TH;
            }
            if (first == 'b' && matches_tag(bytes, start, end, "br", 2)) return TAG_BR;
            if (first == 'h') {
                uint8_t second = asciiLowerTable[bytes[start + 1]];
                if (second == 'r') return TAG_HR;
                if (second >= '1' && second <= '6') {
                    return (tag_id)(TAG_H1 + (second - '1'));
                }
            }
            return TAG_NONE;
        case 3:
            if (first == 'i' && matches_tag(bytes, start, end, "img", 3)) return TAG_IMG;
            if (first == 'c' && matches_tag(bytes, start, end, "col", 3)) return TAG_COL;
            if (first == 'w' && matches_tag(bytes, start, end, "wbr", 3)) return TAG_WBR;
            return TAG_NONE;
        case 4:
            if (first == 'b' && matches_tag(bytes, start, end, "base", 4)) return TAG_BASE;
            if (first == 'm' && matches_tag(bytes, start, end, "meta", 4)) return TAG_META;
            if (first == 'l' && matches_tag(bytes, start, end, "link", 4)) return TAG_LINK;
            if (first == 'b' && matches_tag(bytes, start, end, "body", 4)) return TAG_BODY;
            if (first == 'h' && matches_tag(bytes, start, end, "head", 4)) return TAG_HEAD;
            if (first == 'h' && matches_tag(bytes, start, end, "html", 4)) return TAG_HTML;
            if (first == 'a' && matches_tag(bytes, start, end, "area", 4)) return TAG_AREA;
            if (first == 'f' && matches_tag(bytes, start, end, "font", 4)) return TAG_FONT;
            return TAG_NONE;
        case 5:
            if (first == 't' && matches_tag(bytes, start, end, "title", 5)) return TAG_TITLE;
            if (first == 's' && matches_tag(bytes, start, end, "style", 5)) return TAG_STYLE;
            if (first == 'i' && matches_tag(bytes, start, end, "input", 5)) return TAG_INPUT;
            if (first == 'e' && matches_tag(bytes, start, end, "embed", 5)) return TAG_EMBED;
            if (first == 't' && matches_tag(bytes, start, end, "table", 5)) return TAG_TABLE;
            if (first == 't' && matches_tag(bytes, start, end, "tbody", 5)) return TAG_TBODY;
            if (first == 't' && matches_tag(bytes, start, end, "thead", 5)) return TAG_THEAD;
            if (first == 't' && matches_tag(bytes, start, end, "tfoot", 5)) return TAG_TFOOT;
            if (first == 't' && matches_tag(bytes, start, end, "track", 5)) return TAG_TRACK;
            if (first == 'p' && matches_tag(bytes, start, end, "param", 5)) return TAG_PARAM;
            return TAG_NONE;
        case 6:
            if (first == 's' && matches_tag(bytes, start, end, "script", 6)) return TAG_SCRIPT;
            if (first == 's' && matches_tag(bytes, start, end, "select", 6)) return TAG_SELECT;
            if (first == 's' && matches_tag(bytes, start, end, "source", 6)) return TAG_SOURCE;
            if (first == 's' && matches_tag(bytes, start, end, "strong", 6)) return TAG_STRONG;
            if (first == 'h' && matches_tag(bytes, start, end, "hgroup", 6)) return TAG_HGROUP;
            return TAG_NONE;
        case 7:
            if (first == 'c' && matches_tag(bytes, start, end, "caption", 7)) return TAG_CAPTION;
            return TAG_NONE;
        case 8:
            if (first == 'c' && matches_tag(bytes, start, end, "colgroup", 8)) return TAG_COLGROUP;
            if (first == 'n' && matches_tag(bytes, start, end, "noscript", 8)) return TAG_NOSCRIPT;
            if (first == 't' && matches_tag(bytes, start, end, "textarea", 8)) return TAG_TEXTAREA;
            return TAG_NONE;
        default:
            return TAG_NONE;
    }
}

static int is_heading_tag(tag_id id) {
    return (id >= TAG_H1 && id <= TAG_H6);
}

static int is_table_structure_tag(tag_id id) {
    switch (id) {
        case TAG_TABLE:
        case TAG_TBODY:
        case TAG_THEAD:
        case TAG_TFOOT:
        case TAG_TR:
        case TAG_TD:
        case TAG_TH:
        case TAG_CAPTION:
        case TAG_COLGROUP:
        case TAG_COL:
            return 1;
        default:
            return 0;
    }
}

static int is_table_outside_row_allowed(tag_id id) {
    switch (id) {
        case TAG_TABLE:
        case TAG_THEAD:
        case TAG_TBODY:
        case TAG_TFOOT:
        case TAG_TR:
        case TAG_COL:
        case TAG_CAPTION:
        case TAG_COLGROUP:
        case TAG_STYLE:
        case TAG_SCRIPT:
            return 1;
        default:
            return 0;
    }
}

static int is_head_allowed_tag(tag_id id) {
    switch (id) {
        case TAG_BASE:
        case TAG_META:
        case TAG_TITLE:
        case TAG_STYLE:
        case TAG_SCRIPT:
        case TAG_LINK:
            return 1;
        default:
            return 0;
    }
}

static int is_void_tag(tag_id id) {
    switch (id) {
        case TAG_BR:
        case TAG_HR:
        case TAG_COL:
        case TAG_IMG:
        case TAG_EMBED:
        case TAG_INPUT:
        case TAG_META:
        case TAG_BASE:
        case TAG_WBR:
        case TAG_AREA:
        case TAG_LINK:
        case TAG_PARAM:
        case TAG_TRACK:
        case TAG_SOURCE:
            return 1;
        default:
            return 0;
    }
}

static int formatting_tag_id(tag_id id) {
    switch (id) {
        case TAG_A: return 0;
        case TAG_B: return 1;
        case TAG_I: return 2;
        case TAG_U: return 3;
        case TAG_EM: return 4;
        case TAG_FONT: return 5;
        case TAG_STRONG: return 6;
        default: return -1;
    }
}

static int skip_raw_text(const uint8_t *bytes, int length, const char *tag, int tagLen, int start) {
    int j = start;
    while (j + tagLen + 2 < length) {
        if (bytes[j] == 0x3C && bytes[j + 1] == 0x2F) {
            int k = 0;
            while (k < tagLen) {
                uint8_t b = bytes[j + 2 + k];
                if (b >= 0x80 || asciiLowerTable[b] != (uint8_t)tag[k]) {
                    break;
                }
                k++;
            }
            if (k == tagLen) {
                int end = j + 2 + tagLen;
                while (end < length && bytes[end] != 0x3E) {
                    end++;
                }
                if (end >= length) {
                    return -1;
                }
                return (end + 1 <= length) ? (end + 1) : length;
            }
        }
        j++;
    }
    return -1;
}

static int swiftsoup_should_fallback_internal(const uint8_t *bytes, int length,
                                              swiftsoup_record_selfclosing_fn recordSelfClosing,
                                              swiftsoup_record_boolean_index_fn recordBoolean,
                                              boolean_occurrences_buf *booleanBuf,
                                              void *ctx,
                                              swiftsoup_fallback_reason *reasonOut) {
    if (!bytes || length <= 0) {
        if (reasonOut) {
            *reasonOut = SWIFTSOUP_FALLBACK_MALFORMED_TAG;
        }
        return 1;
    }
    init_scan_tables();
    int i = 0;
    int sawTagDelimiter = 0;
    int sawHtmlTag = 0;
    int sawBodyTag = 0;
    int inHead = 0;
    int sawContentBeforeHtml = 0;
    int headingOpen = 0;
    int openTagDepth = 0;
    int selectDepth = 0;

    uint8_t formatInline[8];
    uint8_t *formatStack = formatInline;
    int formatCount = 0;
    int formatCap = 8;

    typedef struct {
        int captionDepth;
        int sectionDepth;
        int trDepth;
        int cellDepth;
    } TableState;

    TableState tableInline[4];
    TableState *tableStack = tableInline;
    int tableCount = 0;
    int tableCap = 4;

    #define FAIL(reason) do { if (reasonOut) *reasonOut = (reason); \
                              if (formatStack != formatInline) free(formatStack); \
                              if (tableStack != tableInline) free(tableStack); \
                              return 1; } while (0)

    #define FORMAT_PUSH(val) do { \
        if (formatCount == formatCap) { \
            int newCap = formatCap * 2; \
            uint8_t *newBuf = (uint8_t *)malloc((size_t)newCap); \
            if (!newBuf) { FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG); } \
            memcpy(newBuf, formatStack, (size_t)formatCount); \
            if (formatStack != formatInline) free(formatStack); \
            formatStack = newBuf; \
            formatCap = newCap; \
        } \
        formatStack[formatCount++] = (uint8_t)(val); \
    } while (0)

    #define TABLE_PUSH(stateVal) do { \
        if (tableCount == tableCap) { \
            int newCap = tableCap * 2; \
            TableState *newBuf = (TableState *)malloc(sizeof(TableState) * (size_t)newCap); \
            if (!newBuf) { FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG); } \
            memcpy(newBuf, tableStack, sizeof(TableState) * (size_t)tableCount); \
            if (tableStack != tableInline) free(tableStack); \
            tableStack = newBuf; \
            tableCap = newCap; \
        } \
        tableStack[tableCount++] = (stateVal); \
    } while (0)

    while (i < length) {
        if (bytes[i] == 0x00) {
            FAIL(SWIFTSOUP_FALLBACK_CONTAINS_NULL);
        }
        if (bytes[i] != 0x3C) { // '<'
            const void *nextTagPtr = (i + 1 < length)
                ? memchr(bytes + i + 1, 0x3C, (size_t)(length - (i + 1)))
                : NULL;
            int nextTagIndex = nextTagPtr ? (int)((const uint8_t *)nextTagPtr - bytes) : length;
            if (memchr(bytes + i, 0x00, (size_t)(nextTagIndex - i))) {
                FAIL(SWIFTSOUP_FALLBACK_CONTAINS_NULL);
            }
            if (!sawHtmlTag || (sawHtmlTag && !sawBodyTag && !inHead)) {
                int j = i;
                int sawNonWhitespace = 0;
                while (j < nextTagIndex) {
                    if (!isWhitespaceTable[bytes[j]]) {
                        sawNonWhitespace = 1;
                        break;
                    }
                    j++;
                }
                if (sawNonWhitespace) {
                    if (!sawHtmlTag) {
                        sawContentBeforeHtml = 1;
                    }
                    if (sawHtmlTag && !sawBodyTag && !inHead) {
                        sawBodyTag = 1;
                    }
                }
            }
            i = nextTagIndex;
            continue;
        }
        sawTagDelimiter = 1;
        if (i + 1 >= length) {
            FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
        }
        uint8_t next = bytes[i + 1];
        if (next == 0x21) { // !
            if (i + 4 < length &&
                bytes[i + 2] == 0x2D &&
                bytes[i + 3] == 0x2D &&
                bytes[i + 4] == 0x2D) {
                FAIL(SWIFTSOUP_FALLBACK_COMMENT_DASH_DASH_DASH);
            }
            if (i + 3 < length && bytes[i + 2] == 0x2D && bytes[i + 3] == 0x2D) {
                int j = i + 4;
                while (j + 2 < length) {
                    if (bytes[j] == 0x2D && bytes[j + 1] == 0x2D && bytes[j + 2] == 0x3E) {
                        i = j + 3;
                        break;
                    }
                    j++;
                }
                if (j + 2 >= length) {
                    FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
                }
                continue;
            }
            int j = i + 2;
            while (j < length && bytes[j] != 0x3E) {
                j++;
            }
            if (j >= length) {
                FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
            }
            i = j + 1;
            continue;
        }
        if (next == 0x2F) { // </
            int nameStart = i + 2;
            int nameEnd = nameStart;
            while (nameEnd < length && isNameCharTable[bytes[nameEnd]]) {
                uint8_t b = bytes[nameEnd];
                if (b == 0x3A) {
                    FAIL(SWIFTSOUP_FALLBACK_NAMESPACED_TAG);
                }
                nameEnd++;
            }
            if (nameEnd == nameStart) {
                FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
            }
            if (nameEnd < length && bytes[nameEnd] >= 0x80) {
                FAIL(SWIFTSOUP_FALLBACK_NON_ASCII_TAG_NAME);
            }
            tag_id tagId = tag_id_for_ascii_lowercase(bytes, nameStart, nameEnd);
            if (is_void_tag(tagId)) {
                FAIL(SWIFTSOUP_FALLBACK_VOID_END_TAG);
            }
            if (is_table_structure_tag(tagId)) {
                if (tableCount > 0) {
                    if (tagId == TAG_TABLE) {
                        tableCount -= 1;
                    } else {
                        TableState state = tableStack[tableCount - 1];
                        if (tagId == TAG_CAPTION) {
                            if (state.captionDepth > 0) state.captionDepth -= 1;
                        } else if (tagId == TAG_TBODY || tagId == TAG_THEAD || tagId == TAG_TFOOT) {
                            if (state.sectionDepth > 0) state.sectionDepth -= 1;
                        } else if (tagId == TAG_TR) {
                            if (state.trDepth > 0) state.trDepth -= 1;
                            state.cellDepth = 0;
                        } else if (tagId == TAG_TD || tagId == TAG_TH) {
                            if (state.cellDepth > 0) state.cellDepth -= 1;
                        }
                        if (tableCount > 0) {
                            tableStack[tableCount - 1] = state;
                        }
                    }
                }
            }
            if (tagId == TAG_SELECT) {
                if (selectDepth > 0) {
                    selectDepth -= 1;
                }
            }
            if (is_heading_tag(tagId)) {
                headingOpen = 0;
            }
            int formatId = formatting_tag_id(tagId);
            if (formatId >= 0) {
                int idx = -1;
                for (int k = formatCount - 1; k >= 0; k--) {
                    if (formatStack[k] == (uint8_t)formatId) {
                        idx = k;
                        break;
                    }
                }
                if (idx >= 0) {
                    if (idx == formatCount - 1) {
                        formatCount -= 1;
                    } else {
                        FAIL(SWIFTSOUP_FALLBACK_FORMATTING_MISMATCH);
                    }
                }
            }
            if (tagId == TAG_HEAD) {
                inHead = 0;
            } else if (tagId == TAG_BODY) {
                sawBodyTag = 1;
            }
            if (openTagDepth > 0) {
                openTagDepth -= 1;
            }
            int j = nameEnd;
            while (j < length && bytes[j] != 0x3E) {
                j++;
            }
            if (j >= length) {
                FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
            }
            i = j + 1;
            continue;
        }
        if (next == 0x3F) { // <?
            int j = i + 2;
            while (j < length && bytes[j] != 0x3E) {
                j++;
            }
            if (j >= length) {
                FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
            }
            i = j + 1;
            continue;
        }
        if (!isNameCharTable[next]) {
            FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
        }
        int nameStart = i + 1;
        int nameEnd = nameStart;
        while (nameEnd < length && isNameCharTable[bytes[nameEnd]]) {
            uint8_t b = bytes[nameEnd];
            if (b == 0x3A) {
                FAIL(SWIFTSOUP_FALLBACK_NAMESPACED_TAG);
            }
            nameEnd++;
        }
        if (nameEnd == nameStart) {
            FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
        }
        if (nameEnd < length && bytes[nameEnd] >= 0x80) {
            FAIL(SWIFTSOUP_FALLBACK_NON_ASCII_TAG_NAME);
        }
        tag_id tagId = tag_id_for_ascii_lowercase(bytes, nameStart, nameEnd);
        if (tagId == TAG_HGROUP) {
            FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
        }
        if (tagId == TAG_TABLE) {
            if (tableCount > 0 && tableStack[tableCount - 1].cellDepth == 0) {
                FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
            }
            TableState state = {0, 0, 0, 0};
            TABLE_PUSH(state);
        } else if (tableCount == 0 && is_table_structure_tag(tagId)) {
            FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
        } else if (tableCount > 0) {
            TableState state = tableStack[tableCount - 1];
            if (state.captionDepth > 0 && is_table_structure_tag(tagId)) {
                FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
            }
            if (tagId == TAG_CAPTION) {
                if (state.captionDepth > 0) {
                    FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
                }
                state.captionDepth += 1;
            } else if (tagId == TAG_TBODY || tagId == TAG_THEAD || tagId == TAG_TFOOT) {
                if (state.captionDepth > 0) {
                    FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
                }
                state.sectionDepth += 1;
            } else if (tagId == TAG_TR) {
                if (state.captionDepth > 0) {
                    FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
                }
                state.trDepth += 1;
                state.cellDepth = 0;
            } else if (tagId == TAG_TD || tagId == TAG_TH) {
                if (state.captionDepth > 0 || state.trDepth == 0) {
                    FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
                }
                state.cellDepth += 1;
            }
            if (state.captionDepth == 0 && state.trDepth == 0) {
                if (!is_table_outside_row_allowed(tagId)) {
                    FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
                }
            }
            tableStack[tableCount - 1] = state;
        }
        if (is_heading_tag(tagId)) {
            if (headingOpen) {
                FAIL(SWIFTSOUP_FALLBACK_FORMATTING_MISMATCH);
            }
            headingOpen = 1;
        }
        if (tagId == TAG_P && formatCount > 0) {
            FAIL(SWIFTSOUP_FALLBACK_FORMATTING_MISMATCH);
        }
        if (tagId == TAG_HTML) {
            if (sawContentBeforeHtml) {
                FAIL(SWIFTSOUP_FALLBACK_HEAD_BODY_PLACEMENT);
            }
            sawHtmlTag = 1;
        } else if (!sawHtmlTag) {
            // tags before html handled later
        }
        if (sawHtmlTag && !sawBodyTag) {
            if (tagId == TAG_HEAD) {
                inHead = 1;
            } else if (tagId == TAG_BODY) {
                sawBodyTag = 1;
                inHead = 0;
            } else if (inHead) {
                if (!is_head_allowed_tag(tagId)) {
                    inHead = 0;
                    sawBodyTag = 1;
                }
            } else if (!is_head_allowed_tag(tagId)) {
                sawBodyTag = 1;
            }
        } else if (tagId == TAG_BODY) {
            if (!sawHtmlTag && (sawContentBeforeHtml || openTagDepth > 0)) {
                FAIL(SWIFTSOUP_FALLBACK_HEAD_BODY_PLACEMENT);
            }
        }

        int j = nameEnd;
        int sawTagEnd = 0;
        int sawSelfClosing = 0;
        while (j < length) {
            while (j < length && isWhitespaceTable[bytes[j]]) {
                j++;
            }
            if (j >= length) {
                FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
            }
            if (bytes[j] == 0x3E) { // >
                j++;
                sawTagEnd = 1;
                break;
            }
            if (bytes[j] == 0x2F && j + 1 < length && bytes[j + 1] == 0x3E) { // />
                j += 2;
                sawTagEnd = 1;
                sawSelfClosing = 1;
                break;
            }
            int attrStart = j;
            while (j < length
                   && !isWhitespaceTable[bytes[j]]
                   && bytes[j] != 0x3D
                   && bytes[j] != 0x3E
                   && bytes[j] != 0x2F) {
                uint8_t b = bytes[j];
                if (b >= 0x80) {
                    FAIL(SWIFTSOUP_FALLBACK_NON_ASCII_ATTRIBUTE_NAME);
                }
                if (b == 0x22 || b == 0x27 || b == 0x00 || b == 0x3C || b == 0x3E) {
                    FAIL(SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE);
                }
                j++;
            }
            if (attrStart == j) {
                FAIL(SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE);
            }
            int booleanIndex = boolean_attribute_index(bytes, attrStart, j);
            while (j < length && isWhitespaceTable[bytes[j]]) {
                j++;
            }
            if (j < length && bytes[j] == 0x3D) { // =
                j++;
                while (j < length && isWhitespaceTable[bytes[j]]) {
                    j++;
                }
                if (j >= length) {
                    FAIL(SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE);
                }
                if (bytes[j] == 0x22 || bytes[j] == 0x27) {
                    uint8_t quote = bytes[j];
                    j++;
                    if (j >= length) {
                        FAIL(SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE);
                    }
                    const uint8_t *start = bytes + j;
                    const void *found = memchr(start, quote, (size_t)(length - j));
                    if (!found) {
                        FAIL(SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE);
                    }
                    const uint8_t *end = (const uint8_t *)found;
                    if (memchr(start, 0x00, (size_t)(end - start))) {
                        FAIL(SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE);
                    }
                    j = (int)(end - bytes) + 1;
                } else {
                    if (bytes[j] == 0x3C || bytes[j] == 0x3D) {
                        FAIL(SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE);
                    }
                    while (j < length && !isWhitespaceTable[bytes[j]] && bytes[j] != 0x3E) {
                        uint8_t b = bytes[j];
                        if (b == 0x3C || b == 0x22 || b == 0x27) {
                            FAIL(SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE);
                        }
                        j++;
                    }
                }
                if (booleanIndex >= 0) {
                    if (recordBoolean) {
                        recordBoolean(booleanIndex, 0, ctx);
                    }
                    if (booleanBuf) {
                        boolean_occurrences_append(booleanBuf, booleanIndex, 0);
                    }
                }
            } else {
                if (booleanIndex >= 0) {
                    if (recordBoolean) {
                        recordBoolean(booleanIndex, 1, ctx);
                    }
                    if (booleanBuf) {
                        boolean_occurrences_append(booleanBuf, booleanIndex, 1);
                    }
                }
            }
        }
        int isSelfClosing = 0;
        if (!sawTagEnd) {
            FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
        }
        if (sawSelfClosing) {
            isSelfClosing = 1;
        } else if (j > 0) {
            int scan = j - 1;
            while (scan > nameEnd && isWhitespaceTable[bytes[scan]]) {
                scan--;
            }
            if (bytes[scan] == 0x2F) {
                isSelfClosing = 1;
            }
        }
        if (tagId == TAG_NONE && recordSelfClosing) {
            int tagLen = nameEnd - nameStart;
            uint8_t inlineBuf[64];
            uint8_t *buf = inlineBuf;
            if (tagLen > 64) {
                buf = (uint8_t *)malloc((size_t)tagLen);
                if (!buf) {
                    FAIL(SWIFTSOUP_FALLBACK_MALFORMED_TAG);
                }
            }
            for (int k = 0; k < tagLen; k++) {
                buf[k] = asciiLowerTable[bytes[nameStart + k]];
            }
            recordSelfClosing(buf, tagLen, isSelfClosing, ctx);
            if (buf != inlineBuf) {
                free(buf);
            }
        }
        if (!isSelfClosing && tagId == TAG_SCRIPT) {
            int newIndex = skip_raw_text(bytes, length, "script", 6, j);
            if (newIndex >= 0) {
                i = newIndex;
                continue;
            }
            FAIL(SWIFTSOUP_FALLBACK_RAW_TEXT_UNTERMINATED);
        }
        if (!isSelfClosing && tagId == TAG_STYLE) {
            int newIndex = skip_raw_text(bytes, length, "style", 5, j);
            if (newIndex >= 0) {
                i = newIndex;
                continue;
            }
            FAIL(SWIFTSOUP_FALLBACK_RAW_TEXT_UNTERMINATED);
        }
        if (!isSelfClosing && tagId == TAG_TEXTAREA) {
            int newIndex = skip_raw_text(bytes, length, "textarea", 8, j);
            if (newIndex >= 0) {
                i = newIndex;
                continue;
            }
            FAIL(SWIFTSOUP_FALLBACK_RAW_TEXT_UNTERMINATED);
        }
        int formatId = formatting_tag_id(tagId);
        if (formatId >= 0 && !isSelfClosing && !is_void_tag(tagId)) {
            FORMAT_PUSH(formatId);
        }
        if (tagId == TAG_SELECT && !isSelfClosing) {
            selectDepth += 1;
        }
        if (!isSelfClosing) {
            openTagDepth += 1;
        }
        i = j;
    }

    if (!sawTagDelimiter) {
        FAIL(SWIFTSOUP_FALLBACK_NO_TAG_DELIMITER);
    }
    if (headingOpen || formatCount > 0) {
        FAIL(SWIFTSOUP_FALLBACK_FORMATTING_MISMATCH);
    }
    if (selectDepth > 0) {
        FAIL(SWIFTSOUP_FALLBACK_TABLE_HEURISTICS);
    }

    if (reasonOut) {
        *reasonOut = SWIFTSOUP_FALLBACK_NONE;
    }
    if (formatStack != formatInline) free(formatStack);
    if (tableStack != tableInline) free(tableStack);
    return 0;
}

int swiftsoup_should_fallback(const uint8_t *bytes, int length,
                              swiftsoup_record_selfclosing_fn recordSelfClosing,
                              swiftsoup_record_boolean_index_fn recordBoolean,
                              void *ctx,
                              swiftsoup_fallback_reason *reasonOut) {
    return swiftsoup_should_fallback_internal(bytes, length, recordSelfClosing, recordBoolean, NULL, ctx, reasonOut);
}

int swiftsoup_should_fallback_collect(const uint8_t *bytes, int length,
                                      swiftsoup_record_selfclosing_fn recordSelfClosing,
                                      void *ctx,
                                      swiftsoup_fallback_reason *reasonOut,
                                      int32_t **outBooleanPairs,
                                      int32_t *outBooleanCount) {
    boolean_occurrences_buf booleanBuf;
    boolean_occurrences_init(&booleanBuf);
    int result = swiftsoup_should_fallback_internal(bytes, length, recordSelfClosing, NULL, &booleanBuf, ctx, reasonOut);
    boolean_occurrences_finish(&booleanBuf, outBooleanPairs, outBooleanCount);
    return result;
}
