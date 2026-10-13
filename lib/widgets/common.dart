import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Colours from `DesignHelpers.swift`.
class QColors {
  static const blue = Color(0xFF2B8CEE);
  static const background = Color(0xFFF6F7F8);
  static const ink = Color(0xFF0D141B);
  static const muted = Color(0xFF4C739A);
  static const border = Color(0xFFE5E7EB);
  static const grouped = Color(0xFFF2F2F7);
  static const card = Colors.white;
}

/// `WebImage` replacement with a spinner placeholder and a fallback.
class NetImage extends StatelessWidget {
  const NetImage(this.url,
      {super.key, this.width, this.height, this.fit = BoxFit.cover, this.fallback});

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final fb = fallback ??
        Image.asset('assets/apartment1.jpg',
            width: width, height: height, fit: fit);
    if (url == null || url!.isEmpty) return fb;
    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, _) => SizedBox(
        width: width,
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, _, _) => fb,
    );
  }
}

/// Circular profile photo with a person-icon fallback.
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, this.size = 48, this.color = QColors.blue});

  final String? url;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
      child: Icon(Icons.person, color: color, size: size * .5),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipOval(
      child: NetImage(url, width: size, height: size, fallback: placeholder),
    );
  }
}

/// Rounded white card with the subtle border used across the dashboards.
class QCard extends StatelessWidget {
  const QCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      this.color = QColors.card});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Icon tile + title/subtitle + chevron, used for "Messages",
/// "Upcoming Event" and similar dashboard rows.
class NavCard extends StatelessWidget {
  const NavCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.circle = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return QCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .12),
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: Colors.black38),
      ]),
    );
  }
}

/// Plain-text placeholder card ("No upcoming events scheduled.").
class EmptyCard extends StatelessWidget {
  const EmptyCard(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => QCard(
        child: SizedBox(
          width: double.infinity,
          child: Text(text,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text(text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          ?trailing,
        ]),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      );
}

class FieldError extends StatelessWidget {
  const FieldError(this.error, {super.key});
  final String? error;

  @override
  Widget build(BuildContext context) => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(error!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        );
}

/// `QuartierFieldModifier`: white, 50pt tall, 10pt radius, light border.
InputDecoration quartierField(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QColors.blue)),
    );

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label,
      {super.key,
      required this.onPressed,
      this.color = QColors.blue,
      this.busy = false,
      this.height = 50});

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
}

Future<void> showMessage(BuildContext context, String title, String message,
    {VoidCallback? onOk}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message.isEmpty ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onOk?.call();
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

/// Builds an [AsyncValue] with a spinner while loading and the error text on
/// failure, so every screen handles Firestore errors (e.g. a missing index).
Widget asyncBody<T>(AsyncValue<T> value, Widget Function(T) data) =>
    value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Something went wrong:\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
