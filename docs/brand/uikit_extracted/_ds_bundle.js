/* @ds-bundle: {"format":3,"namespace":"AlNujomDesignSystem_6d1292","components":[{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Chip","sourcePath":"components/core/Chip.jsx"},{"name":"Field","sourcePath":"components/core/Field.jsx"},{"name":"PropertyCard","sourcePath":"components/listing/PropertyCard.jsx"},{"name":"BottomNav","sourcePath":"components/navigation/BottomNav.jsx"}],"sourceHashes":{"components/core/Badge.jsx":"029881b87ccb","components/core/Button.jsx":"cdc8b94e4771","components/core/Chip.jsx":"7e312a27c1bc","components/core/Field.jsx":"d43bed5a2c05","components/listing/PropertyCard.jsx":"27203a2a00c2","components/navigation/BottomNav.jsx":"62b721977cc9"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.AlNujomDesignSystem_6d1292 = window.AlNujomDesignSystem_6d1292 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Al Nujom — Badge / Tag. Small non-tappable status markers and over-photo tags.
 */
function Badge({
  children,
  variant = 'featured',
  icon,
  style,
  ...rest
}) {
  const variants = {
    featured: {
      background: 'var(--brand-gold)',
      color: '#fff',
      border: 'none'
    },
    verified: {
      background: 'var(--brand-verified-bg)',
      color: 'var(--brand-verified)',
      border: 'none'
    },
    purpose: {
      background: 'var(--accent)',
      color: 'var(--accent-ink)',
      border: 'none'
    },
    sale: {
      background: 'rgba(46,158,107,0.14)',
      color: 'var(--success)',
      border: 'none'
    },
    rent: {
      background: 'rgba(201,131,24,0.16)',
      color: 'var(--warning)',
      border: 'none'
    },
    glass: {
      background: 'rgba(15,18,28,0.55)',
      color: '#fff',
      border: 'none',
      backdropFilter: 'blur(6px)'
    },
    neutral: {
      background: 'var(--accent-soft)',
      color: 'var(--ink)',
      border: '1px solid var(--border)'
    }
  };
  const v = variants[variant] || variants.featured;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
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
      ...style
    }
  }, rest), icon && /*#__PURE__*/React.createElement("i", {
    "data-lucide": icon,
    style: {
      width: 14,
      height: 14
    }
  }), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Al Nujom — Button.
 * Theme-aware: colors read from the active `.theme-*` scope's tokens.
 * Icons use Lucide: pass a lucide name (e.g. "phone"); the consumer must call
 * `lucide.createIcons()` after render so the <i data-lucide> upgrades to SVG.
 */
function Button({
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
    sm: {
      padding: '7px 14px',
      fontSize: 13,
      height: 36,
      gap: 6,
      iconSize: 16
    },
    md: {
      padding: '0 20px',
      fontSize: 15,
      height: 48,
      gap: 8,
      iconSize: 18
    },
    lg: {
      padding: '0 24px',
      fontSize: 16,
      height: 54,
      gap: 10,
      iconSize: 20
    }
  };
  const s = sizes[size] || sizes.md;
  const variants = {
    primary: {
      background: 'var(--accent)',
      color: 'var(--accent-ink)',
      border: 'none'
    },
    gradient: {
      background: 'var(--accent-grad, var(--accent))',
      color: 'var(--accent-ink)',
      border: 'none',
      boxShadow: 'var(--glow, var(--shadow-md))'
    },
    whatsapp: {
      background: 'var(--brand-whatsapp)',
      color: '#fff',
      border: 'none'
    },
    outline: {
      background: 'transparent',
      color: 'var(--ink)',
      border: '1.5px solid var(--border-strong)'
    },
    ghost: {
      background: 'transparent',
      color: 'var(--accent)',
      border: 'none'
    }
  };
  const v = variants[variant] || variants.primary;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    disabled: disabled,
    onClick: onClick,
    style: {
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
      ...style
    },
    onMouseDown: e => {
      if (!disabled) e.currentTarget.style.transform = 'scale(0.97)';
    },
    onMouseUp: e => {
      e.currentTarget.style.transform = 'scale(1)';
    },
    onMouseLeave: e => {
      e.currentTarget.style.transform = 'scale(1)';
    }
  }, rest), icon && /*#__PURE__*/React.createElement("i", {
    "data-lucide": icon,
    style: {
      width: s.iconSize,
      height: s.iconSize
    }
  }), children && /*#__PURE__*/React.createElement("span", null, children), iconEnd && /*#__PURE__*/React.createElement("i", {
    "data-lucide": iconEnd,
    style: {
      width: s.iconSize,
      height: s.iconSize
    }
  }));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Chip.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Al Nujom — Chip. Category / filter pill with optional leading icon.
 * Toggles between idle and selected (accent-filled).
 */
function Chip({
  children,
  icon,
  selected = false,
  onClick,
  removable = false,
  onRemove,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    onClick: onClick,
    style: {
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
      ...style
    }
  }, rest), icon && /*#__PURE__*/React.createElement("i", {
    "data-lucide": icon,
    style: {
      width: 16,
      height: 16
    }
  }), children, removable && /*#__PURE__*/React.createElement("i", {
    "data-lucide": "x",
    onClick: e => {
      e.stopPropagation();
      onRemove && onRemove();
    },
    style: {
      width: 15,
      height: 15,
      marginInlineStart: 1,
      opacity: 0.8
    }
  }));
}
Object.assign(__ds_scope, { Chip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Chip.jsx", error: String((e && e.message) || e) }); }

// components/core/Field.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Al Nujom — Field. Label + input/select/textarea with a unit suffix slot.
 * Focus state: accent border + (Dark/Bold) accent glow.
 */
function Field({
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
    boxShadow: focused ? 'var(--glow, none)' : 'none'
  };
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'block',
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontFamily: 'var(--font-ui)',
      fontWeight: 700,
      fontSize: 13.5,
      color: 'var(--ink)',
      marginBottom: 8
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      alignItems: 'center'
    }
  }, icon && /*#__PURE__*/React.createElement("i", {
    "data-lucide": icon,
    style: {
      position: 'absolute',
      insetInlineStart: 14,
      width: 18,
      height: 18,
      color: 'var(--ink-muted)',
      pointerEvents: 'none'
    }
  }), as === 'select' ? /*#__PURE__*/React.createElement("select", _extends({
    value: value,
    onChange: onChange,
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    style: {
      ...fieldBase,
      height: 52,
      padding: icon ? '0 44px 0 14px' : '0 14px',
      appearance: 'none'
    }
  }, rest), (options || []).map(o => /*#__PURE__*/React.createElement("option", {
    key: o.value ?? o,
    value: o.value ?? o
  }, o.label ?? o))) : as === 'textarea' ? /*#__PURE__*/React.createElement("textarea", _extends({
    value: value,
    onChange: onChange,
    placeholder: placeholder,
    rows: rows,
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    style: {
      ...fieldBase,
      padding: 14,
      resize: 'none',
      lineHeight: 1.6
    }
  }, rest)) : /*#__PURE__*/React.createElement("input", _extends({
    type: type,
    value: value,
    onChange: onChange,
    placeholder: placeholder,
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    style: {
      ...fieldBase,
      height: 52,
      padding: icon ? '0 44px 0 14px' : '0 14px',
      paddingInlineEnd: unit ? 52 : 14
    }
  }, rest)), as === 'select' && /*#__PURE__*/React.createElement("i", {
    "data-lucide": "chevron-down",
    style: {
      position: 'absolute',
      insetInlineEnd: 14,
      width: 18,
      height: 18,
      color: 'var(--ink-muted)',
      pointerEvents: 'none'
    }
  }), unit && as === 'input' && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      insetInlineEnd: 14,
      fontFamily: 'var(--font-ui)',
      fontWeight: 700,
      fontSize: 13,
      color: 'var(--ink-muted)'
    }
  }, unit)), hint && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontFamily: 'var(--font-ui)',
      fontSize: 12,
      color: 'var(--ink-faint)',
      marginTop: 6
    }
  }, hint));
}
Object.assign(__ds_scope, { Field });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Field.jsx", error: String((e && e.message) || e) }); }

// components/listing/PropertyCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Al Nujom — PropertyCard. The most-rendered widget. Two layouts:
 * `vertical` (4:3 photo on top) and `horizontal` (photo-leading row).
 */
function PropertyCard({
  title,
  price,
  currency = 'ل.س',
  altPrice,
  location,
  image,
  layout = 'vertical',
  featured = false,
  favorite = false,
  purpose,
  // 'sale' | 'rent'
  specs,
  // { beds, baths, area }
  onFavorite,
  onClick,
  style,
  ...rest
}) {
  const horizontal = layout === 'horizontal';
  const Photo = /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      flexShrink: 0,
      width: horizontal ? 132 : '100%',
      aspectRatio: horizontal ? '1 / 1' : '4 / 3',
      backgroundImage: image ? `url(${image})` : 'none',
      backgroundColor: 'var(--accent-soft)',
      backgroundSize: 'cover',
      backgroundPosition: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'var(--photo-scrim)',
      pointerEvents: 'none'
    }
  }), featured && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 10,
      insetInlineStart: 10
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: "featured",
    icon: "star"
  }, "\u0645\u0645\u064A\u0651\u0632")), purpose && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      bottom: 10,
      insetInlineStart: 10
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    variant: "glass"
  }, purpose === 'rent' ? 'للإيجار' : 'للبيع')), onFavorite && /*#__PURE__*/React.createElement("button", {
    type: "button",
    onClick: e => {
      e.stopPropagation();
      onFavorite();
    },
    style: {
      position: 'absolute',
      top: 10,
      insetInlineEnd: 10,
      width: 36,
      height: 36,
      borderRadius: '50%',
      border: 'none',
      background: 'rgba(255,255,255,0.92)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      cursor: 'pointer',
      boxShadow: 'var(--shadow-sm)'
    }
  }, /*#__PURE__*/React.createElement("i", {
    "data-lucide": "heart",
    style: {
      width: 18,
      height: 18,
      color: favorite ? 'var(--brand-coral)' : '#5F6C78',
      fill: favorite ? 'var(--brand-coral)' : 'none'
    }
  })));
  const Body = /*#__PURE__*/React.createElement("div", {
    style: {
      padding: horizontal ? '12px 14px' : 14,
      flex: 1,
      minWidth: 0,
      display: 'flex',
      flexDirection: 'column',
      gap: 7
    }
  }, /*#__PURE__*/React.createElement("h3", {
    style: {
      margin: 0,
      fontFamily: 'var(--font-ui)',
      fontWeight: 700,
      fontSize: horizontal ? 16 : 17,
      lineHeight: 1.3,
      color: 'var(--ink)',
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      display: '-webkit-box',
      WebkitLineClamp: 2,
      WebkitBoxOrient: 'vertical'
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-ui)',
      fontWeight: 800,
      fontSize: horizontal ? 17 : 19,
      color: 'var(--accent)'
    }
  }, price), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-ui)',
      fontWeight: 700,
      fontSize: 12.5,
      color: 'var(--accent)',
      opacity: 0.8
    }
  }, currency), altPrice && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--ink-faint)',
      fontWeight: 600,
      marginInlineStart: 4,
      direction: 'ltr'
    }
  }, altPrice)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 5,
      color: 'var(--ink-muted)'
    }
  }, /*#__PURE__*/React.createElement("i", {
    "data-lucide": "map-pin",
    style: {
      width: 14,
      height: 14
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-ui)',
      fontSize: 13,
      fontWeight: 500,
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, location)), specs && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      marginTop: 2,
      color: 'var(--ink-muted)'
    }
  }, specs.beds != null && /*#__PURE__*/React.createElement(Spec, {
    icon: "bed-double",
    value: specs.beds
  }), specs.baths != null && /*#__PURE__*/React.createElement(Spec, {
    icon: "bath",
    value: specs.baths
  }), specs.area != null && /*#__PURE__*/React.createElement(Spec, {
    icon: "ruler",
    value: `${specs.area} م²`
  })));
  return /*#__PURE__*/React.createElement("div", _extends({
    onClick: onClick,
    style: {
      display: 'flex',
      flexDirection: horizontal ? 'row' : 'column',
      background: 'var(--card)',
      border: '1px solid var(--border)',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      boxShadow: 'var(--shadow-sm)',
      cursor: onClick ? 'pointer' : 'default',
      ...style
    }
  }, rest), Photo, Body);
}
function Spec({
  icon,
  value
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 5,
      fontFamily: 'var(--font-ui)',
      fontWeight: 700,
      fontSize: 12.5
    }
  }, /*#__PURE__*/React.createElement("i", {
    "data-lucide": icon,
    style: {
      width: 15,
      height: 15
    }
  }), value);
}
Object.assign(__ds_scope, { PropertyCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/listing/PropertyCard.jsx", error: String((e && e.message) || e) }); }

// components/navigation/BottomNav.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const DEFAULT_ITEMS = [{
  id: 'home',
  icon: 'home',
  label: 'الرئيسية'
}, {
  id: 'search',
  icon: 'search',
  label: 'البحث'
}, {
  id: 'add',
  icon: 'plus',
  label: 'إضافة',
  primary: true
}, {
  id: 'favorites',
  icon: 'heart',
  label: 'المفضلة'
}, {
  id: 'account',
  icon: 'user',
  label: 'حسابي'
}];

/**
 * Al Nujom — BottomNav. The 5-tab spine, RTL-ordered. Active tab shows the
 * accent color + a top accent bar; the center "إضافة" tab is a raised accent FAB.
 */
function BottomNav({
  items = DEFAULT_ITEMS,
  active = 'home',
  onSelect,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("nav", _extends({
    style: {
      display: 'flex',
      alignItems: 'flex-end',
      justifyContent: 'space-around',
      height: 72,
      padding: '0 6px 10px',
      background: 'var(--card)',
      borderTop: '1px solid var(--border)',
      boxShadow: 'var(--shadow-md)',
      ...style
    }
  }, rest), items.map(it => {
    const isActive = it.id === active;
    if (it.primary) {
      return /*#__PURE__*/React.createElement("button", {
        key: it.id,
        type: "button",
        onClick: () => onSelect && onSelect(it.id),
        style: {
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 5,
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          padding: 0,
          marginBottom: 2
        }
      }, /*#__PURE__*/React.createElement("span", {
        style: {
          width: 50,
          height: 50,
          borderRadius: 16,
          marginTop: -22,
          background: 'var(--accent-grad, var(--accent))',
          color: 'var(--accent-ink)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: 'var(--glow, var(--shadow-md))',
          border: '3px solid var(--card)'
        }
      }, /*#__PURE__*/React.createElement("i", {
        "data-lucide": it.icon,
        style: {
          width: 24,
          height: 24
        }
      })), /*#__PURE__*/React.createElement("span", {
        style: {
          fontFamily: 'var(--font-ui)',
          fontSize: 11,
          fontWeight: 700,
          color: 'var(--ink-muted)'
        }
      }, it.label));
    }
    return /*#__PURE__*/React.createElement("button", {
      key: it.id,
      type: "button",
      onClick: () => onSelect && onSelect(it.id),
      style: {
        position: 'relative',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 5,
        background: 'none',
        border: 'none',
        cursor: 'pointer',
        padding: '10px 4px 0',
        color: isActive ? 'var(--accent)' : 'var(--ink-muted)'
      }
    }, isActive && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        top: 0,
        width: 22,
        height: 3,
        borderRadius: 3,
        background: 'var(--accent)'
      }
    }), /*#__PURE__*/React.createElement("i", {
      "data-lucide": it.icon,
      style: {
        width: 23,
        height: 23,
        fill: isActive && it.id === 'favorites' ? 'var(--accent)' : 'none'
      }
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-ui)',
        fontSize: 11,
        fontWeight: isActive ? 800 : 600
      }
    }, it.label));
  }));
}
Object.assign(__ds_scope, { BottomNav });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/BottomNav.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Chip = __ds_scope.Chip;

__ds_ns.Field = __ds_scope.Field;

__ds_ns.PropertyCard = __ds_scope.PropertyCard;

__ds_ns.BottomNav = __ds_scope.BottomNav;

})();
