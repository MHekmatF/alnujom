import React from 'react';
import { Badge } from '../core/Badge.jsx';

/**
 * Al Nujom — PropertyCard. The most-rendered widget. Two layouts:
 * `vertical` (4:3 photo on top) and `horizontal` (photo-leading row).
 */
export function PropertyCard({
  title,
  price,
  currency = 'ل.س',
  altPrice,
  location,
  image,
  layout = 'vertical',
  featured = false,
  favorite = false,
  purpose,            // 'sale' | 'rent'
  specs,              // { beds, baths, area }
  onFavorite,
  onClick,
  style,
  ...rest
}) {
  const horizontal = layout === 'horizontal';

  const Photo = (
    <div
      style={{
        position: 'relative',
        flexShrink: 0,
        width: horizontal ? 132 : '100%',
        aspectRatio: horizontal ? '1 / 1' : '4 / 3',
        backgroundImage: image ? `url(${image})` : 'none',
        backgroundColor: 'var(--accent-soft)',
        backgroundSize: 'cover',
        backgroundPosition: 'center',
      }}
    >
      <div style={{ position: 'absolute', inset: 0, background: 'var(--photo-scrim)', pointerEvents: 'none' }} />
      {featured && (
        <span style={{ position: 'absolute', top: 10, insetInlineStart: 10 }}>
          <Badge variant="featured" icon="star">مميّز</Badge>
        </span>
      )}
      {purpose && (
        <span style={{ position: 'absolute', bottom: 10, insetInlineStart: 10 }}>
          <Badge variant="glass">{purpose === 'rent' ? 'للإيجار' : 'للبيع'}</Badge>
        </span>
      )}
      {onFavorite && (
        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); onFavorite(); }}
          style={{
            position: 'absolute', top: 10, insetInlineEnd: 10,
            width: 36, height: 36, borderRadius: '50%', border: 'none',
            background: 'rgba(255,255,255,0.92)', display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', boxShadow: 'var(--shadow-sm)',
          }}
        >
          <i data-lucide="heart" style={{ width: 18, height: 18, color: favorite ? 'var(--brand-coral)' : '#5F6C78', fill: favorite ? 'var(--brand-coral)' : 'none' }} />
        </button>
      )}
    </div>
  );

  const Body = (
    <div style={{ padding: horizontal ? '12px 14px' : 14, flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 7 }}>
      <h3 style={{ margin: 0, fontFamily: 'var(--font-ui)', fontWeight: 700, fontSize: horizontal ? 16 : 17, lineHeight: 1.3, color: 'var(--ink)', overflow: 'hidden', textOverflow: 'ellipsis', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
        {title}
      </h3>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
        <span style={{ fontFamily: 'var(--font-ui)', fontWeight: 800, fontSize: horizontal ? 17 : 19, color: 'var(--accent)' }}>{price}</span>
        <span style={{ fontFamily: 'var(--font-ui)', fontWeight: 700, fontSize: 12.5, color: 'var(--accent)', opacity: 0.8 }}>{currency}</span>
        {altPrice && <span style={{ fontSize: 12, color: 'var(--ink-faint)', fontWeight: 600, marginInlineStart: 4, direction: 'ltr' }}>{altPrice}</span>}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5, color: 'var(--ink-muted)' }}>
        <i data-lucide="map-pin" style={{ width: 14, height: 14 }} />
        <span style={{ fontFamily: 'var(--font-ui)', fontSize: 13, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{location}</span>
      </div>
      {specs && (
        <div style={{ display: 'flex', gap: 14, marginTop: 2, color: 'var(--ink-muted)' }}>
          {specs.beds != null && <Spec icon="bed-double" value={specs.beds} />}
          {specs.baths != null && <Spec icon="bath" value={specs.baths} />}
          {specs.area != null && <Spec icon="ruler" value={`${specs.area} م²`} />}
        </div>
      )}
    </div>
  );

  return (
    <div
      onClick={onClick}
      style={{
        display: 'flex',
        flexDirection: horizontal ? 'row' : 'column',
        background: 'var(--card)',
        border: '1px solid var(--border)',
        borderRadius: 'var(--radius-lg)',
        overflow: 'hidden',
        boxShadow: 'var(--shadow-sm)',
        cursor: onClick ? 'pointer' : 'default',
        ...style,
      }}
      {...rest}
    >
      {Photo}
      {Body}
    </div>
  );
}

function Spec({ icon, value }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontFamily: 'var(--font-ui)', fontWeight: 700, fontSize: 12.5 }}>
      <i data-lucide={icon} style={{ width: 15, height: 15 }} />
      {value}
    </span>
  );
}
