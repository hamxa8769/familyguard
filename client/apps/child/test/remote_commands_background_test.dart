// Background remote commands (Phase 1 part B): only lock_now / unlock may
// run without the child tapping anything. Screenshot / audio requests and
// parent messages must stay pending until the child answers them on the
// Remote Commands screen — they need the child's tap (and Android's
// capture dialog) every time.
import 'package:familyguard_core/familyguard_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familyguard_child/sync/sync_service.dart';

RemoteCommand _command(String type) => RemoteCommand(
      id: '1',
      deviceId: 'd1',
      type: type,
      status: 'pending',
    );

void main() {
  test('lock_now and unlock may auto-execute in the background', () {
    expect(autoExecuteRemoteCommandInBackground(_command('lock_now')), isTrue);
    expect(autoExecuteRemoteCommandInBackground(_command('unlock')), isTrue);
  });

  test('screenshot, audio and messages never auto-execute', () {
    expect(autoExecuteRemoteCommandInBackground(_command('request_screenshot')),
        isFalse);
    expect(
        autoExecuteRemoteCommandInBackground(_command('request_audio')), isFalse);
    expect(
        autoExecuteRemoteCommandInBackground(_command('send_message')), isFalse);
    expect(
        autoExecuteRemoteCommandInBackground(_command('something_else')), isFalse);
  });
}
