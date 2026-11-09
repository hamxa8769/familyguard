import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../state/parent_state.dart';

/// Shows [builder] for the currently selected child device, or a hint to pair
/// one. Rebuilds when the parent switches device.
class DeviceScoped extends StatelessWidget {
  const DeviceScoped({super.key, required this.title, required this.builder});

  final String title;
  final Widget Function(BuildContext context, String deviceId) builder;

  @override
  Widget build(BuildContext context) {
    final state = ParentState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final id = state.selectedDeviceId;
        if (id == null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No child device is paired yet.\n\n'
                  'Open "My Children", add a child, and enter the pairing code '
                  'in the FamilyGuard (Child) app on their device.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        // Key by device so state resets when the parent switches child.
        return KeyedSubtree(key: ValueKey(id), child: builder(context, id));
      },
    );
  }
}

/// FutureBuilder with loading, error + retry, and pull-to-refresh handled.
class ApiView<T> extends StatefulWidget {
  const ApiView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
      builder;

  @override
  State<ApiView<T>> createState() => _ApiViewState<T>();
}

class _ApiViewState<T> extends State<ApiView<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  Text('${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _reload, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: widget.builder(context, snap.data as T, _reload),
        );
      },
    );
  }
}

/// Centered hint for an empty list (scrollable so pull-to-refresh works).
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ],
      );
}

/// Runs a save call and reports the result in a SnackBar.
Future<bool> saveWithFeedback(
  BuildContext context,
  Future<void> Function() action,
  String success,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('Not saved: ${e.message}'),
      backgroundColor: Colors.red,
    ));
    return false;
  }
}

/// "5 min ago", "2 h ago", "3 d ago".
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}
