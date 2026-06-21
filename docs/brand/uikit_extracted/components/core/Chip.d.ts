import React from 'react';

export interface ChipProps {
  children?: React.ReactNode;
  /** Lucide icon name (leading) */
  icon?: string;
  /** Selected = accent-filled */
  selected?: boolean;
  onClick?: () => void;
  /** Show a trailing × to remove (active-filter strip) */
  removable?: boolean;
  onRemove?: () => void;
  style?: React.CSSProperties;
}

/**
 * Pill chip used two ways: a horizontal category row on Home/Search, and a
 * removable active-filter strip on Search results. Idle = card+border;
 * selected = accent fill.
 */
export function Chip(props: ChipProps): React.ReactElement;
