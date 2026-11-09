import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// OpenStreetMap base map styled for the app (tiles darkened in dark mode).
/// No API key needed. Production builds should switch to a paid/self-hosted
/// tile provider — the public OSM servers are for light use only.
class FgMap extends StatelessWidget {
  const FgMap({
    super.key,
    required this.layers,
    this.center,
    this.fitPoints,
    this.zoom = 15,
    this.onTap,
    this.controller,
    this.interactive = true,
  });

  final List<Widget> layers;
  final LatLng? center;

  /// When 2+ points are given the camera fits them all.
  final List<LatLng>? fitPoints;
  final double zoom;
  final void Function(LatLng point)? onTap;
  final MapController? controller;
  final bool interactive;

  static const fallbackCenter = LatLng(31.5204, 74.3587); // Lahore

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fit = fitPoints != null && fitPoints!.length >= 2
        ? CameraFit.coordinates(
            coordinates: fitPoints!,
            padding: const EdgeInsets.all(48),
            maxZoom: 17,
          )
        : null;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center ?? fitPoints?.firstOrNull ?? fallbackCenter,
        initialZoom: zoom,
        initialCameraFit: fit,
        backgroundColor: c.surfaceHigh,
        onTap: onTap == null ? null : (_, p) => onTap!(p),
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.familyguard.familyguard_parent',
          tileBuilder: dark ? darkModeTileBuilder : null,
        ),
        ...layers,
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

/// Glowing dot for "child is here".
class ChildPin extends StatelessWidget {
  const ChildPin({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final col = color ?? c.accent;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: col.withValues(alpha: 0.25),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: col,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      ),
    );
  }
}
