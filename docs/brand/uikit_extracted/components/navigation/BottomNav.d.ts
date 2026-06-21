import React from 'react';

export interface BottomNavItem {
  id: string;
  /** Lucide icon name */
  icon: string;
  label: string;
  /** Render as the raised center FAB (the "إضافة" tab) */
  primary?: boolean;
}

export interface BottomNavProps {
  /** Defaults to the 5 product tabs: الرئيسية · البحث · إضافة · المفضلة · حسابي */
  items?: BottomNavItem[];
  active?: string;
  onSelect?: (id: string) => void;
  style?: React.CSSProperties;
}

/**
 * The app's 5-tab bottom navigation, RTL-ordered. Active tab = accent + top
 * accent bar; the center "إضافة" tab is a raised accent FAB (orange gradient
 * on the Bold direction). Pins to the bottom of a screen.
 */
export function BottomNav(props: BottomNavProps): React.ReactElement;
