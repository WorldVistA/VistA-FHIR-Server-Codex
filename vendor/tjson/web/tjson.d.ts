/* tslint:disable */
/* eslint-disable */

export type BareStyle = "prefer" | "none";
export type StringStyle = "quoted" | "bare" | "marked";
/**
 * StringStyle plus the two spellings it retired, so existing code still compiles.
 * @deprecated Write a StringStyle. `"prefer"` means `"bare"` and `"none"` means `"quoted"`.
 */
export type StringStyleCompat = StringStyle | "prefer" | "none";
export type FoldStyle = "auto" | "fixed" | "none";
export type MultilineStyle = "floating" | "bold" | "boldFloating" | "boldLight" | "transparent" | "light" | "foldingQuotes";
export type TableUnindentStyle = "left" | "auto" | "floating" | "none";
export type StringArrayStyle = "spaces" | "preferSpaces" | "comma" | "preferComma" | "none";
export type IndentGlyphStyle = "auto" | "fixed" | "none";
export type IndentGlyphMarkerStyle = "compact" | "separate";
export type Eol = "lf" | "crlf";

export interface StringifyOptions {
    /** Start from a preset canonical configuration (one pair per line, no packing, no tables). */
    canonical?: boolean;
    /** Wrap width in columns. 0 means unlimited. Values between 1 and 19 are clamped to 20. */
    wrapWidth?: number;
    /** Force explicit `[` / `{` indent markers on arrays and objects, even for single-step indents that would normally be implicit. */
    forceMarkers?: boolean;
    /** How a string value announces itself: `"quoted"` always quotes; `"bare"` uses the unquoted form where the spec permits, its opening quote being the space in front of it; `"marked"` writes that space as `_` so it can be seen. Default: `"bare"`. */
    bareStrings?: StringStyleCompat;
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
    /** @experimental Maximum number of lines in a minimal (`) multiline block before falling back to a bold style multiline block (``), applies with multilineStyle: "floating" only.  The idea is that we want to reserve a minimal style multiline for short multilines only for "floating".  "light" has a similar look with no max line fallback.  Default: `10`. */
    multilineMaxLines?: number;
    /** Enable table rendering for uniform arrays-of-objects. Default: `true`. */
    tables?: boolean;
    /** @experimental Allow folding long table rows across continuation lines.  (Not currently implemented.  It is probably best to avoid this option for now as it may change.)  Default: `false`. */
    tableFold?: boolean;
    /** Whether to push wide tables toward the left margin. Independent of `indentGlyphStyle`. Default: `"auto"`. */
    tableUnindentStyle?: TableUnindentStyle;
    /** Minimum rows required to render a table. Default: `3`. */
    tableMinRows?: number;
    /** Minimum columns required to render a table. Default: `3`. */
    tableMinColumns?: number;
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
    /** Whether to wrap deeply-nested objects and arrays in `/<` `/>` glyphs to reduce visual depth. Independent of `tableUnindentStyle`. Default: `"auto"`. */
    indentGlyphStyle?: IndentGlyphStyle;
    /** Where to place the opening `/<` glyph. Default: `"compact"`. */
    indentGlyphMarkerStyle?: IndentGlyphMarkerStyle;
    /** @experimental Spacing multiplier between packed key-value pairs. Valid values: 1–4 (clamped); actual spaces = value × 2. Default: `2` (4 spaces). May be changed or removed in a future version. */
    kvPackMultiple?: number;
    /** Line ending used between output lines. `"lf"` (default) keeps output canonical and byte-identical across platforms; `"crlf"` is for a consumer that genuinely requires CRLF. Being on Windows is not itself a reason, as most Windows tooling handles LF, and TJSON survives whole-file LF↔CRLF conversion, so a consumer can usually convert on its own. Default: `"lf"`. */
    eol?: Eol;
}

export interface ParseOptions {
    /** Revive integers beyond Number.MAX_SAFE_INTEGER as BigInt (exact). When
     * false (the default), such integers throw rather than silently losing
     * precision as a JS number. Default: `false`. */
    bigints?: boolean;
}

/** Parse a TJSON string and return a JavaScript value.
 *
 * Inherently precision-bounded: tjson carries numbers at arbitrary
 * precision, but a JS number is an f64. Plain float precision loss is
 * accepted (you chose JS values); integers a JS number cannot hold exactly
 * throw by default or become BigInt with `{ bigints: true }`, and numbers
 * JSON.parse would turn into ±Infinity throw. For a lossless pipeline use
 * `toJson` (exact text out) with your own `JSON.parse` reviver. */
export function parse(input: string, options?: ParseOptions): any;

/** Parse a TJSON string and return a JSON string. Never lossy: numbers of
 * any size and precision pass through as exact text. */
export function toJson(input: string): string;

/** Render a JSON string as TJSON, with optional options. Never lossy:
 * numbers of any size and precision pass through as exact text. */
export function fromJson(input: string, options?: StringifyOptions): string;

/** Render a JavaScript value as TJSON, with optional options. */
export function stringify(input: any, options?: StringifyOptions): string;

/** The tjson version this module was built from, reported from inside the wasm
 * so it cannot disagree with the code actually running. */
export function version(): string;



/**
 * The tjson version this module was built from.
 *
 * Reported from inside the wasm rather than read from package metadata,
 * because the metadata sits beside the artifact and can disagree with it: a
 * page holding a cached `.wasm` will show fresh surroundings while running old
 * code, and nothing outside the module can tell. This string cannot be wrong
 * about which build is executing.
 *
 * A function rather than a constant only because a `&'static str` cannot cross
 * the wasm boundary as a module constant. `d3.version`, `vue.version` and
 * `ts.version` are the same idea. The C API exposes the same constant through
 * `tjson_version()`.
 */
export function version(): string;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly fromJson: (a: number, b: number, c: any) => [number, number, number, number];
    readonly parse: (a: number, b: number, c: any) => [number, number, number];
    readonly stringify: (a: any, b: any) => [number, number, number, number];
    readonly toJson: (a: number, b: number) => [number, number, number, number];
    readonly version: () => [number, number];
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __externref_table_dealloc: (a: number) => void;
    readonly __wbindgen_free: (a: number, b: number, c: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
