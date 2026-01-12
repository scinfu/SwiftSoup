#ifndef SWIFTSOUP_SCAN_H
#define SWIFTSOUP_SCAN_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*swiftsoup_record_selfclosing_fn)(const uint8_t *name, int length, int isSelfClosing, void *ctx);
typedef void (*swiftsoup_record_boolean_index_fn)(int index, int isBoolean, void *ctx);

void swiftsoup_scan_hints(const uint8_t *bytes, int length,
                          swiftsoup_record_selfclosing_fn recordSelfClosing,
                          swiftsoup_record_boolean_index_fn recordBoolean,
                          void *ctx);

void swiftsoup_scan_hints_collect(const uint8_t *bytes, int length,
                                  swiftsoup_record_selfclosing_fn recordSelfClosing,
                                  void *ctx,
                                  int32_t **outBooleanPairs,
                                  int32_t *outBooleanCount);

void swiftsoup_free_int32(int32_t *ptr);

typedef enum {
    SWIFTSOUP_FALLBACK_NONE = 0,
    SWIFTSOUP_FALLBACK_NO_TAG_DELIMITER = 1,
    SWIFTSOUP_FALLBACK_CONTAINS_NULL = 2,
    SWIFTSOUP_FALLBACK_COMMENT_DASH_DASH_DASH = 3,
    SWIFTSOUP_FALLBACK_MALFORMED_TAG = 4,
    SWIFTSOUP_FALLBACK_NON_ASCII_TAG_NAME = 5,
    SWIFTSOUP_FALLBACK_NAMESPACED_TAG = 6,
    SWIFTSOUP_FALLBACK_TABLE_HEURISTICS = 7,
    SWIFTSOUP_FALLBACK_HEAD_BODY_PLACEMENT = 8,
    SWIFTSOUP_FALLBACK_FORMATTING_MISMATCH = 9,
    SWIFTSOUP_FALLBACK_VOID_END_TAG = 10,
    SWIFTSOUP_FALLBACK_NON_ASCII_ATTRIBUTE_NAME = 11,
    SWIFTSOUP_FALLBACK_MALFORMED_ATTRIBUTE = 12,
    SWIFTSOUP_FALLBACK_RAW_TEXT_UNTERMINATED = 13
} swiftsoup_fallback_reason;

int swiftsoup_should_fallback(const uint8_t *bytes, int length,
                              swiftsoup_record_selfclosing_fn recordSelfClosing,
                              swiftsoup_record_boolean_index_fn recordBoolean,
                              void *ctx,
                              swiftsoup_fallback_reason *reasonOut);

int swiftsoup_should_fallback_collect(const uint8_t *bytes, int length,
                                      swiftsoup_record_selfclosing_fn recordSelfClosing,
                                      void *ctx,
                                      swiftsoup_fallback_reason *reasonOut,
                                      int32_t **outBooleanPairs,
                                      int32_t *outBooleanCount);

#ifdef __cplusplus
}
#endif

#endif /* SWIFTSOUP_SCAN_H */
