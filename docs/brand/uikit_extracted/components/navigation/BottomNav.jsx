import React from 'react';

const DEFAULT_ITEMS = [
  { id: 'home', icon: 'home', label: 'الرئيسية' },
  { id: 'search', icon: 'search', label: 'البحث' },
  { id: 'add', icon: 'plus', label: 'إضافة', primary: true },
  { id: 'favorites', icon: 'heart', label: 'المفضلة' },
  { id: 'account', icon: 'user', label: 'حسابي' },
];

/**
 * Al Nujom — BottomNav. The 5-tab spine, RTL-ordered. Active tab shows the
 * accent color + a top accent bar; the center "إضافة" tab is a raised accent FAB.
 */
export function BottomNav({ items = DEFAULT_ITEMS, active = 'home', onSelect, style, ...rest }) {
  return (
    <nav
      style={{
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'space-around',
        height: 72,
        padding: '0 6px 10px',
        background: 'var(--card)',
        borderTop: '1px solid var(--border)',
        boxShadow: 'var(--shadow-md)',
        ...style,
      }}
      {...rest}
    >
      {items.map((it) => {
        const isActive = it.id === active;
        if (it.primary) {
          return (
            <button
              key={it.id}
              type="button"
              onClick={() => onSelect && onSelect(it.id)}
              style={{
                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5,
                background: 'none', border: 'none', cursor: 'pointer', padding: 0, marginBottom: 2,
              }}
            >
              <span style={{
                width: 50, height: 50, borderRadius: 16, marginTop: -22,
                background: 'var(--accent-grad, var(--accent))', color: 'var(--accent-ink)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: 'var(--glow, var(--shadow-md))', border: '3px solid var(--card)',
              }}>
                <i data-lucide={it.icon} style={{ width: 24, height: 24 }} />
              </span>
              <span style={{ fontFamily: 'var(--font-ui)', fontSize: 11, fontWeight: 700, color: 'var(--ink-muted)' }}>{it.label}</span>
            </button>
          );
        }
        return (
          <button
            key={it.id}
            type="button"
            onClick={() => onSelect && onSelect(it.id)}
            style={{
              position: 'relative',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5,
              background: 'none', border: 'none', cursor: 'pointer', padding: '10px 4px 0',
              color: isActive ? 'var(--accent)' : 'var(--ink-muted)',
            }}
          >
            {isActive && <span style={{ position: 'absolute', top: 0, width: 22, height: 3, borderRadius: 3, background: 'var(--accent)' }} />}
            <i data-lucide={it.icon} style={{ width: 23, height: 23, fill: isActive && it.id === 'favorites' ? 'var(--accent)' : 'none' }} />
            <span style={{ fontFamily: 'var(--font-ui)', fontSize: 11, fontWeight: isActive ? 800 : 600 }}>{it.label}</span>
          </button>
        );
      })}
    </nav>
  );
}
