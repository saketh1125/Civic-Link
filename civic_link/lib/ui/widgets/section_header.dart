/// Section header — the small, all-caps, tracked-out label appearing above
/// groups of settings/list items (e.g. "ACCOUNT", "PREFERENCES").

import 'package:flutter/material.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.label, {
    super.key,
    this.padding = const EdgeInsets.only(left: 4, top: 24, bottom: 8),
    this.color,
  });

  final String label;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: padding,
      child: Text(
        label.toUpperCase(),
        style: sectionHeader(scheme).copyWith(
          color: color ?? scheme.primary,
        ),
      ),
    );
  }
}
