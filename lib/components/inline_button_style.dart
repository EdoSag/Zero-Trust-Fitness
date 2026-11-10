import 'package:flutter/material.dart';

/// Style for a [FilledButton] or [OutlinedButton] that sits in a [Row]
/// next to other widgets.
///
/// The shared Zero-Trust theme gives these buttons a full-width minimum
/// size (`Size.fromHeight(48)`), which is right in a column. In a row the
/// width is unbounded, so that minimum asks for an infinite width: the row
/// fails layout and, in a release build, draws nothing at all (the button
/// simply disappears). This style keeps the theme's height and shape but
/// lets the button size to its label.
const ButtonStyle inlineButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(64, 48)),
);
