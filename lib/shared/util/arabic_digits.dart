/// DC "Blue Crown" design (`AlNujom.dc.html`, founder-approved) renders
/// **Western digits everywhere** — matching Bayut / dubizzle / OpenSooq and
/// how the founder wants prices/specs to read. This function is therefore now
/// a **passthrough**: it returns its input unchanged so every existing call
/// site (rate/rating/amenity/assistant/filter formatters) yields Western
/// digits without a per-site edit. Kept (rather than deleted) so callers keep
/// compiling; new code should not call it.
///
/// (Was: substitute ASCII 0-9 → ٠-٩ and `,`/`.` → Arabic separators, from the
/// Stage-2 Arabic-Indic pass that the DC design reverses.)
String toArabicIndicNumerals(String input) => input;
