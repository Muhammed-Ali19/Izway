# 🌍 GPS Izway

C'est une application Flutter de navigation par GPS imaginée et conçue pour simplifier la vie des conducteurs. L'application recalcule les itinéraires, récupère le temps d'attente et propose un guidage vocal 100% natif.

---

## 🚀 Fonctionnalités

- **Navigation GPS Temps Réel :** Carte claire, fluide, centrée sur le véhicule.
- **Routage Intelligent :** Calcul du trajet le plus rapide (moteur Valhalla) en détectant le passage exact de la frontière.
- **Temps d'Attente Douaniers :** Récupération de l'attente en temps réel sur les douanes
- **Signalements :** Comme sur Waze, on peut signaler la police, un accident ou un danger, avec une logique de validation par les autres utilisateurs.
- **Guidage Vocal (TTS) :** Instructions vocales utilisant les voix natives du navigateur ou téléphone. Un travail spécifique a été fait pour garantir son fonctionnement en arrière-plan et sur PWA iOS.
- **Limites de Vitesse :** Indication de la vitesse actuelle autorisée et alertes de dépassement.
- **Multi-plateformes :** Compilable en application mobile iOS/Android, mais aussi et surtout en **Web App (PWA)** pour être utilisée sans aucune installation via une simple URL.
- **Analyse du traffic:** Récupération du traffic en temps réel

---

## 🏗️ Architecture du Projet

Le projet suit une architecture claire organisée par dossiers dans `lib/` :

```text
lib/
├── main.dart       # Point d'entrée de l'application
├── models/         # Modèles de données (Itinéraires, Alertes)
├── screens/        # Les pages principales (ex: la Carte)
├── services/       # La logique métier et les appels API (GPS, Serveur, Voix)
├── utils/          # Configurations globales (Clés API, URLs)
└── widgets/        # Composants graphiques réutilisables (Boutons, Menus)
```

---

## 🔌 API & Back-end Utilisés

- **Proxy Back-end (PHP) :** Relais sur `api.php`. Contourne les problèmes de CORS sur le Web et sert de base de données pour les alertes.
- **Valhalla (Mapbox/OSM) :** Notre moteur pour tracer la route et donner les instructions gauche/droite.
- **Nominatim / Photon :** La barre de recherche pour trouver une adresse.
- **Waze API (Scraping) :** Pour récupérer le trafic et les temps d'attente à la douane.
- **Overpass API :** En cas de doute sur la route, on vient récupérer la vraie limite de vitesse `maxspeed` de la rue actuelle.

---

## 🛠️ Guide de Développement (Mise en place locale)

Si vous souhaitez modifier le code ou la tester en local, voici comment faire :

1. Prenez le code source et téléchargez les paquets :
```bash
git clone https://github.com/Muhammed-Ali19/Izway.git
cd gps_frontiere
flutter pub get
```

2. Lancez le "Proxy" PHP (nécessaire pour que le web contourne les blocages de sécurité) :
```bash
php -S 0.0.0.0:8001 -t backend
```

3. Dans un autre terminal, lancez Flutter sur Chrome :
```bash
flutter run -d chrome
```
Attention, sur un Pc la navigation ne fonctionne pas, il faut utiliser un téléphone ! 

---

## 📱 Utilisation Publique 

Le projet est entièrement terminé, compilé et prêt à l'emploi. Vous pouvez l'utiliser directement comme n'importe quelle application !

👉 **Lien d'accès : [https://muhammed-ali.fr/web](https://muhammed-ali.fr/web)**

**Astuce très fortement conseillée :** Installez-la sur votre téléphone pour un vrai confort d'utilisation (elle se comportera comme une vraie application sans utiliser le stockage classique).

### L'installer sur iPhone (iOS)
1. Ouvrez le lien sur Safari.
2. Cliquez sur le bouton "Partager" (le carré avec une flèche qui monte en bas de l'écran).
3. Sélectionnez **"Sur l'écran d'accueil"** (ou "Ajouter à l'écran d'accueil").
4. C'est tout ! L'icône du GPS est sur votre téléphone.

### L'installer sur Android
1. Ouvrez le lien sur Chrome.
2. Appuyez sur les trois petits points (ou trois barres horizontales) du menu en bas à droite ou en haut à droite.
3. Sélectionnez **"Ajouter la page à l'écran d'accueil"** ou "Installer l'application".
4. Confirmez. Elle est maintenant installée !
