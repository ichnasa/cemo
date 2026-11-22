import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'models.dart';

/// Lucide versions of the category symbols, in the same order as
/// [kCategoryIcons]. The model keeps storing its own icon (by index), so saved
/// data is unchanged; the UI only swaps the glyph it draws.
const List<IconData> kCategoryLucideIcons = <IconData>[
  FLucideIcons.bookOpen,
  FLucideIcons.briefcase,
  FLucideIcons.lightbulb,
  FLucideIcons.shoppingCart,
  FLucideIcons.graduationCap,
  FLucideIcons.utensils,
  FLucideIcons.plane,
  FLucideIcons.folder,
  FLucideIcons.link,
  FLucideIcons.bookmark,
  FLucideIcons.pin,
  FLucideIcons.bell,
  FLucideIcons.clock,
  FLucideIcons.calendar,
  FLucideIcons.mic,
  FLucideIcons.notepadText,
];

/// The Lucide glyph to draw for a category [icon] from the model.
IconData lucideCategoryIcon(IconData icon) {
  final int i = kCategoryIcons.indexOf(icon);
  return (i >= 0 && i < kCategoryLucideIcons.length) ? kCategoryLucideIcons[i] : icon;
}
