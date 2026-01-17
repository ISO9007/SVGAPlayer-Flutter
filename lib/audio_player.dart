import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_soloud/flutter_soloud.dart' as soloud;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:svgaplayer_flutter/until/log.dart';

import 'proto/svga.pb.dart';


abstract class SVGAAudioLayer {

  factory SVGAAudioLayer(AudioEntity audioItem, MovieEntity videoItem) {
    if (Platform.isIOS) {
      return _SVGAAudioIosLayer(audioItem, videoItem);
    }else {
      return _SVGAAudioLayer(audioItem, videoItem);
    }
  }

  bool get isPlaying;
  AudioEntity get audioItem;
  MovieEntity get videoItem;
  void playAudio();
  void stopAudio();
  Future<void> dispose();
}
extension SVGAAudioInit on SVGAAudioLayer {
  static Future<void> initAudioEngine() async {
    if (!Platform.isIOS) {
      await _SVGAAudioLayer.initSoLoud();
    }
  }
}

class _SVGAAudioIosLayer implements SVGAAudioLayer  {
  final ap.AudioPlayer _player = ap.AudioPlayer();

  bool _isPlaying = false;
  final AudioEntity _audioItem;
  final MovieEntity _videoItem;
  bool _isSetSource = false;
  bool _disposed = false;

  _SVGAAudioIosLayer(this._audioItem, this._videoItem) {
    final bytesData = _videoItem.audiosData[audioItem.audioKey];
    if (bytesData == null) {
      _isSetSource = false;
      return;
    }
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
    });
    try {
      _player.setSourceBytes(bytesData, mimeType: 'audio/mpeg').then((_) async {
        await _player.setPlayerMode(ap.PlayerMode.lowLatency);
        _isSetSource = true;
      });
    }catch (e) {
      _isSetSource = false;
      kkPrint('初始化失败: $e');
    }

  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  AudioEntity get audioItem => _audioItem;

  @override
  MovieEntity get videoItem => _videoItem;

  @override
  void playAudio() {
    if (_isPlaying) {
      return;
    }
    _isPlaying = true;
    if (!_isSetSource) {
      _isPlaying = false;
      kkPrint('播放1, $isPlaying');
      return;
    }
    try {
      kkPrint('播放2, $isPlaying');
      _player.seek(Duration(milliseconds: _audioItem.startTime.toInt())).then((_) {
        _player.resume();
      });
    } catch (e) {
      _isPlaying = false;
      kkPrint('Failed to play audio: $e');
    }
  }

  @override
  void stopAudio() {
    kkPrint('停止播放');
    if (_disposed) return;
    if (isPlaying) {
      _isPlaying = false;
      Future.delayed(Duration(milliseconds: audioItem.totalTime <= 500 ? 100 : 0), (){
        _player.pause();
      });
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (isPlaying) {
      await _player.stop();
    }
    await _player.dispose();
  }
}

class _SVGAAudioLayer implements SVGAAudioLayer {

  final AudioEntity _audioItem;
  final MovieEntity _videoItem;
  bool _isPlaying = false;
  soloud.AudioSource? _source;
  soloud.SoundHandle? _handle;

  _SVGAAudioLayer(this._audioItem, this._videoItem) {
    final audioData = _videoItem.audiosData[audioItem.audioKey];
    if (audioData == null) return;
    final audioHash = md5.convert(audioData).toString();
    final soLoud = soLoudInstance;
    try {
      soLoud.loadMem(
          '$audioHash.mp3',
          audioData,
          mode: soloud.LoadMode.disk
      ).then((s) async {
        _source = s;
      });
    }catch (e) {
      kkPrint('初始化音频失败: $e');
    }
  }

  static Future<void> initSoLoud() async {
    if (!soloud.SoLoud.instance.isInitialized) {
      await soloud.SoLoud.instance.init();
    }
  }

  static soloud.SoLoud get soLoudInstance {
    if (!soloud.SoLoud.instance.isInitialized) {
      soloud.SoLoud.instance.init();
    }
    return soloud.SoLoud.instance;
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  AudioEntity get audioItem => _audioItem;

  @override
  MovieEntity get videoItem => _videoItem;

  @override
  Future<void> playAudio() async {
    if (_isPlaying) {
      return;
    }
    _isPlaying = true;
    final soLoud = soLoudInstance;
    final audioData = _videoItem.audiosData[audioItem.audioKey];
    if (audioData == null) return;
    if (_source == null) {
      _isPlaying = false;
      return;
    }
    try {
      _handle = await soLoud.play(_source!);
      soLoud.seek(_handle!, Duration(milliseconds: audioItem.startTime.toInt()));
    }catch (e) {
      stopAudio();
      kkPrint('播放失败: $e');
    }
  }

  @override
  Future<void> stopAudio() async {
    if (_handle == null) return;
    final soLoud = soLoudInstance;
    if (!isPlaying) return;
    try {
      final stopHandle = _handle!;
      _handle = null;
      if (isPlaying) {
        _isPlaying = false;
      }
      await soLoud.stop(stopHandle);
    }catch (e) {
      kkPrint('SoLoud错误: $e');
    }
  }

  @override
  Future<void> dispose() async {
    stopAudio();
    if (_source == null) return;
    final dispostSource = _source;
    _source = null;
    final soLoud = soLoudInstance;
    await soLoud.disposeSource(dispostSource!);
  }

}
