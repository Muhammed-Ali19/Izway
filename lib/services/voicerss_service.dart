import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/api_config.dart';

class VoiceRssService {
  static final VoiceRssService _instance = VoiceRssService._internal();
  factory VoiceRssService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();

  VoiceRssService._internal();

  /// Génère et joue de l'audio via l'API VoiceRSS
  /// Voix recommandée : Celine (plus naturelle)
  Future<bool> speak(String text, {double rate = 0, String voice = 'Celine'}) async {
    if (ApiConfig.voiceRssKey.isEmpty) {
      debugPrint("VoiceRSS : Clé API absente.");
      return false;
    }

    // hl: langue (fr-fr), v: voix, r: vitesse (-10 à 10)
    final String url = "https://api.voicerss.org/?key=${ApiConfig.voiceRssKey}&hl=fr-fr&v=$voice&r=${rate.toInt()}&src=${Uri.encodeComponent(text)}&f=44khz_16bit_stereo";

    try {
      await _audioPlayer.play(UrlSource(url));
      return true;
    } catch (e) {
      debugPrint("Erreur VoiceRSS : $e");
      return false;
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
