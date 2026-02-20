import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/api_config.dart';

class AzureTtsService {
  static final AzureTtsService _instance = AzureTtsService._internal();
  factory AzureTtsService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();

  AzureTtsService._internal();

  /// Génère et joue de l'audio via l'API Azure Neural TTS
  /// Voix recommandées : fr-FR-DeniseNeural, fr-FR-HenriNeural, fr-FR-EloiseNeural
  Future<bool> speak(String text, {String voice = 'fr-FR-DeniseNeural'}) async {
    if (ApiConfig.azureKey.isEmpty) {
      debugPrint("Azure TTS : Clé API absente.");
      return false;
    }

    final String url = "https://${ApiConfig.azureRegion}.tts.speech.microsoft.com/cognitiveservices/v1";

    // SSML requis pour une qualité optimale avec Azure
    final String ssml = """
<speak version='1.0' xml:lang='fr-FR'>
  <voice xml:lang='fr-FR' xml:gender='Female' name='$voice'>
    <prosody rate='0%' pitch='0%'>
      $text
    </prosody>
  </voice>
</speak>""";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Ocp-Apim-Subscription-Key": ApiConfig.azureKey,
          "Content-Type": "application/ssml+xml",
          "X-Microsoft-OutputFormat": "audio-16khz-128kbitrate-mono-mp3",
          "User-Agent": "GPS_Frontiere"
        },
        body: ssml,
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await _audioPlayer.play(BytesSource(bytes));
        return true;
      } else {
        debugPrint("Erreur Azure TTS : ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Erreur lors de l'appel Azure TTS : $e");
      return false;
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
