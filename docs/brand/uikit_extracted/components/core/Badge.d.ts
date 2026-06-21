import React from 'react';

export type BadgeVariant =
  | 'featured'  // gold "مميّز" — premium listings
  | 'verified'  // green "موثّق" — verified agency (trust)
  | 'purpose'   // accent-filled "للبيع/للإيجار"
  | 'sale'      // soft green for-sale tag
  | 'rent'      // soft amber for-rent tag
  | 'glass'     // translucent dark, for over-photo use
  | 'neutral';  // quiet chip on surface

export interface BadgeProps {
  children?: React.ReactNode;
  variant?: BadgeVariant;
  /** Optional Lucide icon name (e.g. "badge-check") */
  icon?: string;
  style?: React.CSSProperties;
}

/**
 * Pill status marker. Never tappable. The gold `featured` and green `verified`
 * badges are the brand's two key trust signals.
 */
export function Badge(props: BadgeProps): React.ReactElement;
