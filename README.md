# GPS Frontière - Izway

Application de navigation GPS intelligente spécialisée dans les trajets transfrontaliers, le signalement communautaire et la détection de radars.

## 🚀 Fonctionnalités Clés

- **Navigation Temps Réel** : Itinéraires précis via le moteur Valhalla.
- **Alertes Communautaires** : Signalez et recevez des alertes pour la police, les accidents et les radars.
- **Passages de Frontières** : Détection automatique des frontières avec calcul de distance et affichage du drapeau du pays suivant.
- **Limitations de Vitesse** : Affichage dynamique des limitations de vitesse basées sur les données OpenStreetMap.
- **Trafic en Temps Réel** : Couche de trafic MapTiler intégrée.
- **Mode Social** : Visualisez les autres utilisateurs ("Peers") sur la carte en temps réel.

## 🛠 Architecture Technique

Le projet suit une structure modulaire pour séparer la logique métier de l'interface utilisateur.

### Structure des Dossiers (`lib/`)

- **`main.dart`** : Point d'entrée de l'application et configuration globale.
- **`models/`** : Définitions des structures de données.
  - `alert.dart` : Modèles pour les alertes (Radars, Accidents, Police).
  - `route_models.dart` : Structures pour les trajets, étapes et infos de routage.
- **`services/`** : Cœur logique de l'application (Business Logic).
  - `route_service.dart` : Calcul d'itinéraires et parsing des données Valhalla.
  - `traffic_service.dart` : Récupération des radars via Overpass API.
  - `location_service.dart` : Gestion fine du GPS et calculs de distances.
  - `speed_limit_service.dart` : Recherche temps réel des limitations de vitesse.
  - `alert_service.dart` : Gestion de la persistance des alertes et des votes.
  - `user_service.dart` : Synchronisation des positions entre utilisateurs.
- **`widgets/`** : Composants graphiques réutilisables.
  - `navigation/` : Dashboard de bord, bannières d'instructions et widget de vitesse.
  - `routes/` : Sélecteur d'itinéraire et résumés de trajet.
  - `search/` : Barre de recherche et résultats.
- **`screens/`** :
  - `map_screen.dart` : Écran principal regroupant la carte et la coordination des services.

## 🌐 APIs et Technologies

L'application s'appuie sur un écosystème de services open-source et premium :

- **Framework** : [Flutter](https://flutter.dev) (Dart)
- **Cartographie** :
  - [flutter_map](https://pub.dev/packages/flutter_map) : Moteur d'affichage basé sur Leaflet.
  - [MapTiler](https://www.maptiler.com/) : Fond de carte (Vector Tiles), couches de trafic et API de recherche (Geocoding).
- **Moteur de Routage** : [Valhalla](https://valhalla.github.io/valhalla/) : Calcul des trajectoires et détection des attributs de route (frontières, pays).
- **Données Géographiques** : [Overpass API](https://overpass-api.de/) : Extraction dynamique des radars et des limitations de vitesse depuis OpenStreetMap.
- **Backend** : Serveur PHP/SQL sur mesure pour la gestion des alertes communautaires et la synchronisation des pairs.

## 📦 Installation et Lancement

1.  Assurez-vous d'avoir Flutter installé (`flutter doctor`).
2.  Clonez le dépôt.
3.  Installez les dépendances :
    ```bash
    flutter pub get
    ```
4.  Lancez l'application :
    ```bash
    flutter run
    ```

## 📝 Configuration

Les clés API (MapTiler, Overpass) sont configurées dans les fichiers de services correspondants. Pour MapTiler, vérifiez la constante `_mapTilerKey` dans `map_screen.dart`.
