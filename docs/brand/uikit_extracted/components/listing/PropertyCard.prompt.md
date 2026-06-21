**PropertyCard** — the most-rendered widget; a listing as a photo-led card. `vertical` for feeds/grids, `horizontal` for search rows.

```jsx
<PropertyCard
  title="شقة فاخرة في المزة"
  price="85,000,000" currency="ل.س" altPrice="≈ $32,000"
  location="دمشق — المزة"
  image="https://images.unsplash.com/photo-..."
  featured purpose="sale"
  specs={{ beds: 3, baths: 2, area: 180 }}
  favorite onFavorite={() => {}} onClick={() => {}}
/>

<PropertyCard layout="horizontal" title="…" price="120,000,000" location="حلب — الفرقان" specs={{ beds: 4, baths: 3, area: 240 }} />
```

- The heart uses brand **coral** when `favorite`. The featured (gold) + purpose (glass) badges sit over the photo with the scrim gradient.
- Specs render Lucide `bed-double` / `bath` / `ruler`; call `lucide.createIcons()` after mount.
