import React from 'react';

/**
 * Al Nujom — Badge / Tag. Small non-tappable status markers and over-photo tags.
 */
export function Badge({ children, variant = 'featured', icon, style, ...rest }) {
  const variants = {
    featured: { background: 'var(--brand-gold)', color: '#fff', border: 'none' },
    verified: { background: 'var(--brand-verified-bg)', color: 'var(--brand-verified)', border: 'none' },
    purpose: { background: 'var(--accent)', color: 'var(--accent-ink)', border: 'none' },
    sale: { background: 'rgba(46,158,107,0.14)', color: 'var(--success)', border: 'none' },
    rent: { background: 'rgba(201,131,24,0.16)', color: 'var(--warning)', border: 'none' },
    glass: { background: 'rgba(15,18,28,0.55)', color: '#fff', border: 'none', backdropFilter: 'blur(6px)' },
    neutral: { background: 'var(--accent-soft)', color: 'var(--ink)', border: '1px solid var(--border)' },
  };
  const v = variants[variant] || variants.featured;

  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 5,
        height: 26,
        padding: '0 11px',
        borderRadius: 'var(--radius-pill)',
        fontFamily: 'var(--font-ui)',
        fontWeight: 800,
        fontSize: 12,
        lineHeight: 1,
        letterSpacing: '.2px',
        whiteSpace: 'nowrap',
        ...v,
        ...style,
      }}
      {...rest}
    >
      {icon && <i data-lucide={icon} style={{ width: 14, height: 14 }} />}
      {children}
    </span>
  );
}
