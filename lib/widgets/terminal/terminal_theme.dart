import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

const TerminalTheme d1vTerminalLightTheme = TerminalTheme(
  cursor: Color(0xFF047857),
  selection: Color(0xFFBFDBFE),
  foreground: Color(0xFF1F2937),
  background: Color(0xFFF8FAFC),
  black: Color(0xFF111827),
  red: Color(0xFFB91C1C),
  green: Color(0xFF047857),
  yellow: Color(0xFFA16207),
  blue: Color(0xFF1D4ED8),
  magenta: Color(0xFFA21CAF),
  cyan: Color(0xFF0E7490),
  white: Color(0xFFE5E7EB),
  brightBlack: Color(0xFF4B5563),
  brightRed: Color(0xFFDC2626),
  brightGreen: Color(0xFF059669),
  brightYellow: Color(0xFFCA8A04),
  brightBlue: Color(0xFF2563EB),
  brightMagenta: Color(0xFFC026D3),
  brightCyan: Color(0xFF0891B2),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFFDE68A),
  searchHitBackgroundCurrent: Color(0xFFFBBF24),
  searchHitForeground: Color(0xFF111827),
);

const TerminalTheme d1vTerminalDarkTheme = TerminalTheme(
  cursor: Color(0xFF34D399),
  selection: Color(0xFF374151),
  foreground: Color(0xFFE5E7EB),
  background: Color(0xFF0B0D10),
  black: Color(0xFF111827),
  red: Color(0xFFF87171),
  green: Color(0xFF34D399),
  yellow: Color(0xFFFBBF24),
  blue: Color(0xFF60A5FA),
  magenta: Color(0xFFE879F9),
  cyan: Color(0xFF22D3EE),
  white: Color(0xFFD1D5DB),
  brightBlack: Color(0xFF6B7280),
  brightRed: Color(0xFFFCA5A5),
  brightGreen: Color(0xFF6EE7B7),
  brightYellow: Color(0xFFFDE047),
  brightBlue: Color(0xFF93C5FD),
  brightMagenta: Color(0xFFF0ABFC),
  brightCyan: Color(0xFF67E8F9),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF854D0E),
  searchHitBackgroundCurrent: Color(0xFFA16207),
  searchHitForeground: Color(0xFFFFFFFF),
);

TerminalTheme d1vTerminalTheme(Brightness brightness) =>
    brightness == Brightness.dark
    ? d1vTerminalDarkTheme
    : d1vTerminalLightTheme;
