// lib/features/search/domain/entities/display_mode.dart
//
// Phase 25 premium uplift — the search results presentation mode toggle.
// `list` renders the scrollable result cards; `map` renders an embedded map
// of the same filtered results (reusing the map feature's widgets +
// `search_map` RPC). Purely a presentation concern — it never changes the
// query parameters sent to the search RPC.
enum DisplayMode { list, map }
