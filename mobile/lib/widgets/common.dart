import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../theme.dart';

export '../theme.dart';

// ================================================================== Туслах функцууд
String formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  final time = '${two(d.hour)}:${two(d.minute)}';
  if (diff == 0) return 'Өнөөдөр, $time';
  if (diff == 1) return 'Өчигдөр, $time';
  return '${d.year}.${two(d.month)}.${two(d.day)}';
}

const kWeekdays = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

void showSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text, style: const TextStyle(color: Colors.white)),
    backgroundColor: error ? const Color(0xFFB4413A) : kEmeraldDeep,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ));
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String ok = 'Тийм'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: serif(size: 20)),
      content: Text(body, style: const TextStyle(color: kSlate)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Болих')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

/// Өвчний үүсгэгчээс дүрс, өнгө, төрлийг гаргана.
class PathogenStyle {
  final String emoji;
  final Color color;
  final String type;
  const PathogenStyle(this.emoji, this.color, this.type);
}

PathogenStyle pathogenStyle(String pathogen, bool healthy) {
  if (healthy) return const PathogenStyle('🍃', kLeaf, 'Эрүүл');
  final p = pathogen.toLowerCase();
  if (p.contains('мөөгөнцөр')) return const PathogenStyle('🍄', kCoral, 'Мөөгөнцөр');
  if (p.contains('оомицет')) return const PathogenStyle('💧', kCoral, 'Оомицет');
  if (p.contains('бактери')) return const PathogenStyle('🦠', kAmber, 'Бактери');
  if (p.contains('вирус')) return const PathogenStyle('🧬', kPurple, 'Вирус');
  if (p.contains('хортон') || p.contains('хачиг')) return const PathogenStyle('🕷️', kAmber, 'Хортон');
  return const PathogenStyle('🍂', kAmber, 'Өвчин');
}

/// "Мөөгөнцөр — Venturia inaequalis" → "Venturia inaequalis"
String latinName(String pathogen) {
  final i = pathogen.indexOf('—');
  final s = i >= 0 ? pathogen.substring(i + 1).trim() : pathogen.trim();
  return s == '—' ? '' : s;
}

Color severityColor(String severity) {
  switch (severity) {
    case 'Эрүүл':
      return kLeaf;
    case 'Анхан шат':
      return kTeal;
    case 'Бага':
      return kAmber;
    case 'Дунд':
      return kOrange;
    case 'Хүнд':
      return kCoral;
    default:
      return kMuted;
  }
}

Color statusColor(Diagnosis d) => d.needsReview ? kAmber : (d.status == 'confirmed' ? kBlue : kLeaf);

// ================================================================== Дэвсгэр, суурь
/// Дээрээс доош бараан ногоон градиент + бүдэг ногоон гэрлийн толбо + навчны хээ.
class LeafBackground extends StatelessWidget {
  final Widget child;
  final bool foliage;
  const LeafBackground({super.key, required this.child, this.foliage = true});

  Widget _glow(double s, Color c) => IgnorePointer(
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withAlpha(0)])),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kBgTop, kBgMid, kBgBottom],
            ),
          ),
        ),
      ),
      Positioned(top: -80, right: -80, child: _glow(300, kEmerald.withAlpha(48))),
      Positioned(bottom: 20, left: -90, child: _glow(330, const Color(0xFF047857).withAlpha(60))),
      if (foliage) ...[
        Positioned(
          top: 90,
          left: -80,
          child: Transform.rotate(angle: -0.5, child: Icon(Icons.eco, size: 260, color: Colors.white.withAlpha(8))),
        ),
        Positioned(
          bottom: 160,
          right: -70,
          child: Transform.rotate(angle: 0.8, child: Icon(Icons.spa, size: 230, color: Colors.white.withAlpha(6))),
        ),
      ],
      Positioned.fill(child: child),
    ]);
  }
}

/// Дэлгэцийн суурь. Үндсэн табуудад AppBar байхгүй (гарчиг нь PageHeader-аар),
/// дэд дэлгэцүүдэд тунгалаг AppBar + буцах товч.
class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final bool foliage;
  const AppScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.foliage = true,
  });

  @override
  Widget build(BuildContext context) {
    final showBar = title != null || actions != null || bottom != null;
    return Scaffold(
      backgroundColor: kBg1,
      extendBodyBehindAppBar: true,
      appBar: !showBar
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: kText,
              centerTitle: true,
              leading: Navigator.of(context).canPop()
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Center(
                        child: GlassIconButton(
                          icon: Icons.chevron_left,
                          size: 38,
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      ),
                    )
                  : null,
              title: title == null ? null : Text(title!, style: serif(size: 18)),
              actions: actions,
              bottom: bottom,
            ),
      floatingActionButton: floatingActionButton,
      body: LeafBackground(foliage: foliage, child: SafeArea(bottom: false, child: body)),
    );
  }
}

/// Дэлгэцийн дээд гарчиг: serif том гарчиг + ногоон тайлбар.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool center;
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing, this.center = false});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final text = Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(title, style: serif(size: 24)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: TextStyle(color: kMint.withAlpha(205), fontSize: 12.5)),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 16),
      child: Row(children: [
        if (canPop) ...[
          GlassIconButton(icon: Icons.chevron_left, size: 38, onPressed: () => Navigator.maybePop(context)),
          const SizedBox(width: 12),
        ],
        Expanded(child: text),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ================================================================== Шилэн карт, товчнууд
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color color;
  final Color border;
  final bool blur;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.radius = 16,
    this.onTap,
    this.color = kGlassDark,
    this.border = kBorder,
    this.blur = false,
  });

  /// Илүү тод "glass-dark-card" хувилбар.
  const Glass.card({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 24,
    this.onTap,
    this.color = kGlassCard,
    this.border = const Color(0x26FFFFFF),
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: br, border: Border.all(color: border)),
      child: child,
    );
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: br, child: content),
      );
    }
    if (blur) {
      content = ClipRRect(
        borderRadius: br,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: content),
      );
    }
    return margin == null ? content : Padding(padding: margin!, child: content);
  }
}

/// Ногоон градиент "pill" товч (цагаан бичигтэй) — дизайны гол товч.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? trailingText;
  final bool loading;
  final bool expand;
  final bool secondary;
  final bool small;
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingText,
    this.loading = false,
    this.expand = false,
    this.secondary = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final pad = small ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8) : const EdgeInsets.symmetric(horizontal: 22, vertical: 15);
    final fontSize = small ? 12.5 : 14.5;
    final child = Padding(
      padding: pad,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
          else ...[
            if (icon != null) ...[Icon(icon, color: Colors.white, size: small ? 16 : 19), const SizedBox(width: 8)],
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: fontSize, letterSpacing: 0.2)),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(trailingText!, style: TextStyle(color: Colors.white, fontSize: fontSize + 2)),
            ],
          ],
        ],
      ),
    );
    final decoration = BoxDecoration(
      gradient: secondary ? null : kEmeraldGradient,
      color: secondary ? const Color(0x26FFFFFF) : null,
      borderRadius: BorderRadius.circular(40),
      border: secondary ? Border.all(color: kBorderStrong) : null,
      boxShadow: secondary || !enabled
          ? null
          : [BoxShadow(color: const Color(0xFF064E3B).withAlpha(140), blurRadius: 18, offset: const Offset(0, 8))],
    );
    final btn = Opacity(
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: enabled ? onPressed : null,
            child: child,
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color iconColor;
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 40,
    this.iconColor = kText,
  });

  @override
  Widget build(BuildContext context) {
    final b = Material(
      color: kGlassDark,
      shape: const CircleBorder(side: BorderSide(color: kBorderStrong)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(width: size, height: size, child: Icon(icon, color: iconColor, size: size * 0.5)),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// Жижиг хэсгийн гарчиг + баруун талын ногоон холбоос.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kText, letterSpacing: 0.3)),
          ),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(action!, style: const TextStyle(color: kLeaf, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
        ]),
      );
}

/// Жижиг дээд үсгийн гарчиг (дизайны "uppercase tracking-wider").
class CapsLabel extends StatelessWidget {
  final String text;
  const CapsLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kSlate, letterSpacing: 1.0)),
      );
}

/// Өнгөт тэмдэглэгээ (badge).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;
  const Pill(this.text, {super.key, required this.color, this.icon, this.solid = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: solid ? color : color.withAlpha(50),
          borderRadius: BorderRadius.circular(20),
          border: solid ? null : Border.all(color: color.withAlpha(76)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 11, color: solid ? Colors.white : color), const SizedBox(width: 4)],
          Text(text,
              style: TextStyle(color: solid ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final Diagnosis d;
  const StatusChip(this.d, {super.key});

  @override
  Widget build(BuildContext context) => Pill(d.statusLabel, color: statusColor(d));
}

/// Шүүлтүүрийн chip: сонгогдсон нь ногоон дүүрэн, бусад нь шилэн.
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const FilterPill(this.label, {super.key, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? kEmerald : kGlassDark,
          shape: StadiumBorder(side: BorderSide(color: selected ? kEmerald : kBorder)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: selected ? Colors.white : kSlate,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            ),
          ),
        ),
      );
}

/// Хэмжүүрийн жижиг хавтан (утга + тайлбар).
class MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData? icon;
  const MetricTile({super.key, required this.value, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: kTile,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Column(children: [
          if (icon != null) ...[Icon(icon, color: color, size: 18), const SizedBox(height: 4)],
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: kSlate, fontSize: 10.5)),
        ]),
      );
}

/// Дугуй ногоон градиент дүрс (аватар).
class GradientAvatar extends StatelessWidget {
  final String name;
  final double size;
  const GradientAvatar(this.name, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [kEmeraldDeep, Color(0xFF14B8A6), kMint],
        ),
        border: Border.all(color: Colors.white.withAlpha(120), width: size > 50 ? 2 : 1),
        boxShadow: [BoxShadow(color: const Color(0xFF064E3B).withAlpha(150), blurRadius: size / 3)],
      ),
      child: Text(initial,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

/// Ногоон градиент дөрвөлжин доторх навчны лого.
class LeafLogo extends StatelessWidget {
  final double size;
  const LeafLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kLeaf.withAlpha(76), const Color(0xFF047857).withAlpha(102)],
          ),
          border: Border.all(color: kMint.withAlpha(102)),
        ),
        child: Icon(Icons.eco, color: kMint, size: size * 0.56),
      );
}

/// Ваартай ургамлын энгийн зураг (гадны зураг шаардахгүй).
class PlantArt extends StatelessWidget {
  final double size;
  const PlantArt({super.key, this.size = 130});

  Widget _leaf(double s) => ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EE7B7), Color(0xFF065F46)],
        ).createShader(r),
        child: Icon(Icons.eco, size: s, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
        Positioned(bottom: size * 0.30, left: -size * 0.02, child: Transform.rotate(angle: -0.9, child: _leaf(size * 0.5))),
        Positioned(bottom: size * 0.30, right: -size * 0.02, child: Transform.rotate(angle: 0.5, child: _leaf(size * 0.5))),
        Positioned(bottom: size * 0.34, child: Transform.rotate(angle: -0.2, child: _leaf(size * 0.62))),
        Container(
          width: size * 0.48,
          height: size * 0.36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF3F0E7), Color(0xFFC9C2B0)],
            ),
            borderRadius: BorderRadius.vertical(top: const Radius.circular(6), bottom: Radius.circular(size * 0.12)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 16, offset: const Offset(0, 12))],
          ),
        ),
      ]),
    );
  }
}

// ================================================================== Төлөвийн харагдац
class LoadingView extends StatelessWidget {
  final String? text;
  const LoadingView({super.key, this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: kLeaf),
          if (text != null) ...[
            const SizedBox(height: 18),
            Text(text!, textAlign: TextAlign.center, style: const TextStyle(color: kSlate)),
          ],
        ]),
      );
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Glass.card(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, size: 44, color: kMuted),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: kSlate)),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                PillButton(label: 'Дахин оролдох', icon: Icons.refresh, onPressed: onRetry, small: true),
              ],
            ]),
          ),
        ),
      );
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyView({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kGlassDark,
              shape: BoxShape.circle,
              border: Border.all(color: kBorder),
            ),
            child: Icon(icon, size: 40, color: kLeaf),
          ),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kSlate, fontSize: 13.5)),
        ]),
      );
}

/// Серверийн зураг (алдаа гарвал дүрс харуулна).
class NetImage extends StatelessWidget {
  final String path;
  final double? height;
  final double? width;
  final BoxFit fit;
  const NetImage(this.path, {super.key, this.height, this.width, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => Image.network(
        ApiClient.instance.mediaUrl(path),
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: width,
          color: const Color(0xFF022C22),
          child: const Icon(Icons.eco, color: kMuted),
        ),
        loadingBuilder: (c, child, p) => p == null
            ? child
            : Container(
                height: height,
                width: width,
                color: const Color(0xFF022C22),
                child: const Center(child: CircularProgressIndicator(color: kLeaf, strokeWidth: 2))),
      );
}

// ================================================================== Өвчний мэдээллийн хэсгүүд
/// Дизайны мэдээллийн хэсэг: шилэн хайрцаг, ногоон гарчиг + emoji.
class InfoSection extends StatelessWidget {
  final String emoji;
  final String title;
  final Widget child;
  const InfoSection({super.key, required this.emoji, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Glass(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(color: kMint, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: const TextStyle(color: kSlate, fontSize: 13, height: 1.5),
            child: child,
          ),
        ]),
      );
}

/// Хуучин нэр — InfoSection-ий icon хувилбар.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const SectionCard({super.key, required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Glass(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: kMint, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(color: kMint, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(style: const TextStyle(color: kSlate, fontSize: 13, height: 1.5), child: child),
        ]),
      );
}

/// Эмчилгээний мөр: 🌿 Органик / 🧪 Химийн.
class TreatmentRow extends StatelessWidget {
  final Treatment t;
  const TreatmentRow(this.t, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(t.isOrganic ? '🌿' : '🧪', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.method,
                  style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (t.isOrganic ? kEmerald : const Color(0xFF3B82F6)).withAlpha(50),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(t.isOrganic ? 'Органик' : 'Химийн',
                  style: TextStyle(fontSize: 10.5, color: t.isOrganic ? kMint : kBlue, fontWeight: FontWeight.w600)),
            ),
          ]),
          if (t.instructions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 5),
              child: Text(t.instructions, style: const TextStyle(color: kMuted, fontSize: 12, height: 1.45)),
            ),
        ]),
      );
}

/// Өвчний дэлгэрэнгүй мэдээлэл (үр дүн ба мэдээллийн хуудсанд хоёуланд).
class DiseaseDetails extends StatelessWidget {
  final Disease d;
  final bool showTreatments;
  const DiseaseDetails(this.d, {super.key, this.showTreatments = true});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (d.symptoms.isNotEmpty) InfoSection(emoji: '🔍', title: 'Шинж тэмдэг', child: Text(d.symptoms)),
        if (d.description.isNotEmpty)
          InfoSection(
            emoji: '📖',
            title: 'Өвчний тухай',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (latinName(d.pathogen).isNotEmpty) ...[
                Text('Үүсгэгч: ${d.pathogen}', style: const TextStyle(fontStyle: FontStyle.italic, color: kMintSoft)),
                const SizedBox(height: 6),
              ],
              Text(d.description),
            ]),
          ),
        if (showTreatments && d.treatments.isNotEmpty)
          InfoSection(
            emoji: '🌱',
            title: d.isHealthy ? 'Арчилгааны зөвлөгөө' : 'Эмчилгээний зөвлөмж',
            child: Column(children: d.treatments.map((t) => TreatmentRow(t)).toList()),
          ),
        if (d.prevention.isNotEmpty) InfoSection(emoji: '🛡️', title: 'Урьдчилан сэргийлэх', child: Text(d.prevention)),
        if (!d.isHealthy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              'Химийн бодис хэрэглэхдээ шошгон дээрх тун, хамгаалалт, хураалтын өмнөх хүлээх хугацааг заавал баримтална уу.',
              style: TextStyle(fontSize: 11.5, color: kMuted),
            ),
          ),
      ]);
}
