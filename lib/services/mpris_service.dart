import 'dart:io';
import 'dart:async';
import 'package:dbus/dbus.dart';
import 'package:lizaplayer/services/player_service.dart';

class LizaplayerMprisService extends DBusObject {
  final PlayerService _playerService;
  DBusClient? _client;
  StreamSubscription? _trackSub;
  StreamSubscription? _playSub;
  
  LizaplayerMprisService(this._playerService) 
      : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  Future<void> init() async {
    if (!Platform.isLinux) return;
    
    try {
      _client = DBusClient.session();
      
      _client!.registerObject(this);
      
      await _client!.requestName('org.mpris.MediaPlayer2.lizaplayer',
          flags: {
            DBusRequestNameFlag.doNotQueue, 
            DBusRequestNameFlag.replaceExisting,
            DBusRequestNameFlag.allowReplacement
          });
      
      _trackSub = _playerService.trackStream.listen((_) => _notifyAll());
      _playSub = _playerService.playingStream.listen((_) => _notifyAll());
      
      _notifyAll();
      
      Future.delayed(const Duration(seconds: 1), _notifyAll);
    } catch (e) {
      print('MPRIS registration error: $e');
    }
  }

  void _notifyAll() {
    final track = _playerService.currentTrack;
    final isPlaying = _playerService.playing;
    
    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {
        'PlaybackStatus': DBusString(isPlaying ? 'Playing' : 'Paused'),
        'Metadata': _getMetadataDict(track),
      },
    );
  }

  DBusValue _getMetadataDict(AppTrack? track) {
    if (track == null) {
      return DBusDict.stringVariant({
        'mpris:trackid': DBusObjectPath('/org/mpris/MediaPlayer2/Track/0'),
      });
    }
    return DBusDict.stringVariant({
      'mpris:trackid': DBusObjectPath('/org/mpris/MediaPlayer2/Track/${track.id.hashCode.abs()}'),
      'xesam:title': DBusString(track.title),
      'xesam:artist': DBusArray.string([track.artistName]),
      'xesam:album': DBusString('lizaplayer'),
      'xesam:albumArtist': DBusArray.string([track.artistName]),
      'mpris:artUrl': DBusString(track.coverUrl),
      'mpris:length': DBusInt64(track.duration?.inMicroseconds ?? 0),
    });
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface('org.mpris.MediaPlayer2',
          methods: [
            DBusIntrospectMethod('Raise'),
            DBusIntrospectMethod('Quit'),
          ],
          properties: [
            DBusIntrospectProperty('CanQuit', DBusSignature('b'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('CanRaise', DBusSignature('b'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('HasTrackList', DBusSignature('b'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('Identity', DBusSignature('s'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('DesktopEntry', DBusSignature('s'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('SupportedUriSchemes', DBusSignature('as'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('SupportedMimeTypes', DBusSignature('as'), access: DBusPropertyAccess.read),
          ]),
      DBusIntrospectInterface('org.mpris.MediaPlayer2.Player',
          methods: [
            DBusIntrospectMethod('Next'),
            DBusIntrospectMethod('Previous'),
            DBusIntrospectMethod('Pause'),
            DBusIntrospectMethod('PlayPause'),
            DBusIntrospectMethod('Stop'),
            DBusIntrospectMethod('Play'),
            DBusIntrospectMethod('Seek', args: [DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_, name: 'Offset')]),
            DBusIntrospectMethod('SetPosition', args: [
              DBusIntrospectArgument(DBusSignature('o'), DBusArgumentDirection.in_, name: 'TrackId'),
              DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_, name: 'Position')
            ]),
          ],
          properties: [
            DBusIntrospectProperty('PlaybackStatus', DBusSignature('s'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('Metadata', DBusSignature('a{sv}'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('Volume', DBusSignature('d'), access: DBusPropertyAccess.readwrite),
            DBusIntrospectProperty('Position', DBusSignature('x'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('Rate', DBusSignature('d'), access: DBusPropertyAccess.readwrite),
            DBusIntrospectProperty('CanGoNext', DBusSignature('b'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('CanGoPrevious', DBusSignature('b'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('CanPlay', DBusSignature('b'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('CanPause', DBusSignature('b'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('CanSeek', DBusSignature('b'), access: DBusPropertyAccess.read),
            DBusIntrospectProperty('CanControl', DBusSignature('b'), access: DBusPropertyAccess.read),
          ]),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.mpris.MediaPlayer2') {
      if (methodCall.name == 'Raise') return DBusMethodSuccessResponse([]);
      if (methodCall.name == 'Quit') { exit(0); }
    }
    
    if (methodCall.interface == 'org.mpris.MediaPlayer2.Player') {
      if (methodCall.name == 'Next') { _playerService.next(); return DBusMethodSuccessResponse([]); }
      if (methodCall.name == 'Previous') { _playerService.previous(); return DBusMethodSuccessResponse([]); }
      if (methodCall.name == 'Pause') { _playerService.pause(); return DBusMethodSuccessResponse([]); }
      if (methodCall.name == 'PlayPause') {
        if (_playerService.playing) { _playerService.pause(); } else { _playerService.play(); }
        return DBusMethodSuccessResponse([]);
      }
      if (methodCall.name == 'Stop') { _playerService.stop(); return DBusMethodSuccessResponse([]); }
      if (methodCall.name == 'Play') { _playerService.play(); return DBusMethodSuccessResponse([]); }
      if (methodCall.name == 'Seek') {
        final offset = (methodCall.values[0] as DBusInt64).value;
        _playerService.seek(Duration(microseconds: _playerService.position.inMicroseconds + offset));
        return DBusMethodSuccessResponse([]);
      }
    }
    return DBusMethodErrorResponse('org.freedesktop.DBus.Error.UnknownMethod', []);
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      if (name == 'Identity') return DBusGetPropertyResponse(DBusString('lizaplayer'));
      if (name == 'DesktopEntry') return DBusGetPropertyResponse(DBusString('lizaplayer'));
      if (name == 'CanQuit') return DBusGetPropertyResponse(DBusBoolean(true));
      if (name == 'CanRaise') return DBusGetPropertyResponse(DBusBoolean(true));
      if (name == 'HasTrackList') return DBusGetPropertyResponse(DBusBoolean(false));
      if (name == 'SupportedUriSchemes') return DBusGetPropertyResponse(DBusArray.string([]));
      if (name == 'SupportedMimeTypes') return DBusGetPropertyResponse(DBusArray.string([]));
    } else if (interface == 'org.mpris.MediaPlayer2.Player') {
      if (name == 'PlaybackStatus') return DBusGetPropertyResponse(DBusString(_playerService.playing ? 'Playing' : 'Paused'));
      if (name == 'Metadata') return DBusGetPropertyResponse(_getMetadataDict(_playerService.currentTrack));
      if (name == 'Volume') return DBusGetPropertyResponse(DBusDouble(_playerService.volume));
      if (name == 'Position') return DBusGetPropertyResponse(DBusInt64(_playerService.position.inMicroseconds));
      if (name == 'Rate') return DBusGetPropertyResponse(DBusDouble(1.0));
      if (name == 'CanGoNext') return DBusGetPropertyResponse(DBusBoolean(true));
      if (name == 'CanGoPrevious') return DBusGetPropertyResponse(DBusBoolean(true));
      if (name == 'CanPlay') return DBusGetPropertyResponse(DBusBoolean(true));
      if (name == 'CanPause') return DBusGetPropertyResponse(DBusBoolean(true));
      if (name == 'CanSeek') return DBusGetPropertyResponse(DBusBoolean(true));
      if (name == 'CanControl') return DBusGetPropertyResponse(DBusBoolean(true));
    }
    return DBusMethodErrorResponse('org.freedesktop.DBus.Error.UnknownProperty', []);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      return DBusGetAllPropertiesResponse({
        'CanQuit': DBusBoolean(true),
        'CanRaise': DBusBoolean(true),
        'HasTrackList': DBusBoolean(false),
        'DesktopEntry': DBusString('lizaplayer'),
        'Identity': DBusString('lizaplayer'),
        'SupportedUriSchemes': DBusArray.string([]),
        'SupportedMimeTypes': DBusArray.string([]),
      });
    } else if (interface == 'org.mpris.MediaPlayer2.Player') {
      return DBusGetAllPropertiesResponse({
        'PlaybackStatus': DBusString(_playerService.playing ? 'Playing' : 'Paused'),
        'Metadata': _getMetadataDict(_playerService.currentTrack),
        'Volume': DBusDouble(_playerService.volume),
        'Position': DBusInt64(_playerService.position.inMicroseconds),
        'MinimumRate': DBusDouble(1.0),
        'MaximumRate': DBusDouble(1.0),
        'Rate': DBusDouble(1.0),
        'CanGoNext': DBusBoolean(true),
        'CanGoPrevious': DBusBoolean(true),
        'CanPlay': DBusBoolean(true),
        'CanPause': DBusBoolean(true),
        'CanSeek': DBusBoolean(true),
        'CanControl': DBusBoolean(true),
      });
    }
    return DBusGetAllPropertiesResponse({});
  }

  void dispose() {
    _trackSub?.cancel();
    _playSub?.cancel();
    _client?.close();
  }
}
