**Button** — the primary tap target across Al Nujom; theme-aware fill that adapts to the active direction (gold / teal / blue / orange gradient).

```jsx
<Button variant="primary" icon="phone">اتصال</Button>
<Button variant="whatsapp" icon="message-circle" block>تواصل عبر واتساب</Button>
<Button variant="gradient" iconEnd="arrow-left" block>متابعة</Button>
<Button variant="outline">إنشاء حساب جديد</Button>
<Button variant="ghost" iconEnd="chevron-left">عرض الكل</Button>
```

- **variant**: `primary` (filled accent) · `gradient` (Bold orange gradient + glow) · `whatsapp` (brand green) · `outline` · `ghost`.
- **size**: `sm` 36px · `md` 48px (default) · `lg` 54px. `block` stretches full-width.
- **icons**: pass a Lucide name to `icon` / `iconEnd`. Load Lucide and call `lucide.createIcons()` after mount.
- RTL is inherited from the document (`dir="rtl"`); icons sit on the correct side automatically.
