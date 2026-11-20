import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ------------------------------------------------------------------ Өнгө (дизайны "botanical" палитр)
const kBgTop = Color(0xFF1B3D2C);
const kBgMid = Color(0xFF102B1F);
const kBg1 = Color(0xFF0E241A);
const kBgBottom = Color(0xFF081710);

const kEmerald = Color(0xFF10B981); // emerald-500 — гол товч
const kEmeraldDeep = Color(0xFF059669); // emerald-600
const kLeaf = Color(0xFF34D399); // emerald-400 — идэвхтэй icon, холбоос
const kMint = Color(0xFF6EE7B7); // emerald-300 — гарчгийн тодруулга
const kMintSoft = Color(0xFFA7F3D0); // emerald-200

const kGlassDark = Color(0xA60E241A); // rgba(14,36,26,.65)
const kGlassCard = Color(0xB8123023); // rgba(18,48,35,.72)
const kTile = Color(0x99022C22); // emerald-950/60 — хэмжүүрийн хавтан, оролт
const kBorder = Color(0x1FFFFFFF); // white/12
const kBorderStrong = Color(0x33FFFFFF); // white/20
const kFieldBorder = Color(0x4D059669); // emerald-600/30

const kText = Color(0xFFFFFFFF);
const kSlate = Color(0xFFCBD5E1); // slate-300
const kMuted = Color(0xFF94A3B8); // slate-400

const kCoral = Color(0xFFF87171);
const kAmber = Color(0xFFFBBF24);
const kOrange = Color(0xFFFB923C);
const kTeal = Color(0xFF5EEAD4);
const kBlue = Color(0xFF93C5FD);
const kPurple = Color(0xFFD8B4FE);

const kEmeraldGradient = LinearGradient(colors: [kEmerald, kEmeraldDeep]);

// Хуучин нэрс (бусад файлд ашиглагдсан)
const kAccent = kLeaf;
const kAccentDark = kBg1;
const kGreen = kLeaf;
const kGlass = kGlassDark;
const kGlassStrong = Color(0x1AFFFFFF);
const kLightGreen = kGlassStrong;
const kGlassBorder = kBorder;
const kDanger = kCoral;
const kWarning = kAmber;
const kInfo = kBlue;

/// Google Fonts ашиглах эсэх. Тестэд false болгоно (сүлжээгүй орчин).
bool useGoogleFonts = true;

/// Гарчгийн serif фонт (Lora — монгол Ө, Ү үсгийг бүрэн дэмждэг).
TextStyle serif({double size = 28, FontWeight weight = FontWeight.w700, Color color = kText, double? height}) =>
    useGoogleFonts
        ? GoogleFonts.lora(fontSize: size, fontWeight: weight, color: color, height: height)
        : TextStyle(fontFamily: 'serif', fontSize: size, fontWeight: weight, color: color, height: height);

const kPlantEmoji = {
  'Алим': '🍏',
  'Эрдэнэ шиш': '🌽',
  'Усан үзэм': '🍇',
  'Төмс': '🥔',
  'Улаан лооль': '🍅',
};

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kEmerald, brightness: Brightness.dark).copyWith(
    primary: kEmerald,
    onPrimary: Colors.white,
    secondary: kLeaf,
    onSecondary: kBg1,
    secondaryContainer: kEmerald,
    onSecondaryContainer: Colors.white,
    surface: const Color(0xFF123023),
    onSurface: kText,
    surfaceContainerHigh: const Color(0xFF143626),
    error: kCoral,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: kBg1,
    textTheme: (useGoogleFonts ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme)
        .apply(bodyColor: kText, displayColor: kText),
  );
}

/// Дизайны оролтын талбар: бараан ногоон дэвсгэр, нимгэн ногоон хүрээ, 12px булан.
InputDecoration glassInput(String label, {IconData? icon, String? hint, String? helper, Widget? suffix}) {
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label.isEmpty ? null : label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: icon == null ? null : Icon(icon, color: kMint.withAlpha(150), size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: kTile,
    labelStyle: TextStyle(color: kMintSoft.withAlpha(200), fontSize: 13),
    floatingLabelStyle: const TextStyle(color: kLeaf),
    hintStyle: const TextStyle(color: kMuted, fontSize: 13),
    helperStyle: const TextStyle(color: kMuted, fontSize: 11.5),
    counterStyle: const TextStyle(color: kMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(kFieldBorder),
    enabledBorder: b(kFieldBorder),
    focusedBorder: b(kLeaf, 1.4),
    errorBorder: b(kCoral),
    focusedErrorBorder: b(kCoral, 1.4),
  );
}
