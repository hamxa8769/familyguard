import 'package:flutter/material.dart';

/// Which bottom-navigation tab a feature lives under.
enum FeatureSection { activity, rules, alerts, family }

/// Contract every parent-side feature implements. The tabs and registry only
/// know about this interface, so features stay decoupled and pluggable.
abstract class FeatureModule {
  String get id;
  String get title;
  String get description;
  IconData get icon;
  FeatureSection get section;
  Widget buildScreen(BuildContext context);
}
