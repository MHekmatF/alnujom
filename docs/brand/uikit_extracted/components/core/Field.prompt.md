**Field** — labelled input / select / textarea with focus glow and a unit-suffix slot.

```jsx
<Field label="عنوان الإعلان" placeholder="شقة مشطّبة قرب الحديقة…" />
<Field label="نوع العقار" as="select" options={['شقة','منزل','محل','مكتب','أرض']} />
<Field label="السعر" unit="ل.س" type="text" />
<Field label="المساحة" unit="م²" />
<Field label="وصف العقار" as="textarea" rows={4} hint="0 / 1000" />
```

- `as`: `input` (default) · `select` (chevron auto-added) · `textarea`.
- Focus = accent border + `--glow` (Dark/Bold). On `.theme-bold` inputs fill deep navy via `--input-bg`.
- `unit` shows a trailing suffix; `icon` shows a leading Lucide glyph.
