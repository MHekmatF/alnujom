import React from 'react';

/**
 * Al Nujom — Field. Label + input/select/textarea with a unit suffix slot.
 * Focus state: accent border + (Dark/Bold) accent glow.
 */
export function Field({
  label,
  value,
  onChange,
  placeholder,
  type = 'text',
  as = 'input',
  unit,
  options,
  icon,
  hint,
  rows = 4,
  style,
  ...rest
}) {
  const [focused, setFocused] = React.useState(false);

  const fieldBase = {
    width: '100%',
    boxSizing: 'border-box',
    fontFamily: 'var(--font-ui)',
    fontSize: 15,
    fontWeight: 500,
    color: 'var(--ink)',
    background: 'var(--input-bg, var(--surface))',
    border: `1.5px solid ${focused ? 'var(--accent)' : 'var(--input-border, var(--border-strong))'}`,
    borderRadius: 'var(--radius-md)',
    outline: 'none',
    transition: 'border-color var(--motion-fast) var(--ease), box-shadow var(--motion-fast) var(--ease)',
    boxShadow: focused ? 'var(--glow, none)' : 'none',
  };

  return (
    <label style={{ display: 'block', ...style }}>
      {label && (
        <span style={{ display: 'block', fontFamily: 'var(--font-ui)', fontWeight: 700, fontSize: 13.5, color: 'var(--ink)', marginBottom: 8 }}>
          {label}
        </span>
      )}
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
        {icon && (
          <i data-lucide={icon} style={{ position: 'absolute', insetInlineStart: 14, width: 18, height: 18, color: 'var(--ink-muted)', pointerEvents: 'none' }} />
        )}
        {as === 'select' ? (
          <select
            value={value}
            onChange={onChange}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            style={{ ...fieldBase, height: 52, padding: icon ? '0 44px 0 14px' : '0 14px', appearance: 'none' }}
            {...rest}
          >
            {(options || []).map((o) => (
              <option key={o.value ?? o} value={o.value ?? o}>{o.label ?? o}</option>
            ))}
          </select>
        ) : as === 'textarea' ? (
          <textarea
            value={value}
            onChange={onChange}
            placeholder={placeholder}
            rows={rows}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            style={{ ...fieldBase, padding: 14, resize: 'none', lineHeight: 1.6 }}
            {...rest}
          />
        ) : (
          <input
            type={type}
            value={value}
            onChange={onChange}
            placeholder={placeholder}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            style={{ ...fieldBase, height: 52, padding: icon ? '0 44px 0 14px' : '0 14px', paddingInlineEnd: unit ? 52 : 14 }}
            {...rest}
          />
        )}
        {as === 'select' && (
          <i data-lucide="chevron-down" style={{ position: 'absolute', insetInlineEnd: 14, width: 18, height: 18, color: 'var(--ink-muted)', pointerEvents: 'none' }} />
        )}
        {unit && as === 'input' && (
          <span style={{ position: 'absolute', insetInlineEnd: 14, fontFamily: 'var(--font-ui)', fontWeight: 700, fontSize: 13, color: 'var(--ink-muted)' }}>{unit}</span>
        )}
      </div>
      {hint && (
        <span style={{ display: 'block', fontFamily: 'var(--font-ui)', fontSize: 12, color: 'var(--ink-faint)', marginTop: 6 }}>{hint}</span>
      )}
    </label>
  );
}
