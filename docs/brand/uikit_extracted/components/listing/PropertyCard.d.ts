import React from 'react';

export interface PropertySpecs {
  beds?: number;
  baths?: number;
  /** Area in m² (the "م²" suffix is added) */
  area?: number;
}

export interface PropertyCardProps {
  title: string;
  /** Pre-formatted amount string, e.g. "85,000,000" */
  price: string;
  currency?: string;
  /** Optional alternate-currency line, e.g. "≈ $32,000" */
  altPrice?: string;
  location: string;
  /** Photo URL (4:3 vertical / 1:1 horizontal). Falls back to an accent-soft block. */
  image?: string;
  layout?: 'vertical' | 'horizontal';
  featured?: boolean;
  favorite?: boolean;
  /** Over-photo purpose tag */
  purpose?: 'sale' | 'rent';
  specs?: PropertySpecs;
  onFavorite?: () => void;
  onClick?: () => void;
  style?: React.CSSProperties;
}

/**
 * The marketplace listing card. `vertical` for grids/feeds, `horizontal` for
 * search-result rows. Composes Badge for the featured / purpose tags.
 */
export function PropertyCard(props: PropertyCardProps): React.ReactElement;
