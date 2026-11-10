# Change Log

All notable changes to this project will be documented in this file.

## Unreleased
* Keep `<p>` scope tracking current when elements close from the top of the open-element stack, so parsing deeply nested tables or formatting elements is linear instead of quadratic. Preserve cache invalidation during manual token processing, where callers may rename open elements.
* Remove selected elements per parent in `Elements.remove()`, so removing many siblings is linear instead of quadratic. Compact only the affected sibling suffix and preserve custom subclass `remove()` calls, ordering, and errors.
* Parse each `:has()` selector-list branch independently and support leading adjacent/general sibling combinators, including sibling chains and descendants. Preserve escaped and nested commas, candidate scoping, and cached evaluator isolation; avoid stale subtree result snapshots when sibling attributes change outside the selection root.
* Isolate mutable parser-built OR evaluator graphs in the default query cache so editing a parsed selector cannot change later queries. Preserve established AND error handling in indexed selection and honor same-module evaluator overrides instead of substituting built-in index semantics.
* Check `OrderedSet.isSubset(of:)` without restarting single-pass inputs. Such sequences no longer lose earlier matches or depend on hash iteration order; successful checks stop once all required members are found. Collections retain their specialized membership checks (including Set and Range), and singleton receivers need only one check without temporary membership storage. Empty receivers do not consume the input. Temporary membership storage for multi-member, non-Collection inputs is bounded by receiver size.
* Preserve stored representatives in `OrderedSet.swapObject(_:with:)`, including canonically equivalent String bytes. Equal lookup arguments no longer replace or remain retained as members; swapping the same member is a no-op. Explicit equal-value replacement through `append` remains unchanged.
* Decode paired text escapes correctly in `TokenQueue.unescape` and `:contains` / `:containsOwn` / `:containsData`. Runs of backslashes now quote one scalar at a time, including inside graphemes, rather than duplicating escapes. A lone trailing backslash is still dropped. Regex arguments and CSS hexadecimal identifier decoding remain separate and unchanged.
* Preserve the exact consumed spelling of balanced expressions while splitting compound selectors. Missing numeric closing parentheses now fail consistently after combinators and within partial outer expressions, instead of being synthesized. Partial literal text/regex input is no longer changed by an invented closing delimiter. Public `TokenQueue.chompBalanced` partial-result behavior and existing nonnumeric EOF tolerance remain unchanged; this is not a new browser-equivalent EOF policy.
* Parse complete numeric selectors with ASCII digits, CSS whitespace and checked Int conversion. Correct implicit negative nth coefficients and reject malformed or out-of-range input with a normal parse error rather than trapping. Match all supported Int coefficients/offsets without arithmetic overflow and preserve An+B semantics in evaluator serialization. This intentionally stops accepting trailing garbage and non-CSS whitespace; no broader CSS token/comment/escape or `of S` support is added.
* Keep validated absent attribute reads deferred and reject empty case-insensitive value queries before changing storage. Retain the existing bounded 32-name prefilter and exact comparisons. Validate both UTF-8 split partitions without recreating the entire text.
* Fix regex capture extraction to use Foundation UTF-16 ranges, preventing Unicode-offset crashes and preserving captures within combining, emoji, and CRLF graphemes. `Matcher.group` now returns nil for invalid group indices or without a current match; participating empty captures remain empty strings. Exhausted matchers stop advancing their cursor. Pattern compilation reuse and legacy option handling are unchanged.
* Empty child-list insertions and clearing an already empty Element no longer invalidate source/query/text caches or advance mutation tokens. Indexed insertions still validate bounds before returning. Empty TextNode insertion is still a real structural mutation.
* Make virtual `abs:` attribute presence case-insensitive, matching value lookup. Invalid virtual suffixes fall back to physical attribute presence. Fresh TextNode byte-based presence checks now initialize the same deferred storage as String checks, without marking content edited. These correct previously false results; URL resolution and text-splitting rules remain unchanged.
* Define `TextNode.splitText(_:)` offsets as Swift Characters and `splitText(utf8Offset:)` offsets as exact Unicode scalar-aligned UTF-8 byte positions. End offsets produce empty tails. Invalid ranges, partial UTF-8 scalars, and malformed byte storage throw before mutation; byte splits no longer silently round to a grapheme boundary.
* Keep text-dependent selector caches current after child appends, detach retained children during `empty()` / content replacement, and preserve original insertion gaps when moving existing siblings. Self replacement is a no-op; invalid offsets and cyclic insertions/replacements are rejected before detaching any inputs.
* Resolve node URLs through the public base-URI byte getter, including absent base URIs, instead of force-unwrapping storage.
* Preserve byte-array TextNode presence initialization and the complete earlier public-behavior regression suites while integrating the alternative canonical-name refinement. Ambiguous deferred attributes now materialize; their reads still preserve source reuse and mutation versions.
* Reduce cold deferred-name validation work with a bounded mask prefilter and exact collision checks. Keep ambiguous batches and byte-distinct Unicode names on the same canonical materialization contract.
* Make deferred attribute lookups and serialization agree with materialized storage. Preserve the existing first-position/last-value rule for exact duplicate names, first matching case-variant lookup, trimmed valid keys, and byte-name precedence. Ordinary unique attribute batches remain deferred; ambiguous batches materialize before reads rather than changing their answers later.
* Use wrapping integer arithmetic in `Attribute.hashCode()` so hash mixing cannot trap on overflow.
* Avoid repeated membership scans when exposing singly owned attribute lists or iterators. Mutation notifications still validate every owner by identity, and multi-owner cleanup remains unchanged.
* Include comment contents in `Element.data()` and `:containsData`, as documented, in descendant document order. Traverse iteratively without intermediate subtree strings or materializing single-slice data nodes. Custom DataNode getter overrides remain respected. Queries previously ignoring comment contents may now match.
* Observe direct `Attribute.setKey` / `setValue` edits through every live owning collection and node, including references shared by `put` / `addAll`. Removed or replaced references no longer invalidate former owners. Reads that materialize deferred text/data do not count as DOM mutations.
* Clone mutable attribute objects independently, including implicit boolean attributes, while retaining immutable byte storage sharing. Cloned DOM mutations no longer change the original. Attribute keys that are empty after trimming are rejected before mutation.
* Keep attribute indexes consistent with case-insensitive getters when case variants or direct renames introduce duplicate names: the first matching attribute wins and elements appear once.
* Make deferred text and script-data attributes authoritative before public attribute access or edits. Subsequent reads/appends cannot overwrite edits or restore removed content. Direct non-element attribute edits invalidate text/selector caches and serialized source reuse.
* Return each element once from class indexes even when `class` repeats a token or case variant. Preserve traversal order in both combined and class-only rebuilds.
* Distinguish missing physical attributes from present empty values in equality, inequality, and regex predicates. Empty prefix/suffix/substring operands now match nothing, as required by CSS; existing SwiftSoup case/whitespace normalization is otherwise unchanged.
* Keep attribute fast plans consistent with the parser by delegating non-ASCII attribute selectors to it. Preserve parsed virtual `abs:` predicates with quoted empty operands, and recognize padded `abs:` keys in the public value getter.
* Honor case-preserving attribute updates in byte-slice predicates without dropping the lowercase-key fast path.
* Preserve value and regex predicates when an attribute-presence index seeds a compound selector. Presence alone does not prove a prefix, suffix, substring, or regex match. Keep exact-index shortcuts and check single-predicate `And` evaluators consistently.
* Resolve virtual `abs:` attribute presence through `hasAttr`, not the physical attribute-name index, and invalidate affected ancestor/subtree selector results when the base URI changes. Physical attribute indexes and text caches remain intact.
* Route unescaped punctuation in bare ID selectors through the parser, matching compound-selector validation. Literal punctuation in an ID must be escaped (for example `#x\]` for ID `x]`) or supplied through `getElementById`.
* Treat `getElementById` arguments as literal IDs, retaining leading/trailing whitespace. Callers that intentionally accepted padded input must now trim it themselves. Recognize form feed as a descendant combinator rather than an ID byte in the selector fast path.
* Preserve escaped trailing spaces and non-ASCII identifier content while removing CSS query padding, including direct parser and multi-root selection paths.
* Scan balanced and compound selectors at code-point boundaries; handle backslash parity and paired quote delimiters correctly. Unicode prepend characters no longer absorb closing parentheses or combinators. The public balanced scanner still supports multi-scalar delimiters.
* Match class tokens, never an entire whitespace-separated class list. Use HTML's five ASCII whitespace separators consistently in class getters, predicates, and indexes; vertical tab (U+000B) remains part of a class token.
* Preserve byte-distinct Unicode selector spellings in the parser, evaluator, fast-plan, and per-root result caches. Custom `QueryParserCache` implementations must also use code-point-exact key equality rather than Swift's canonical-equivalence equality.
* Generate ID/class escapes by Unicode scalar, preserving combining marks (including immediately after `#`/`.`), emoji, leading digits, controls, and literal backslashes. Escape spaces as code points so query trimming does not remove significant trailing spaces. CSS represents U+0000 as U+FFFD, not as a literal NUL.
* Preserve whitespace decoded from ID escapes during indexed selection. Anchor `:has(> ...)` against each candidate element and avoid the collect-once shortcut for root-dependent predicates.
* Decode CSS hexadecimal escapes in ID and class selectors: one to six hex digits, one optional CSS whitespace terminator (including CRLF), and U+FFFD for zero, surrogate, or out-of-range code points. Preserve the complete escape when splitting compound selectors.
* Compatibility: `p#\61` now matches ID `a`, not ID `61`. Clients that intended the old literal value should use `p#61` or `p#\36 1`; an ID containing a literal backslash followed by `61` is selected by `p#\\61`. ID/class parsing also accepts non-ASCII identifier code points so combining marks following hex digits are retained. Existing non-hex escapes remain supported. This does not change tag/attribute escape parsing or the separate text/regex unescape behavior.

## [2.3.2](https://github.com/scinfu/SwiftSoup/tree/2.3.2)
* Renamed Selector Class to CssSelector

## [1.7.4](https://github.com/scinfu/SwiftSoup/tree/1.7.4)
* Removed Some warnings
* Swift 4.2

## [1.7.1](https://github.com/scinfu/SwiftSoup/tree/1.7.1)
* Backward compatibility for Swift < 4.1

## [1.7.0](https://github.com/scinfu/SwiftSoup/tree/1.7.0)
* Removed StringBuilder from Element.cssSelector
* Lint Code
* Swift 4.1

## [1.6.5](https://github.com/scinfu/SwiftSoup/tree/1.6.5)
* Removed StringBuilder from Element.cssSelector
* Lint Code


## [1.6.4](https://github.com/scinfu/SwiftSoup/tree/1.6.4)
* Add newer simulators to targeted devices to build with Carthage [tvOS]

## [1.6.3](https://github.com/scinfu/SwiftSoup/tree/1.6.3)

* Add newer tvOS simulators to targeted devices to build with Carthage.
* Add newer watchOS simulators to targeted devices to build with Carthage.
