// JS <-> wasm value transport for the tjson binding (see src/wasm.rs, which
// documents the design). Values cross the boundary as JSON text: one
// traversal both polices and carries the data, so nothing can be accepted
// that wasn't inspected.
//
// Everything in this file is internal to the generated wasm glue: JS package
// users never see these functions (the public surface is parse, stringify,
// toJson, fromJson). User-facing documentation lives on those, in the
// TypeScript types and npm README — comments here are for maintainers.

const HAS_RAW_JSON = typeof JSON.rawJSON === 'function';

function describe(key) {
  return key === '' ? 'the top-level value' : `key '${key}'`;
}

// The replacer runs once per node of every stringify — it is the hot path,
// and carries only checks that cannot live anywhere else. Hoisted to module
// scope so every call shares one function identity (no per-call closure,
// warm inline caches).
// Throwing is better than losing data that the user might expect to be
// preserved.  Users can stringify it themselves if they have a different need.
function strictStringifyReplacer(key, value) {
  switch (typeof value) {
    // tjson internally keeps arbitrary precision on numbers in json and tjson,
    // but javascript numbers do not.  As such, in some sense, any conversion
    // to javascript numbers can theoretically be lossy, but only because
    // javascript cannot hold the precision at all.
    // We error out when a newer javascript
    // would have maintained the round-trip precision.  The user knows that
    // js is only so precise, but perhaps not that their runtime is too old.
    case 'bigint': {
      // The definition of Number.isSafeInteger rejects any number that could
      // be the result of rounding a different integer, so a conversion that
      // lands in the safe range was exact. (A few values just outside —
      // ±2^53 itself, and larger integers a double happens to represent
      // exactly — could also be accepted without rawJSON, but distinguishing
      // them isn't worth the complexity, and the emitted digits are
      // identical via rawJSON anyway.)
      const asNumber = Number(value);
      if (Number.isSafeInteger(asNumber)) return asNumber;
      if (HAS_RAW_JSON) return JSON.rawJSON(value.toString());
      throw new TypeError(
        `BigInt at ${describe(key)} exceeds Number.MAX_SAFE_INTEGER and cannot be ` +
        `serialized exactly on this runtime (JSON.rawJSON is missing; it ships in ` +
        `Node 21+ and modern browsers); convert it to JSON yourself and use ` +
        `fromJson on the resulting string, or upgrade the runtime`);
    }

    case 'number': {
      // The only place NaN/Infinity are detectable: JSON.stringify itself
      // silently coerces them to null.
      if (!Number.isFinite(value)) {
        const kind = Number.isNaN(value) ? 'NaN' : 'Infinity';
        throw new TypeError(`${kind} at ${describe(key)} is not representable in JSON`);
      }
      break;
    }

    case 'object': {
      if (value === null || Array.isArray(value)) break;
      const prototype = Object.getPrototypeOf(value);
      // Null-prototype objects pass on purpose: plain data made with
      // Object.create(null), and JSON.rawJSON's marker objects (which
      // stringify consumes by brand), both live there.
      if (prototype !== Object.prototype && prototype !== null) {
        // Anything with a .toJSON() was already converted before being
        // processed by the replacer, so an instance arriving here has no
        // declared JSON form and serializing it would produce junk ({} or worse).
        const typeName = (value.constructor && value.constructor.name) || 'a non-plain object';
        throw new TypeError(
          `${typeName} at ${describe(key)} is not JSON data; ` +
          `give it a toJSON() or convert it to a plain object/array first`);
      }
      break;
    }

    // boolean, undefined, function, symbol: JSON.stringify's own semantics
    // handle these (booleans serialize; the rest mean "absent").
    //
    // Strings (keys included) pass untouched — deliberately no per-string
    // scan here: if one contains a lone surrogate, JSON.stringify emits it
    // as a \uXXXX escape (well-formed mode, ES2019) and the Rust side
    // rejects that escape loudly. Enforcement is guaranteed without paying
    // O(len) per string.
  }

  return value;
}

// Serialize a live JS value to JSON text with JSON.stringify semantics
// (toJSON honored, undefined means absent), rejecting loudly every value
// that has no JSON form. Stricter than JSON.stringify, on purpose.
export function valueToJsonText(root) {
  const json = JSON.stringify(root, strictStringifyReplacer);
  if (json === undefined) {
    throw new TypeError(
      'value is not JSON-serializable (undefined, a function, or a symbol at the top level)');
  }
  return json;
}

// Failure-path diagnostics only: called after the Rust side has already
// rejected our generated JSON text, to name WHICH string offended (an
// ill-formed string is the only invalid thing JSON.stringify can emit, so it
// also serves as the classifier: returning without throwing means the caller
// is looking at a genuine internal bug, not bad input). Checks keys as well
// as values. May be arbitrarily expensive — it never runs on the happy path.
export function throwNamingIllFormedString(root) {
  if (typeof String.prototype.isWellFormed !== 'function') return;
  JSON.stringify(root, function (key, value) {
    if (!key.isWellFormed()) {
      // Interpolating the key mangles the surrogate on display, but still
      // locates it for the reader.
      throw new TypeError(
        `object key '${key}' contains an unpaired surrogate ` +
        `(ill-formed UTF-16, usually a sign the string was truncated mid-character)`);
    }
    const type = typeof value;
    if (type === 'string' && !value.isWellFormed()) {
      throw new TypeError(
        `string at ${describe(key)} contains an unpaired surrogate ` +
        `(ill-formed UTF-16, usually a sign the string was truncated mid-character)`);
    }
    // Neutralize values plain JSON.stringify would choke on — this walk
    // exists only to locate strings.
    if (type === 'bigint') return 0;
    return value;
  });
}

const DIGIT_FORM = /^-?\d+$/;

// Reviver core, shared by both hoisted revivers below (hot path: a number
// sits on nearly every node of typical documents).
//
// Policy — tjson carries numbers at arbitrary precision; a JS number is an
// f64, so forcing JSON text into JS values is inherently float-lossy. The
// user chose that by asking for JS values at all, so plain float precision
// loss passes silently. What must never pass silently:
//   * digit-form integers a JS number cannot hold exactly (beyond
//     Number.MAX_SAFE_INTEGER, including digit runs that overflow f64 to
//     Infinity around 1e308) — throw, or revive as BigInt from the exact
//     source digits when the caller opted in;
//   * any number JSON.parse would turn into ±Infinity (float notation like
//     1e400) — a finite text becoming Infinity does not round-trip even
//     approximately, so throw and point at the escape hatches.
// Exponent/decimal notation within f64 range (1e30, 0.5) is float notation:
// the author wrote a float, engine float semantics apply, it passes.
// (Non-digit-form sources DO reach the unsafe-integer logic — 1e30 parses to
// a value Number.isInteger accepts — which is why the DIGIT_FORM test is
// load-bearing.)
//
// Callers who want different semantics use toJson (arbitrary-precision text
// out) and run their own JSON.parse with their own reviver.
function policeNumber(key, value, context, bigints) {
  if (typeof value !== 'number') return value;
  if (Number.isFinite(value)) {
    // A finite non-integer is always within f64 range by construction: only
    // float-precision loss is possible, which the user accepted. NaN cannot
    // come out of JSON.parse (the grammar has no such literal), and the
    // non-finite branch below would catch it anyway.
    if (!Number.isInteger(value)) return value;
    if (Number.isSafeInteger(value)) return value;
  }
  // Unsafe integer, or overflowed to ±Infinity.
  const source = context && context.source;
  if (source !== undefined && !DIGIT_FORM.test(source)) {
    // Float notation. Finite: precision loss the user accepted. Infinite:
    // refuse to invent Infinity from finite text.
    if (Number.isFinite(value)) return value;
    throw new TypeError(
      `number ${source} at ${describe(key)} does not fit in a JS number and ` +
      `JSON.parse would silently turn it into ${value}, which does not round-trip ` +
      `even approximately; use toJson and your own JSON.parse reviver if you ` +
      `want that behavior`);
  }
  if (bigints) {
    if (source !== undefined) return BigInt(source);
    throw new TypeError(
      `integer at ${describe(key)} cannot be represented exactly as a JS number ` +
      `and this runtime cannot revive it as a BigInt (JSON.parse source access ` +
      `is missing; it ships in Node 21+ and modern browsers)`);
  }
  // This message speaks the public parse() API's language: the snippet takes
  // a bare boolean, but users call parse(text, { bigints: true }).
  throw new TypeError(
    `integer ${source !== undefined ? source : value} at ${describe(key)} cannot be ` +
    `represented exactly as a JS number; pass { bigints: true } to receive it as a BigInt`);
}

// Hoisted like strictStringifyReplacer: one function identity each, no
// per-call closure over the bigints flag.
function rejectUnsafeIntegers(key, value, context) {
  return policeNumber(key, value, context, false);
}

function reviveUnsafeIntegersAsBigInts(key, value, context) {
  return policeNumber(key, value, context, true);
}

// Parse JSON text to a live JS value; number policy above. Pass true to
// revive unsafe integers as BigInt (the public parse() exposes this as
// { bigints: true }).
export function jsonTextToValue(json, bigints) {
  return JSON.parse(json, bigints === true ? reviveUnsafeIntegersAsBigInts : rejectUnsafeIntegers);
}
