**Chip** — category / filter pill with optional leading icon; idle vs. accent-filled selected state.

```jsx
<Chip icon="building-2" selected>شقق</Chip>
<Chip icon="store">محلات</Chip>
<Chip removable onRemove={() => {}}>دمشق</Chip>
```

- `selected` fills with the theme accent. `removable` adds a trailing × (use in the active-filter strip).
- Lay them out in a horizontally-scrolling flex row with `gap: 8px`.
