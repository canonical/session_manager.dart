import 'package:dbus/dbus.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:ubuntu_session/ubuntu_session.dart';

import 'gnome_session_manager_test.mocks.dart';

@GenerateMocks([DBusClient, DBusRemoteObject])
void main() {
  final busName = GnomeSessionManager.busName;

  test('connect and disconnect', () async {
    final object = createMockRemoteObject();
    final bus = object.client as MockDBusClient;

    final manager = GnomeSessionManager(object: object);
    await manager.connect();
    verify(object.getAllProperties(busName)).called(1);

    await manager.close();
    verify(bus.close()).called(1);
  });

  test('read properties', () async {
    final object = createMockRemoteObject(properties: {
      'SessionIsActive': const DBusBoolean(true),
      'SessionName': const DBusString('ubuntu'),
    });

    final manager = GnomeSessionManager(object: object);
    await manager.connect();
    final sessionName = manager.sessionName;
    final sessionIsActive = manager.sessionIsActive;
    expect(sessionName, 'ubuntu');
    expect(sessionIsActive, true);
    await manager.close();
  });

  test('logout', () async {
    final object = createMockRemoteObject();
    final manager = GnomeSessionManager(object: object);
    await manager
        .logout(mode: {GnomeLogoutMode.force, GnomeLogoutMode.noConfirm});
    verify(object.callMethod(
      busName,
      'Logout',
      [
        DBusUint32(
            GnomeLogoutMode.force.index | GnomeLogoutMode.noConfirm.index)
      ],
      replySignature: DBusSignature(''),
    )).called(1);
  });

  test('reboot', () async {
    final object = createMockRemoteObject();
    final manager = GnomeSessionManager(object: object);
    await manager.reboot();
    verify(object.callMethod(busName, 'Reboot', [],
            replySignature: DBusSignature('')))
        .called(1);
  });

  test('shutdown', () async {
    final object = createMockRemoteObject();
    final manager = GnomeSessionManager(object: object);
    await manager.shutdown();
    verify(object.callMethod(busName, 'Shutdown', [],
            replySignature: DBusSignature('')))
        .called(1);
  });

  test('can shutdown', () async {
    final object = createMockRemoteObject(canShutdown: true);
    final manager = GnomeSessionManager(object: object);
    final canShutdown = await manager.canShutdown();
    verify(object.callMethod(busName, 'CanShutdown', [],
            replySignature: DBusSignature('b')))
        .called(1);
    expect(canShutdown, true);
  });

  test('is session running', () async {
    final object = createMockRemoteObject(isSessionRunning: true);
    final manager = GnomeSessionManager(object: object);
    final isSessionRunning = await manager.isSessionRunning();
    verify(object.callMethod(busName, 'IsSessionRunning', [],
            replySignature: DBusSignature('b')))
        .called(1);
    expect(isSessionRunning, true);
  });
}

MockDBusRemoteObject createMockRemoteObject({
  Stream<DBusPropertiesChangedSignal>? propertiesChanged,
  Map<String, DBusValue>? properties,
  bool canShutdown = false,
  bool isSessionRunning = false,
}) {
  final dbus = MockDBusClient();
  final object = MockDBusRemoteObject();
  final busName = GnomeSessionManager.busName;
  when(object.client).thenReturn(dbus);
  when(object.propertiesChanged)
      .thenAnswer((_) => propertiesChanged ?? const Stream.empty());
  when(object.getAllProperties(busName))
      .thenAnswer((_) async => properties ?? {});
  when(object.callMethod(busName, 'Logout', any,
          replySignature: DBusSignature('')))
      .thenAnswer((_) async => DBusMethodSuccessResponse());
  when(object.callMethod(busName, 'Reboot', [],
          replySignature: DBusSignature('')))
      .thenAnswer((_) async => DBusMethodSuccessResponse());
  when(object.callMethod(busName, 'Shutdown', [],
          replySignature: DBusSignature('')))
      .thenAnswer((_) async => DBusMethodSuccessResponse());
  when(object.callMethod(busName, 'CanShutdown', [],
          replySignature: DBusSignature('b')))
      .thenAnswer(
          (_) async => DBusMethodSuccessResponse([DBusBoolean(canShutdown)]));
  when(object.callMethod(busName, 'IsSessionRunning', [],
          replySignature: DBusSignature('b')))
      .thenAnswer((_) async =>
          DBusMethodSuccessResponse([DBusBoolean(isSessionRunning)]));
  return object;
}