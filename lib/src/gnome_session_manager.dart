import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:meta/meta.dart';

import 'util.dart';

enum GnomeLogoutMode {
  /// Normal
  normal,

  /// No confirmation interface should be shown.
  noConfirm,

  /// Forcefully logout. No confirmation will be shown and any inhibitors will
  /// be ignored.
  force,
}

/// The client that connects to the GNOME Session Manager
class GnomeSessionManager {
  GnomeSessionManager({
    DBusClient? bus,
    @visibleForTesting DBusRemoteObject? object,
  })  : _bus = bus,
        _object = object ?? _createRemoteObject(bus);

  static DBusRemoteObject _createRemoteObject(DBusClient? bus) {
    return DBusRemoteObject(
      bus ?? DBusClient.session(),
      name: busName,
      path: DBusObjectPath(objectPath),
    );
  }

  static final String busName = 'org.gnome.SessionManager';
  static final String objectPath = '/org/gnome/SessionManager';

  final DBusClient? _bus;
  final DBusRemoteObject _object;
  final _properties = <String, DBusValue>{};
  final _propertyController = StreamController<List<String>>.broadcast();
  StreamSubscription? _propertySubscription;

  /// If true, the session is currently in the foreground and available for user
  /// input.
  bool get sessionIsActive => _getProperty('SessionIsActive', false);

  /// The name of the session that has been loaded.
  String get sessionName => _getProperty('SessionName', '');

  /// Request a logout dialog.
  Future<void> logout({Set<GnomeLogoutMode> mode = const {}}) {
    var logoutMode = 0;
    for (final flag in mode) {
      logoutMode |= flag.index;
    }
    return _object.callMethod(busName, 'Logout', [DBusUint32(logoutMode)],
        replySignature: DBusSignature(''));
  }

  /// Request a reboot dialog.
  Future<void> reboot() {
    return _object.callMethod(busName, 'Reboot', [],
        replySignature: DBusSignature(''));
  }

  /// Request a shutdown dialog.
  Future<void> shutdown() {
    return _object.callMethod(busName, 'Shutdown', [],
        replySignature: DBusSignature(''));
  }

  /// True if shutdown is available to the user, false otherwise
  Future<bool> canShutdown() async {
    return _object
        .callMethod(busName, 'CanShutdown', [],
            replySignature: DBusSignature('b'))
        .then((response) => response.values.first.asBoolean());
  }

  /// True if the session has entered the Running phase, false otherwise
  Future<bool> isSessionRunning() async {
    return _object
        .callMethod(busName, 'IsSessionRunning', [],
            replySignature: DBusSignature('b'))
        .then((response) => response.values.first.asBoolean());
  }

  /// Connects to the Session Manager service.
  Future<void> connect() async {
    // Already connected
    if (_propertySubscription != null) {
      return;
    }
    _propertySubscription ??= _object.propertiesChanged.listen((signal) {
      if (signal.propertiesInterface == busName) {
        _updateProperties(signal.changedProperties);
      }
    });
    return _object.getAllProperties(busName).then(_updateProperties);
  }

  /// Closes connection to the Session Manager service.
  Future<void> close() async {
    await _propertySubscription?.cancel();
    _propertySubscription = null;
    if (_bus == null) {
      await _object.client.close();
    }
  }

  T _getProperty<T>(String name, T defaultValue) {
    return _properties.get(name) ?? defaultValue;
  }

  void _updateProperties(Map<String, DBusValue> properties) {
    _properties.addAll(properties);
    _propertyController.add(properties.keys.toList());
  }
}