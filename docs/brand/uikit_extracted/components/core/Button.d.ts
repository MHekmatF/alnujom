import React from 'react';

export type ButtonVariant = 'primary' | 'gradient' | 'whatsapp' | 'outline' | 'ghost';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps {
  children?: React.ReactNode;
  /** primary = filled accent; gradient = bold orange gradient + glow; whatsapp = brand green; outline; ghost */
  variant?: ButtonVariant;
  size?: ButtonSize;
  /** Lucide icon name shown before the label (call lucide.createIcons() after render) */
  icon?: string;
  /** Lucide icon name shown after the label */
  iconEnd?: string;
  /** Stretch to full width */
  block?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  type?: 'button' | 'submit' | 'reset';
  style?: React.CSSProperties;
}

/**
 * The Al Nujom action button. Colors come from the active `.theme-*` scope, so
 * the same component renders gold (Premium), teal (Airy), blue (Dark) or the
 * orange gradient (Bold) automatically.
 */
export function Button(props: ButtonProps): React.ReactElement;
