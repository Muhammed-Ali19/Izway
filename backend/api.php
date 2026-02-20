<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Configuration Database
if (file_exists(__DIR__ . '/config.local.php')) {
    include(__DIR__ . '/config.local.php');
} else {
    // Default or Production environment variables
    $host = getenv('DB_HOST') ?: 'localhost';
    $db   = getenv('DB_NAME') ?: 'gps_app';
    $user = getenv('DB_USER') ?: 'root';
    $pass = getenv('DB_PASS') ?: '';
    $charset = 'utf8mb4';
}

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

// Defer Database Connection
$pdo = null;
$dbError = null;

function getDb() {
    global $pdo, $dbError, $host, $db, $user, $pass, $charset, $options;
    if ($pdo !== null) return $pdo;
    
    try {
        $dsn = "mysql:host=$host;dbname=$db;charset=$charset";
        $pdo = new PDO($dsn, $user, $pass, $options);
        
        // Nettoyage automatique (1 chance sur 10)
        if (rand(1, 10) === 1) { 
            $pdo->exec("DELETE FROM alerts WHERE timestamp < DATE_SUB(NOW(), INTERVAL 2 HOUR)");
            $pdo->exec("DELETE FROM user_positions WHERE last_seen < DATE_SUB(NOW(), INTERVAL 5 MINUTE)");
        }
        return $pdo;
    } catch (\PDOException $e) {
        $dbError = $e->getMessage();
        return null;
    }
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $db = getDb();
    if (!$db) {
        // Renvoie une liste vide au lieu d'une erreur 503 si DB en panne
        die(json_encode([]));
    }
    try {
        // Récupérer alertes récentes
        $query = "SELECT * FROM alerts WHERE timestamp > DATE_SUB(NOW(), INTERVAL 2 HOUR) AND (upvotes - downvotes) > -3 ORDER BY timestamp DESC";
        $stmt = $db->query($query);
        die(json_encode($stmt->fetchAll()));
    } catch (Exception $e) {
        http_response_code(500);
        die(json_encode(["error" => $e->getMessage()]));
    }
} 
elseif ($method === 'POST') {
    $rawInput = file_get_contents('php://input');
    $input = json_decode($rawInput, true);
    

    if (!$input) {
        http_response_code(400);
        die(json_encode(["error" => "JSON invalide", "raw" => file_get_contents('php://input')]));
    }

    $action = isset($input['action']) ? $input['action'] : 'create_alert';

    switch ($action) {
        case 'vote':
            $db = getDb();
            if (!$db) { http_response_code(503); die(json_encode(["error" => "Indisponible: $dbError"])); }
            if (!isset($input['id']) || !isset($input['type'])) {
                http_response_code(400);
                die(json_encode(["error" => "ID ou type manquant"]));
            }
            $column = ($input['type'] === 'up') ? 'upvotes' : 'downvotes';
            $stmt = $db->prepare("UPDATE alerts SET $column = $column + 1 WHERE id = ?");
            $stmt->execute([$input['id']]);
            die(json_encode(["success" => true]));

        case 'update_position':
            $db = getDb();
            if (!$db) { http_response_code(503); die(json_encode(["error" => "Indisponible: $dbError"])); }
            if (!isset($input['user_id']) || !isset($input['latitude']) || !isset($input['longitude'])) {
                http_response_code(400);
                die(json_encode(["error" => "Données position manquantes"]));
            }
            $stmt = $db->prepare("INSERT INTO user_positions (user_id, latitude, longitude) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE latitude = VALUES(latitude), longitude = VALUES(longitude), last_seen = NOW()");
            $stmt->execute([$input['user_id'], $input['latitude'], $input['longitude']]);
            
            $stmt = $db->prepare("SELECT user_id, latitude, longitude FROM user_positions WHERE user_id != ? AND last_seen > DATE_SUB(NOW(), INTERVAL 5 MINUTE)");
            $stmt->execute([$input['user_id']]);
            die(json_encode($stmt->fetchAll()));

        case 'delete':
        case 'delete_alert':
            $db = getDb();
            if (!$db) { http_response_code(503); die(json_encode(["error" => "Indisponible: $dbError"])); }
            if (!isset($input['id'])) {
                http_response_code(400);
                die(json_encode(["error" => "ID manquant (reçu: " . json_encode($input) . ")"]));
            }
            $stmt = $db->prepare("DELETE FROM alerts WHERE id = ?");
            $success = $stmt->execute([$input['id']]);
            $count = $stmt->rowCount();
            die(json_encode([
                "success" => $success, 
                "deleted_count" => $count,
                "id" => $input['id']
            ]));

        case 'search_proxy':
            $query = $input['query'];
            $url = "https://nominatim.openstreetmap.org/search?q=" . urlencode($query) . "&format=json&limit=10&addressdetails=1";
            if (isset($input['viewbox'])) {
                $url .= "&viewbox=" . $input['viewbox'];
            }
            
            $ch = curl_init($url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'User-Agent: GPSFrontiere/3.1 (contact: alihirlak@gps-frontiere.com)',
                'Referer: https://gps-frontiere.alihirlak.com/',
                'Accept: application/json'
            ]);
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            // Fallback vers Photon si Nominatim bloque (418, 429, etc.)
            if ($httpCode !== 200 || empty($response) || $response === '[]') {
                $photonUrl = "https://photon.komoot.io/api/?q=" . urlencode($query) . "&limit=10";
                $ch2 = curl_init($photonUrl);
                curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch2, CURLOPT_HTTPHEADER, ['User-Agent: GPSFrontiere/3.1']);
                $photonRes = curl_exec($ch2);
                curl_close($ch2);
                
                if (!empty($photonRes)) {
                    $pData = json_decode($photonRes, true);
                    $results = [];
                    if (isset($pData['features'])) {
                        foreach ($pData['features'] as $f) {
                            $props = $f['properties'];
                            $results[] = [
                                'lat' => $f['geometry']['coordinates'][1],
                                'lon' => $f['geometry']['coordinates'][0],
                                'display_name' => ($props['name'] ?? '') . ", " . ($props['city'] ?? $props['state'] ?? '') . " " . ($props['country'] ?? ''),
                                'address' => [
                                    'road' => $props['street'] ?? $props['name'] ?? '',
                                    'city' => $props['city'] ?? '',
                                    'country' => $props['country'] ?? ''
                                ]
                            ];
                        }
                    }
                    die(json_encode($results));
                }
            }
            die($response);

        case 'reverse_proxy':
            $lat = $input['lat'];
            $lon = $input['lon'];
            $url = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10";
            $ch = curl_init($url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Referer: https://gps-frontiere.alihirlak.com/'
            ]);
            $response = curl_exec($ch);
            curl_close($ch);
            die($response);

        case 'route_proxy':
            $valhallaUrl = 'https://valhalla1.openstreetmap.de/route';
            $ch = curl_init($valhallaUrl);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($input['payload']));
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json',
                'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            ]);
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            if (curl_errno($ch)) {
                error_log("Valhalla Proxy Error: " . curl_error($ch));
                http_response_code(500);
                die(json_encode(["error" => "Proxy Error: " . curl_error($ch)]));
            }
            if ($httpCode !== 200) {
                error_log("Valhalla Error Code: $httpCode. Response: " . substr($response, 0, 500));
            }
            curl_close($ch);
            die($response);

        case 'get_border_wait':
            $lat = $input['lat'] ?? null;
            $lon = $input['lon'] ?? null;
            $name = $input['name'] ?? '';
            
            if (!$lat || !$lon) {
                die(json_encode(["wait" => null, "info" => "Coordonnées manquantes"]));
            }

            // Spécifique : Tunnel du Mont-Blanc
            // On vérifie le nom OU la proximité géographique (45.90, 6.85)
            $isMontBlanc = (strpos(strtolower($name), 'mont-blanc') !== false);
            if (!$isMontBlanc && abs($lat - 45.90) < 0.05 && abs($lon - 6.85) < 0.05) {
                $isMontBlanc = true;
            }

            if ($isMontBlanc) {
                // Tentative de récupération via ATMB ou TMB (Scraping léger)
                $url = "https://www.atmb.com/trafic-temps-reel/le-tunnel-du-mont-blanc";
                $ch = curl_init($url);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
                curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
                curl_setopt($ch, CURLOPT_TIMEOUT, 5);
                $html = curl_exec($ch);
                curl_close($ch);
                
                if ($html) {
                    // Chercher "attente" dans le texte (Flexible: min, mn, MN, minutes)
                    if (preg_match('/attente[^0-9]*([0-9]+)\s*(min|mn|minute)/i', $html, $matches)) {
                        die(json_encode([
                            "wait" => $matches[1] . "min",
                            "source" => "ATMB Live"
                        ]));
                    }
                    if (stripos($html, 'Trafic fluide') !== false) {
                        die(json_encode(["wait" => "Fluid", "source" => "ATMB Live"]));
                    }
                }
            }

            // Spécifique : Douane Suisse (St-Julien / Bardonnex)
            if (abs($lat - 46.15) < 0.05 && abs($lon - 6.10) < 0.05) {
                $delta = 0.04; // Zone plus large pour la douane
            } else {
                $delta = 0.08; // Par défaut
            }
            $bl_lat = $lat - $delta; $bl_lon = $lon - $delta;
            $tr_lat = $lat + $delta; $tr_lon = $lon + $delta;
            $wazeUrl = "https://www.waze.com/row-rtserver/webapp/v1/get-traffic-results?bottom_left=$bl_lat,$bl_lon&top_right=$tr_lat,$tr_lon&max_jams=5";
            
            $ch = curl_init($wazeUrl);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
            curl_setopt($ch, CURLOPT_REFERER, 'https://www.waze.com/live-map/');
            $response = curl_exec($ch);
            curl_close($ch);
            
            $data = json_decode($response, true);
            if (isset($data['jams']) && !empty($data['jams'])) {
                $maxDelay = 0;
                foreach ($data['jams'] as $jam) {
                    $delay = $jam['delay'] ?? 0;
                    if ($delay > $maxDelay) $maxDelay = $delay;
                }
                if ($maxDelay > 0) {
                    $minutes = round($maxDelay / 60);
                    die(json_encode([
                        "wait" => ($minutes > 0 ? $minutes : 1) . "min",
                        "source" => "Waze Community"
                    ]));
                }
            }

            die(json_encode(["wait" => "Fluid", "source" => "Default"]));

        case 'create_alert':
        default:
            $db = getDb();
            if (!$db) { 
                die(json_encode(["success" => false, "message" => "Base de données indisponible"])); 
            }
            if (!isset($input['type']) || !isset($input['latitude']) || !isset($input['longitude'])) {
                http_response_code(400);
                die(json_encode(["error" => "Données signalement manquantes", "received_action" => $action]));
            }
            $id = isset($input['id']) ? $input['id'] : uniqid('alert_');
            $stmt = $db->prepare("INSERT INTO alerts (id, type, latitude, longitude, description, user_id, upvotes, downvotes) 
                                 VALUES (?, ?, ?, ?, ?, ?, 0, 0)
                                 ON DUPLICATE KEY UPDATE type = VALUES(type), latitude = VALUES(latitude), longitude = VALUES(longitude), description = VALUES(description)");
            $stmt->execute([
                $id,
                $input['type'],
                $input['latitude'],
                $input['longitude'],
                $input['description'] ?? '',
                $input['user_id'] ?? 'anon'
            ]);
            die(json_encode(["success" => true, "id" => $id]));
    }
}
?>
