class DirectionTranslator {
  static String translate(String instruction) {
    if (instruction.isEmpty) return "";

    String result = instruction;

    // Mapping patterns (Regex based for better matching with street names)
    final Map<RegExp, String> patterns = {
      // Directions & Starts
      RegExp(r"(Head|Drive|Go|Take) ([a-z\s\-]+) on (.*)", caseSensitive: false): "Suivez {3} vers le {2}",
      RegExp(r"(Head|Drive|Go|Take) ([a-z\s\-]+) towards (.*)", caseSensitive: false): "Allez vers {3} en direction {2}",
      RegExp(r"(Head|Drive|Go|Take) ([a-z\s\-]+) (.*)", caseSensitive: false): "Allez vers {2} {3}",
      RegExp(r"(Head|Drive|Go|Take) ([a-z\s\-]+)", caseSensitive: false): "Allez vers {2}",
      
      // Basic moves
      RegExp(r"Drive on (.*)", caseSensitive: false): "Restez sur {1}",
      RegExp(r"Continue on (.*)", caseSensitive: false): "Continuez tout droit sur {1}",
      
      // Turns
      RegExp(r"Turn right onto (.*)", caseSensitive: false): "Tournez à droite sur {1}",
      RegExp(r"Turn left onto (.*)", caseSensitive: false): "Tournez à gauche sur {1}",
      RegExp(r"Slight right onto (.*)", caseSensitive: false): "Légèrement à droite sur {1}",
      RegExp(r"Slight left onto (.*)", caseSensitive: false): "Légèrement à gauche sur {1}",
      RegExp(r"Sharp right onto (.*)", caseSensitive: false): "Tournez franchement à droite sur {1}",
      RegExp(r"Sharp left onto (.*)", caseSensitive: false): "Tournez franchement à gauche sur {1}",
      
      // Keep/Merge
      RegExp(r"Continue onto (.*)", caseSensitive: false): "Continuez sur {1}",
      RegExp(r"Keep right onto (.*)", caseSensitive: false): "Serrez à droite sur {1}",
      RegExp(r"Keep left onto (.*)", caseSensitive: false): "Serrez à gauche sur {1}",
      RegExp(r"Merge onto (.*)", caseSensitive: false): "Rejoignez {1}",
      RegExp(r"Take the ramp onto (.*)", caseSensitive: false): "Prenez la bretelle vers {1}",
      
      // Roundabouts
      RegExp(r"At the roundabout, take the (.*) exit onto (.*)", caseSensitive: false): "Au rond-point, {1} sortie sur {2}",
      RegExp(r"At the roundabout, take the (.*) exit", caseSensitive: false): "Au rond-point, {1} sortie",
      
      // Destination
      RegExp(r"Your destination is on the (.*)", caseSensitive: false): "Votre destination est à {1}",
      RegExp(r"You have arrived at your destination(.*)", caseSensitive: false): "Vous êtes arrivé",
    };

    for (var entry in patterns.entries) {
      final match = entry.key.firstMatch(result);
      if (match != null) {
        String template = entry.value;
        for (int i = 1; i <= match.groupCount; i++) {
          String val = match.group(i) ?? "";
          // Translation for specific words within groups
          val = _translateTerms(val);
          template = template.replaceAll("{$i}", val);
        }
        return template;
      }
    }

    // Default fallbacks for common standalone words if no regex matched
    return _translateTerms(result);
  }

  static String _translateTerms(String text) {
    String lower = text.toLowerCase().trim();
    
    // Numbers/Exits
    if (lower == "first") return "première";
    if (lower == "second") return "deuxième";
    if (lower == "third") return "troisième";
    if (lower == "fourth") return "quatrième";
    if (lower == "fifth") return "cinquième";
    if (lower == "sixth") return "sixième";
    
    // Directions
    if (lower == "right") return "droite";
    if (lower == "left") return "gauche";
    if (lower == "north") return "nord";
    if (lower == "south") return "sud";
    if (lower == "east") return "est";
    if (lower == "west") return "ouest";
    if (lower == "northwest") return "nord-ouest";
    if (lower == "northeast") return "nord-est";
    if (lower == "southwest") return "sud-ouest";
    if (lower == "southeast") return "sud-est";
    
    // Verbs
    if (lower == "head") return "Dirigez-vous";
    if (lower == "drive") return "Suivez";
    if (lower == "go") return "Allez";
    
    return text;
  }
}
