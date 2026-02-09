header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");

// Gestion du Preflight CORS
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

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
    
    // Nettoyage automatique (1 chance sur 10)
    if (rand(1, 10) === 1) { 
        $pdo->exec("DELETE FROM alerts WHERE timestamp < DATE_SUB(NOW(), INTERVAL 2 HOUR)");
        $pdo->exec("DELETE FROM user_positions WHERE last_seen < DATE_SUB(NOW(), INTERVAL 5 MINUTE)");
    }

} catch (\PDOException $e) {
    http_response_code(500);
    die(json_encode(["error" => "Erreur de connexion BDD: " . $e->getMessage()]));
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    try {
        // Récupérer alertes récentes
        $query = "SELECT * FROM alerts WHERE timestamp > DATE_SUB(NOW(), INTERVAL 2 HOUR) AND (upvotes - downvotes) > -3 ORDER BY timestamp DESC";
        $stmt = $pdo->query($query);
        die(json_encode($stmt->fetchAll()));
    } catch (Exception $e) {
        http_response_code(500);
        die(json_encode(["error" => $e->getMessage()]));
    }
} 
elseif ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        http_response_code(400);
        die(json_encode(["error" => "JSON invalide", "raw" => file_get_contents('php://input')]));
    }

    $action = isset($input['action']) ? $input['action'] : 'create_alert';

    switch ($action) {
        case 'vote':
            if (!isset($input['id']) || !isset($input['type'])) {
                http_response_code(400);
                die(json_encode(["error" => "ID ou type manquant"]));
            }
            $column = ($input['type'] === 'up') ? 'upvotes' : 'downvotes';
            $stmt = $pdo->prepare("UPDATE alerts SET $column = $column + 1 WHERE id = ?");
            $stmt->execute([$input['id']]);
            die(json_encode(["success" => true]));

        case 'update_position':
            if (!isset($input['user_id']) || !isset($input['latitude']) || !isset($input['longitude'])) {
                http_response_code(400);
                die(json_encode(["error" => "Données position manquantes"]));
            }
            $stmt = $pdo->prepare("INSERT INTO user_positions (user_id, latitude, longitude) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE latitude = VALUES(latitude), longitude = VALUES(longitude), last_seen = NOW()");
            $stmt->execute([$input['user_id'], $input['latitude'], $input['longitude']]);
            
            $stmt = $pdo->prepare("SELECT user_id, latitude, longitude FROM user_positions WHERE user_id != ? AND last_seen > DATE_SUB(NOW(), INTERVAL 5 MINUTE)");
            $stmt->execute([$input['user_id']]);
            die(json_encode($stmt->fetchAll()));

        case 'delete':
        case 'delete_alert':
            if (!isset($input['id'])) {
                http_response_code(400);
                die(json_encode(["error" => "ID manquant (reçu: " . json_encode($input) . ")"]));
            }
            $stmt = $pdo->prepare("DELETE FROM alerts WHERE id = ?");
            $success = $stmt->execute([$input['id']]);
            $count = $stmt->rowCount();
            die(json_encode([
                "success" => $success, 
                "deleted_count" => $count,
                "id" => $input['id']
            ]));

        case 'create_alert':
        default:
            if (!isset($input['type']) || !isset($input['latitude']) || !isset($input['longitude'])) {
                http_response_code(400);
                die(json_encode(["error" => "Données signalement manquantes", "received_action" => $action]));
            }
            $id = isset($input['id']) ? $input['id'] : uniqid('alert_');
            $stmt = $pdo->prepare("INSERT INTO alerts (id, type, latitude, longitude, description, user_id, upvotes, downvotes) 
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
