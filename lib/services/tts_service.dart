import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService I = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> speak(String text) async {
    await init();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
