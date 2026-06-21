**BottomNav** — the 5-tab spine (الرئيسية · البحث · إضافة · المفضلة · حسابي), RTL-ordered, with a raised center "add" FAB.

```jsx
<BottomNav active="home" onSelect={setTab} />
```

- Active tab colors with the theme accent + a 2px top bar. The center `إضافة` tab is a raised FAB (orange gradient on `.theme-bold`, accent + glow elsewhere).
- Pin it to the bottom of a 390-wide device frame; height 72px. Pass custom `items` to relabel.
