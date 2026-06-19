export const colors = {
  primary: '#1E3A5F',
  primaryLight: '#2D5A8E',
  accent: '#FFCE00',
  accentDark: '#E6B800',
  danger: '#DD0000',
  success: '#22C55E',
  successLight: '#DCFCE7',
  warning: '#F59E0B',
  background: '#F0F4F8',
  card: '#FFFFFF',
  border: '#E2E8F0',
  text: {
    primary: '#1A202C',
    secondary: '#718096',
    muted: '#A0AEC0',
    inverse: '#FFFFFF',
  },
  units: {
    u1: '#3B82F6',
    u2: '#8B5CF6',
    u3: '#10B981',
    u4: '#F59E0B',
    u5: '#EF4444',
    u6: '#6366F1',
  },
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
};

export const radius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  full: 9999,
};

export const typography = {
  h1: { fontSize: 28, fontWeight: '700' as const, letterSpacing: -0.5 },
  h2: { fontSize: 22, fontWeight: '700' as const, letterSpacing: -0.3 },
  h3: { fontSize: 18, fontWeight: '600' as const },
  body: { fontSize: 16, fontWeight: '400' as const },
  bodyBold: { fontSize: 16, fontWeight: '600' as const },
  small: { fontSize: 13, fontWeight: '400' as const },
  smallBold: { fontSize: 13, fontWeight: '600' as const },
  caption: { fontSize: 11, fontWeight: '400' as const },
};
