# Feature Specification: Search & Filters

**Feature Branch**: `014-search-filters`
**Created**: 2026-05-24
**Status**: Draft
**Input**: Phase 14 — Combined text + facet search with sort, from `docs/IMPLEMENTATION_PLAN.md`

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Keyword Search (Priority: P1)

A visitor wants to find a specific property and types keywords into the search bar — in Arabic (e.g., "شقة دمشق") or Latin characters — and expects to see only matching listings.

**Why this priority**: Keyword search is the most direct path from intent to result. Without it, users must browse the entire catalog blindly.

**Independent Test**: Can be fully tested by opening the search page, entering a keyword, and confirming only matching listings appear.

**Acceptance Scenarios**:

1. **Given** the search page is open, **When** the user types "شقة" and submits, **Then** only listings whose title, description, or address contains the literal token "شقة" appear in the results (exact-form match; "شقق" is a distinct token and will NOT match).
2. **Given** the user taps the hero search bar on the Home screen, **When** the search screen opens, **Then** the keyword input has focus and no filters are pre-applied.
3. **Given** the user taps a property-type chip (e.g., "Apartments") on the Home screen, **When** the search screen opens, **Then** the property-type filter is pre-set to that type, results are already narrowed accordingly, and the filter sheet reflects the pre-applied selection.
4. **Given** a keyword search is active, **When** the user clears the search bar, **Then** all approved listings are shown (unfiltered).
5. **Given** a keyword that matches no listings, **When** the user submits the search, **Then** an empty-state message appears with an option to clear the search.
6. **Given** an Arabic keyword search returns zero or fewer than 3 results, **When** the empty/sparse state is shown, **Then** a localized hint is displayed informing the user that Arabic search matches exact word forms and suggesting they try alternate forms (e.g., "جرب: شقق").

---

### User Story 2 — Facet Filters (Priority: P1)

A visitor wants to narrow listings by structured criteria: purpose (sale / rent / daily_rent / investment), property type (apartment, villa, land, shop, office, farm, warehouse, other), location (governorate → city → area), price range with currency selector, number of rooms, number of bathrooms, and property area size. The filter panel opens as a modal bottom sheet from a "Filters" button on the search screen.

**Why this priority**: Facet filters are essential for a real-estate marketplace — without them the catalog is unusable for anyone with specific requirements.

**Independent Test**: Can be fully tested by tapping "Filters," applying one or more dimensions, tapping "Apply," and confirming only matching listings appear.

**Acceptance Scenarios**:

1. **Given** the user taps "Filters" on the search screen, **Then** a modal bottom sheet opens containing all filter dimensions plus "Apply" and "Reset" actions.
2. **Given** the filter sheet is open, **When** the user selects "For Sale" as purpose and "Apartment" as type and taps "Apply," **Then** only approved sale-apartment listings appear.
3. **Given** the user picks a governorate, **When** they then pick a city within that governorate, **Then** the area picker shows only areas belonging to that city.
4. **Given** a price-range filter is set with a chosen currency, **When** the user taps "Apply," **Then** no listing in the results falls outside the specified price range when converted to the chosen currency.
5. **Given** multiple filters are active and the filter sheet is opened again, **When** the user clears one filter dimension and taps "Apply," **Then** results re-expand to all listings matching the remaining active filters.
6. **Given** all applied filters match zero listings, **When** the results are displayed, **Then** an empty state appears with a "Clear all filters" action.
7. **Given** the rooms filter is set to "Exactly 3," **When** results are shown, **Then** only listings with exactly 3 rooms appear.
8. **Given** the rooms filter is set to "At least 3," **When** results are shown, **Then** listings with 3, 4, 5, or more rooms all appear.
9. **Given** the user taps "Reset" inside the filter sheet, **Then** all filter dimensions return to their empty/default state and the sheet remains open for further edits.

---

### User Story 3 — Sort Options (Priority: P2)

A visitor wants to control the order of the result list — see the newest listings first, or sort by price (low-to-high or high-to-low) — using an inline control directly on the search results page, without opening the filter sheet.

**Why this priority**: Sorting gives users control over relevance without reducing the result set. An inline control makes it a one-tap action rather than a two-step sheet open + apply flow.

**Independent Test**: Can be fully tested by tapping the inline sort control, selecting each option, and confirming the listing order changes accordingly.

**Acceptance Scenarios**:

1. **Given** the search results page is open, **Then** an inline sort control is visible on the page without needing to open the filter sheet.
2. **Given** the inline sort control is visible, **When** the user selects "Newest first," **Then** listings appear sorted by publication date, most recent at top.
3. **Given** the inline sort control is visible, **When** the user selects "Price: low to high," **Then** listings appear sorted by primary price ascending.
4. **Given** the inline sort control is visible, **When** the user selects "Price: high to low," **Then** listings appear sorted by primary price descending.
5. **Given** a sort option is active, **When** the user changes it via the inline control, **Then** the list reorders immediately without clearing applied filters and without opening the filter sheet.

---

### User Story 4 — Filter State Persistence Through Navigation (Priority: P2)

A visitor applies filters on the search page, taps into a listing detail, then presses Back — and expects to return to the same filtered result list without re-applying any criteria.

**Why this priority**: Losing filter state on navigation is a frustrating experience that forces users to repeat work and discourages deep exploration.

**Independent Test**: Can be fully tested by applying filters, navigating to a listing detail, pressing Back, and confirming filters and results are unchanged.

**Acceptance Scenarios**:

1. **Given** the user has an active filter set and a sort order, **When** they open a listing detail and press Back, **Then** the search page is restored with the same filters, sort, and result list.
2. **Given** the user has active filters and navigates away to the Home screen (not via Back), **Then** the search state is not required to be restored when re-opening search.

---

### User Story 5 — Combined Search + Filter + Sort (Priority: P2)

A visitor applies a keyword search, adds facet filters, and selects a sort order all at once to find exactly the properties they need.

**Why this priority**: Real-world searches require all three axes simultaneously; isolated testing of each alone is insufficient for marketplace quality.

**Independent Test**: Can be tested by entering a keyword, applying at least two facet filters, choosing a sort order, and confirming results satisfy all three constraints simultaneously.

**Acceptance Scenarios**:

1. **Given** an active keyword search and facet filters, **When** the user adds a sort option, **Then** results are filtered by both keyword and facets AND ordered by the chosen sort.
2. **Given** all three (search + filters + sort) are active, **When** the user clears only the keyword, **Then** filters and sort remain active and results update accordingly.

---

### Edge Cases

- What happens when a governorate has no approved listings? (Empty-state message with a clear-filters action.)
- What happens when the user enters a very long keyword (>100 characters)? (Input is accepted; no error. Results appear or empty-state if no match.)
- What happens when price-range "min" is set higher than "max"? (Visible inline validation error; query is not submitted until corrected.)
- What happens when no exchange-rate data is available for the chosen filter currency? (Price-range filter is disabled for that currency with an explanatory message.)
- What happens on a slow connection while results are loading? (Loading indicator shown; results appear when the response arrives.)
- What happens when the user switches the app display language while a search is active? (All UI labels update; the results list re-fetches with the new locale's display names.)

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a dedicated search screen reachable from the Home screen (replacing the Phase 13 Coming-soon stubs on the hero search bar and property-type shortcuts). Tapping a property-type chip on the Home screen MUST navigate to the search screen with that property type pre-applied as a structured filter — the filter sheet shows the chip as selected and results are already narrowed to that type. Tapping the hero search bar MUST navigate to the search screen with focus on the keyword input and no pre-applied filters.
- **FR-002**: The system MUST support keyword search over listing titles, addresses, and descriptions.
- **FR-003**: The system MUST return results for Arabic-language keyword queries by matching the exact token form entered against listing titles, addresses, and descriptions. Morphological variants are out of scope for Phase 14 (e.g., querying "شقة" will NOT automatically match listings that use "شقق" or "شقتين").
- **FR-004**: The system MUST return correct results for Latin-character keyword queries (case-insensitive).
- **FR-005**: The system MUST provide a filter panel implemented as a modal bottom sheet, opened via a "Filters" button on the search screen. The sheet MUST offer the following independent filter dimensions: listing purpose, property type, governorate, city, area, price range with a currency selector, number of rooms, number of bathrooms, and property area size. The sheet MUST include an "Apply" action that runs the query and closes the sheet, and a "Reset" action that clears all filter values. The rooms and bathrooms filters MUST offer two modes the user can switch between: "Exactly N" (exact count match) and "At least N" (minimum count match).
- **FR-006**: The governorate / city / area filters MUST be cascading: selecting a governorate limits available cities; selecting a city limits available areas.
- **FR-007**: The price-range filter MUST include a currency selector; the system MUST apply exchange-rate conversion when comparing against listings priced in a different currency.
- **FR-008**: The system MUST support three sort orders: newest first (default), price low-to-high, and price high-to-low. The sort control MUST be an inline element visible directly on the search results page (separate from the filter bottom sheet), so the user can change sort order without opening the filter panel.
- **FR-009**: Search text, facet filters, and sort order MUST be composable — any combination must yield the correct intersection of matching listings.
- **FR-010**: When no listings match the current search/filter/sort state, the system MUST display a localized empty-state message and a "Clear all filters" action.
- **FR-011**: The system MUST show only approved, within-publish-window listings in all search and filter results (same public-read gate as the Home feed).
- **FR-012**: Filter state (active filters + sort order) MUST be preserved when the user navigates from the search page to a listing detail via the Back navigation path.
- **FR-013**: Every user-visible string in the search and filter UI MUST exist in both the Arabic and English localization files and render correctly in RTL and LTR layouts.
- **FR-014**: Search results MUST load in paginated form; scrolling to the bottom of the current page loads the next page automatically.
- **FR-015**: The search screen MUST be accessible to anonymous (non-logged-in) users without a login prompt.
- **FR-016**: The system MUST display a loading indicator while fetching search or filter results.
- **FR-017**: The price-range filter MUST reject a "min > max" state with a visible inline validation error before the query is submitted.
- **FR-018**: Clearing all filters MUST return the results to the full unfiltered (keyword-only or all-approved) listing set.
- **FR-019**: When an Arabic keyword search returns zero or fewer than 3 results, the system MUST display a localized user-education hint explaining that Arabic search matches exact word forms and suggesting the user try alternate forms of the same word.

### Key Entities

- **Search Query**: A user-entered text string (Arabic or Latin) used to match across listing titles, addresses, and descriptions.
- **Filter State**: The complete set of currently active filter criteria (purpose, property type, location tier, price range with chosen currency, rooms, bathrooms, area size) combined with the active sort order.
- **Search Result Page**: A paginated list of approved, in-window listings that satisfy the active search query and all active filters, ordered by the active sort criterion.
- **Listing (search projection)**: An approved listing record surfaced in search results, including primary price (with currency), main image, location hierarchy labels (in the user's locale), property type, purpose, and publication date — no draft, rejected, or hidden listings.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user typing an Arabic keyword (e.g., "شقة") sees only listings whose content contains that exact token within 2 seconds of submitting the query on a standard mobile connection. Listings using morphological variants (e.g., "شقق") are correctly absent from results.
- **SC-002**: A user typing a Latin-character keyword (e.g., "Damascus") sees only matching listings within 2 seconds of submitting the query.
- **SC-003**: Applying any combination of valid facet filters returns a result list containing only listings that satisfy every active filter simultaneously (verified against a known fixture data set). Room and bathroom filters are verified in both "Exactly N" and "At least N" modes.
- **SC-004**: Switching sort order reorders the displayed results visibly within 1 second without clearing active filters.
- **SC-005**: After navigating to a listing detail and pressing Back, the search page restores with identical filters, sort order, and result list — requiring no user re-entry.
- **SC-006**: When filters and/or search yield zero matching listings, the empty-state message appears within 1 second of the last filter change.
- **SC-007**: All text elements in the search and filter UI render in Arabic (RTL) by default and switch correctly to English (LTR) when the app locale is changed.
- **SC-008**: An anonymous user can open the search screen and perform any search or filter action without receiving a login prompt.
- **SC-009**: The price-range filter rejects a "min > max" input with a visible inline error message before submitting any query.
- **SC-010**: Results load in pages; scrolling to the end of the current page triggers automatic loading of the next page.
- **SC-011**: The search screen is reachable from the Home screen hero search bar and property-type shortcuts (replacing the Phase 13 Coming-soon snackbar stubs).

---

## Assumptions

- Filter state persistence is scoped to the back-navigation path within the current session only. It does not survive app cold-start restarts.
- The price-range filter currency selector defaults to the user's currently active display currency; exchange-rate conversion is applied at query time using the latest available exchange rate.
- "Newest first" (by publication date descending) is the default sort order when the search screen opens.
- The search screen replaces the Phase 13 Coming-soon stubs on the home page hero search bar and property-type chips. Phase 14 owns the `/search` route and wires those entry points. The two entry points have different opening states: hero search bar → empty search with keyboard focus; property-type chip → pre-filtered by that property type.
- Keyword search covers `title`, `address_text`, and `description` only. It does not search publisher contact details, phone numbers, or any admin-only fields.
- Only listings with `status = 'approved'` and within the active publish window are ever surfaced — the same public-read gate as the Phase 13 home feed. Phase 14 introduces no new visibility rules.
- Phase 14 adds no new Supabase tables. Schema additions are limited to a full-text search column and index on the existing `listings` table, plus a public read-only view.
- The governorate / city / area seed data (Phase 8) is already in place. Phase 14 reads it; it does not modify location data.
- The rooms and bathrooms filters offer two user-selectable modes: "Exactly N" (exact count) and "At least N" (minimum count). The area-size filter uses a min/max range. The UX control shape (stepper, dropdown, toggle) is a planning-time decision.
- The Phase 13 indexes `idx_listings_governorate_status` and `idx_listings_property_type_status` are already applied and support Phase 14's location- and type-based facet filters.
- **Arabic search precision (Phase 14)**: Arabic full-text search uses basic (non-morphological) tokenization in Phase 14. Searching "شقة" matches only that exact token — it will not stem or match plural/dual/derived forms. A user-education hint (FR-019) compensates. Morphological Arabic search (stemming, root-based matching) is explicitly deferred to a future phase; see forward-stated enhancement note in the Clarifications section.

---

## Clarifications

### Session 2026-05-24

- Q: Should the spec explicitly state the Arabic search precision boundary (exact-token, no morphology), add a user-education hint for zero/sparse results, and forward-state smart Arabic search as a future enhancement? → A: Yes — exact-token matching documented (FR-003 updated, SC-001 updated), user-education hint added as FR-019 + US1 scenario 4, and smart morphological Arabic search explicitly deferred.

- Q: Should rooms and bathrooms filters use "exactly N", "at least N", or a range? → A: Dual-mode — user can switch between "Exactly N" (exact count) and "At least N" (minimum count) for both rooms and bathrooms. Area-size filter uses a min/max range.
- Q: What is the filter panel UI pattern (bottom sheet, full-screen page, persistent chips, or hybrid)? → A: Modal bottom sheet — a "Filters" button opens a sheet covering ~80% of the screen with all filter dimensions, "Apply" to run the query, and "Reset" to clear all values.
- Q: Should the sort control be inside the filter sheet or a separate inline control on the results page? → A: Separate inline control — visible directly on the search results page so users can change sort order with one tap, without opening the filter sheet.
- Q: When a user taps a property-type chip on the Home screen, does the search screen open pre-filtered or empty? → A: Pre-filtered — the property type is pre-applied as a structured filter, results are already narrowed, and the filter sheet reflects the selection. The hero search bar opens an empty (no pre-applied filters) search screen with keyboard focus.

**Forward-stated enhancement — Smart Arabic Search**: A future phase (post-Phase 14) SHOULD introduce morphological Arabic search — either via a PostgreSQL Arabic stemming extension (if available on the hosting platform at that time) or client-side query preprocessing that expands input tokens to their root forms before querying. When that phase ships, FR-003 and SC-001 are the primary spec sections to revise. The `tsvector` infrastructure laid in Phase 14 is the starting point for that upgrade.
