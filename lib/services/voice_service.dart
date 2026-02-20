import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'voicerss_service.dart';
import 'azure_tts_service.dart';
import '../utils/api_config.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  final VoiceRssService _voiceRssService = VoiceRssService();
  final AzureTtsService _azureTtsService = AzureTtsService();
  bool _isInitialized = false;

  VoiceService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9);

    try {
      final voices = await _flutterTts.getVoices;
      for (var voice in voices) {
        String name = voice["name"].toString().toLowerCase();
        String locale = voice["locale"].toString().toLowerCase();
        
        if (locale.contains("fr") && 
            (name.contains("google") || name.contains("wavenet") || name.contains("siri") || name.contains("natural") || name.contains("premium"))) {
          await _flutterTts.setVoice({"name": voice["name"], "locale": voice["locale"]});
          break;
        }
      }
    } catch (e) {
      debugPrint("Erreur d'initialisation voix : $e");
    }

    if (!kIsWeb) {
      if (Platform.isIOS) {
        // GESTION DU SON : Baisse la musique pendant le guidage
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.duckOthers,
              IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
              IosTextToSpeechAudioCategoryOptions.allowBluetooth
            ],
            IosTextToSpeechAudioMode.voicePrompt
        );
      }
    }

    _isInitialized = true;
  }

  // Synthèse vocale avec fallback intelligent
  Future<void> speakNatural(String text) async {
    if (!_isInitialized) await _initTts();
    if (text.isEmpty) return;

    // 1. Essayer Azure (Premium)
    if (ApiConfig.azureKey.isNotEmpty) {
      bool success = await _azureTtsService.speak(text);
      if (success) return;
    }

    // 2. Essayer VoiceRSS (Standard)
    if (ApiConfig.voiceRssKey.isNotEmpty) {
      String cloudText = text
        .replaceAll(RegExp(r'<break time="\d+ms"/>'), ", ")
        .replaceAll("Dans ", "Dans... ")
        .replaceAll("Tournez ", "tournez ")
        .replaceAll("Prenez ", "prenez ");
      
      bool success = await _voiceRssService.speak(cloudText, voice: 'Celine', rate: -1);
      if (success) return;
    }

    // 3. Fallback système (Local)
    String processed = text;
    if (!processed.contains("<break")) {
      processed = processed
        .replaceAll("Dans ", "Dans <break time=\"100ms\"/> ")
        .replaceAll(" mètres", " mètres <break time=\"200ms\"/> ")
        .replaceAll(" kilomètres", " kilomètres <break time=\"200ms\"/> ")
        .replaceAll("tournez ", "<break time=\"50ms\"/> tournez ")
        .replaceAll("Prenez ", "<break time=\"50ms\"/> Prenez ");
    }

    // Simulation SSML pour le moteur système
    final parts = processed.split(RegExp(r'<break time="(\d+)ms"/>'));
    final matches = RegExp(r'<break time="(\d+)ms"/>').allMatches(processed).toList();

    for (int i = 0; i < parts.length; i++) {
        String part = parts[i].replaceAll(RegExp(r'<[^>]*>'), "").trim();
        if (part.isNotEmpty) {
          await _flutterTts.speak(part);
        }
        
        if (i < matches.length) {
          int duration = int.parse(matches[i].group(1)!);
          await Future.delayed(Duration(milliseconds: duration));
        }
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await _initTts();
    if (text.isEmpty) return;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    await _azureTtsService.stop();
  }
}
