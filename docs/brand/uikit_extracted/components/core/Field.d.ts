import React from 'react';

export interface FieldOption { value: string; label: string; }

export interface FieldProps {
  label?: string;
  value?: string;
  onChange?: (e: React.ChangeEvent<any>) => void;
  placeholder?: string;
  type?: string;
  /** Render as a plain input, a dropdown, or a multi-line textarea */
  as?: 'input' | 'select' | 'textarea';
  /** Trailing unit suffix, e.g. "م²" or "ل.س" */
  unit?: string;
  /** Options for as="select" */
  options?: (FieldOption | string)[];
  /** Leading Lucide icon name */
  icon?: string;
  /** Helper text under the field */
  hint?: string;
  rows?: number;
  style?: React.CSSProperties;
}

/**
 * Labelled form control (input / select / textarea). Focus draws the accent
 * border, plus the accent glow in the Dark and Bold directions (`--glow`).
 * On the Bold direction it picks up `--input-bg` / `--input-border` for the
 * deep-navy filled inputs.
 */
export function Field(props: FieldProps): React.ReactElement;
