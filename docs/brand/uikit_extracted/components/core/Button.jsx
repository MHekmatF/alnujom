import React from 'react';

/**
 * Al Nujom — Button.
 * Theme-aware: colors read from the active `.theme-*` scope's tokens.
 * Icons use Lucide: pass a lucide name (e.g. "phone"); the consumer must call
 * `lucide.createIcons()` after render so the <i data-lucide> upgrades to SVG.
 */
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  icon,
  iconEnd,
  block = false,
  disabled = false,
  onClick,
  type = 'button',
  style,
  ...rest
}) {
  const sizes = {
    sm: { padding: '7px 14px', fontSize: 13, height: 36, gap: 6, iconSize: 16 },
    md: { padding: '0 20px', fontSize: 15, height: 48, gap: 8, iconSize: 18 },
    lg: { padding: '0 24px', fontSize: 16, height: 54, gap: 10, iconSize: 20 },
  };
  const s = sizes[size] || sizes.md;

  const variants = {
    primary: { background: 'var(--accent)', color: 'var(--accent-ink)', border: 'none' },
    gradient: {
      background: 'var(--accent-grad, var(--accent))',
      color: 'var(--accent-ink)',
      border: 'none',
      boxShadow: 'var(--glow, var(--shadow-md))',
    },
    whatsapp: { background: 'var(--brand-whatsapp)', color: '#fff', border: 'none' },
    outline: {
      background: 'transparent',
      color: 'var(--ink)',
      border: '1.5px solid var(--border-strong)',
    },
    ghost: { background: 'transparent', color: 'var(--accent)', border: 'none' },
  };
  const v = variants[variant] || variants.primary;

  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      style={{
        display: block ? 'flex' : 'inline-flex',
        width: block ? '100%' : undefined,
        alignItems: 'center',
        justifyContent: 'center',
        gap: s.gap,
        height: s.height,
        padding: s.padding,
        fontFamily: 'var(--font-ui)',
        fontWeight: 800,
        fontSize: s.fontSize,
        lineHeight: 1,
        borderRadius: variant === 'ghost' ? 'var(--radius-sm)' : 'var(--radius-md)',
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.5 : 1,
        transition: 'transform var(--motion-fast) var(--ease), filter var(--motion-fast) var(--ease)',
        ...v,
        ...style,
      }}
      onMouseDown={(e) => { if (!disabled) e.currentTarget.style.transform = 'scale(0.97)'; }}
      onMouseUp={(e) => { e.currentTarget.style.transform = 'scale(1)'; }}
      onMouseLeave={(e) => { e.currentTarget.style.transform = 'scale(1)'; }}
      {...rest}
    >
      {icon && <i data-lucide={icon} style={{ width: s.iconSize, height: s.iconSize }} />}
      {children && <span>{children}</span>}
      {iconEnd && <i data-lucide={iconEnd} style={{ width: s.iconSize, height: s.iconSize }} />}
    </button>
  );
}
