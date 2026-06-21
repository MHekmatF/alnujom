# Al Nujom — App UI Kit

A clickable, RTL, four-screen recreation of the Al Nujom real-estate app, each screen
art-directed in one of the system's four directions. Built on the DS tokens
(`../../styles.css`) inside a 390 × 844 device frame.

| Screen | File anchor | Direction |
|---|---|---|
| **Home** | `[data-screen="home"]` | Premium — cream / gold, Playfair price numerals, featured hero + 2-up row |
| **Listing detail** | `[data-screen="listing"]` | Airy — full-bleed teal, 4-up facts grid, verified-agent card, WhatsApp CTA |
| **Search results** | `[data-screen="search"]` | Dark — midnight navy, glowing-blue filter chips, photo-left result cards |
| **Add listing** | `[data-screen="add"]` | Bold — navy + orange gradient, 4-step bar, segmented pills, glowing inputs |

## Interactions

- The **rail** below the phone jumps between the four screens (and re-themes the frame).
- In-app: tapping the **hero / mini / result cards** → Listing detail; **bottom-nav** tabs
  switch Home ⇄ Search ⇄ Add; **back / ×** buttons return Home.
- Last screen is remembered in `localStorage` (`alnujom_screen`).

## Notes

- Icons are **Lucide** (CDN). Photos are **Unsplash** (real-estate imagery).
- The screens here are a self-contained HTML/CSS recreation that mirrors the DS component
  primitives (`components/`). For production React, compose the bundled primitives —
  `Button`, `Badge`, `Chip`, `Field`, `PropertyCard`, `BottomNav` — which carry the same
  visual language and retone automatically per `.theme-*` scope.
- Fully RTL (`dir="rtl"`); Arabic copy is realistic Syrian-register marketplace content.
