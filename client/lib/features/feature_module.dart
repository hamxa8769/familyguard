import 'package:flutter/material.dart';

/// Contract every feature implements. The dashboard and registry only know
/// about this interface, so features stay decoupled and pluggable.
abstract class FeatureModule {
  String get id;
  String get title;
  String get description;
  IconData get icon;

  /// The screen shown when this feature is opened.
  Widget buildScreen(BuildContext context);
}
