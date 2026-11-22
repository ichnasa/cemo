import 'dart:io';

import 'package:flutter/material.dart';

import 'models.dart';
import 'storage.dart';
import 'theme.dart';

/// Round category avatar: the category's photo when it has one, otherwise a
/// white symbol on its colour.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.color, required this.icon, this.size = 32, this.imagePath});

  final Color color;
  final IconData icon;
  final double size;

  /// Relative path of a photo in app storage (see [Storage]).
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final Widget glyph = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.56, color: Colors.white),
    );
    final String? path = imagePath;
    if (path == null || !Storage.ready) return glyph;
    return ClipOval(
      child: Image.file(
        File(Storage.resolve(path)),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Decode small: avatars are tiny, and this keeps scrolling smooth.
        cacheWidth: (size * 3).round(),
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) => glyph,
      ),
    );
  }
}

enum PillKind { primary, secondary, text }

/// Black pill (primary), outlined pill (secondary) or plain text button.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = PillKind.primary,
    this.expand = true,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillKind kind;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final bool enabled = onPressed != null;
    Color fill = Colors.transparent;
    Color fg = c.t1;
    BoxBorder? border;
    if (kind == PillKind.primary) {
      fill = enabled ? c.primaryFill : c.disabled;
      fg = enabled ? c.primaryText : c.t3;
    } else if (kind == PillKind.secondary) {
      border = Border.all(color: c.border);
      fg = enabled ? c.t1 : c.t3;
    }
    final Widget pill = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: fill, border: border, borderRadius: BorderRadius.circular(999)),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Tx.uiStrong(context).copyWith(
          color: fg,
          fontWeight: kind == PillKind.primary ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: PressScale(
        onTap: onPressed,
        child: expand ? SizedBox(width: double.infinity, child: pill) : pill,
      ),
    );
  }
}

/// Shrinks its child very slightly while pressed. No fading, so nothing blinks.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Orange outlined reminder chip; red when overdue, grey and struck through when done.
class ReminderChip extends StatelessWidget {
  const ReminderChip({super.key, required this.when, this.done = false});

  final DateTime when;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final bool overdue = !done && when.isBefore(DateTime.now());
    final Color color = done ? c.t2 : (overdue ? c.destructive : c.reminder);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: done ? c.border : color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.notifications, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            reminderLabel(when),
            style: Tx.caption(context).copyWith(
              color: color,
              decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// A Memo illustration from assets/memo. The artwork is black on transparent,
/// so in Dark Mode it sits on a light tile to stay visible.
class MemoImage extends StatelessWidget {
  const MemoImage(this.scene, {super.key, this.size = 200, required this.label});

  final int scene;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final String path = 'assets/memo/s${scene.toString().padLeft(2, '0')}.png';
    final Widget img = Image.asset(path, width: size, height: size, fit: BoxFit.contain, semanticLabel: label);
    if (!context.isDark) return img;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(24)),
      child: img,
    );
  }
}

/// Centred illustration, serif headline, short text and an optional button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.scene,
    required this.imageLabel,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final int scene;
  final String imageLabel;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MemoImage(scene, size: 190, label: imageLabel),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Tx.serifTitle(context, size: 24)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: Tx.excerpt(context)),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: 20),
              PillButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal text tabs with a 1 pt underline on the selected one.
class TopicTabs extends StatelessWidget {
  const TopicTabs({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    return Container(
      height: 45,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 24),
        itemBuilder: (BuildContext context, int i) {
          final bool on = i == selected;
          return Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: on ? c.t1 : Colors.transparent)),
                ),
                child: Text(labels[i], style: Tx.tab(context).copyWith(color: on ? c.t1 : c.t2)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small uppercase section label.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8)});

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text.toUpperCase(), style: Tx.caption(context).copyWith(letterSpacing: 0.5)),
    );
  }
}

/// Text with every occurrence of [query] on the highlight colour.
class HighlightText extends StatelessWidget {
  const HighlightText({super.key, required this.text, required this.query, required this.style});

  final String text;
  final String query;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);
    final String lower = text.toLowerCase();
    final String q = query.toLowerCase();
    final List<TextSpan> spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final int i = lower.indexOf(q, start);
      if (i < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(
        text: text.substring(i, i + q.length),
        style: TextStyle(backgroundColor: context.c.highlight),
      ));
      start = i + q.length;
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
