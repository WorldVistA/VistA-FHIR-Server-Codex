/* tslint:disable */
/* eslint-disable */

export type BareStyle = "prefer" | "none";
export type FoldStyle = "auto" | "fixed" | "none";
export type MultilineStyle = "floating" | "bold" | "boldFloating" | "transparent" | "light" | "foldingQuotes";
export type TableUnindentStyle = "left" | "auto" | "floating" | "none";
export type StringArrayStyle = "spaces" | "preferSpaces" | "comma" | "preferComma" | "none";
export type IndentGlyphStyle = "auto" | "fixed" | "none";
export type IndentGlyphMarkerStyle = "compact" | "separate";

export interface StringifyOptions {
    /** Start from a preset canonical configuration (one pair per line, no packing, no tables). */
    canonical?: boolean;
    /** Wrap width in columns. 0 means unlimited. Values between 1 and 19 are clamped to 20. */
    wrapWidth?: number;
    /** Force explicit `[` / `{` indent markers on arrays and objects, even for single-step indents that would normally be implicit. */
    forceMarkers?: boolean;
    /** Whether to use bare (unquoted) strings. Default: `"prefer"`. */
    bareStrings?: BareStyle;
    /** Whether to use bare (unquoted) object keys. Default: `"prefer"`. */
    bareKeys?: BareStyle;
    /** Allow packing multiple key-value pairs onto one line. Default: `true`. */
    inlineObjects?: boolean;
    /** Allow packing multiple array items onto one line. Default: `true`. */
    inlineArrays?: boolean;
    /** Allow multiline string blocks for strings containing newlines. Default: `true`. */
    multilineStrings?: boolean;
    /** Multiline block style. Default: `"bold"`. */
    multilineStyle?: MultilineStyle;
    /** Minimum number of lines before a multiline block is used. Default: `1`. */
    multilineMinLines?: number;
    /** Maximum number of lines in a multiline block before falling back. Default: `10`. */
    multilineMaxLines?: number;
    /** Enable table rendering for uniform arrays-of-objects. Default: `true`. */
    tables?: boolean;
    /** Allow folding long table rows across continuation lines. Default: `false`. */
    tableFold?: boolean;
    /** How to horizontally reposition tables using indent-offset glyphs. Default: `"auto"`. */
    tableUnindentStyle?: TableUnindentStyle;
    /** Minimum rows required to render a table. Default: `3`. */
    tableMinRows?: number;
    /** Minimum columns required to render a table. Default: `3`. */
    tableMinCols?: number;
    /** Minimum fraction [0–1] of rows sharing a column before it's included. Default: `0.8`. */
    tableMinSimilarity?: number;
    /** If any column's content width (including the leading space on bare string values) exceeds this value, the table is abandoned and falls back to block layout. `0` means no limit. Default: `40`. */
    tableColumnMaxWidth?: number;
    /** How to pack short-string arrays onto one line. Default: `"preferComma"`. */
    stringArrayStyle?: StringArrayStyle;
    /** Set all fold styles at once. More specific fold options override this if also set. */
    fold?: FoldStyle;
    /** How to fold long numbers across lines. Default: `"auto"`. */
    numberFoldStyle?: FoldStyle;
    /** How to fold bare strings. Default: `"auto"`. */
    stringBareFoldStyle?: FoldStyle;
    /** How to fold quoted strings. Default: `"auto"`. */
    stringQuotedFoldStyle?: FoldStyle;
    /** How to fold multiline string continuation lines. Default: `"none"`. */
    stringMultilineFoldStyle?: FoldStyle;
    /** When to emit `/<` `/>` indent-offset glyphs. Default: `"auto"`. */
    indentGlyphStyle?: IndentGlyphStyle;
    /** Where to place the opening `/<` glyph. Default: `"compact"`. */
    indentGlyphMarkerStyle?: IndentGlyphMarkerStyle;
}

/** Parse a TJSON string and return a JSON string. */
export function toJson(input: string): string;

/** Render a JSON string as TJSON, with optional options. */
export function fromJson(input: string, options?: StringifyOptions): string;

/** Render a JavaScript value as TJSON, with optional options. */
export function stringify(input: any, options?: StringifyOptions): string;



/**
 * Parse a TJSON string and return a JavaScript value.
 *
 * Accepts the full TJSON format: bare strings and keys, multiline strings,
 * pipe tables, line folding, and comments. The output is a live JavaScript
 * value — object, array, string, number, boolean, or null.
 *
 * ```js
 * const value = parse("  name: Alice\n  age: 30");
 * // → { name: "Alice", age: 30 }
 * ```
 *
 * Throws an `Error` if the input is not valid TJSON.
 */
export function parse(input: string): any;
