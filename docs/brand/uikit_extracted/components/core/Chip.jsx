import React from 'react';

/**
 * Al Nujom — Chip. Category / filter pill with optional leading icon.
 * Toggles between idle and selected (accent-filled).
 */
export function Chip({ children, icon, selected = false, onClick, removable = false, onRemove, style, ...rest }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 7,
        height: 38,
        padding: '0 15px',
        borderRadius: 'var(--radius-pill)',
        fontFamily: 'var(--font-ui)',
        fontWeight: 700,
        fontSize: 13.5,
        lineHeight: 1,
        whiteSpace: 'nowrap',
        cursor: 'pointer',
        transition: 'all var(--motion-fast) var(--ease)',
        background: selected ? 'var(--accent)' : 'var(--card)',
        color: selected ? 'var(--accent-ink)' : 'var(--ink)',
        border: selected ? '1px solid var(--accent)' : '1px solid var(--border)',
        ...style,
      }}
      {...rest}
    >
      {icon && <i data-lucide={icon} style={{ width: 16, height: 16 }} />}
      {children}
      {removable && (
        <i
          data-lucide="x"
          onClick={(e) => { e.stopPropagation(); onRemove && onRemove(); }}
          style={{ width: 15, height: 15, marginInlineStart: 1, opacity: 0.8 }}
        />
      )}
    </button>
  );
}
