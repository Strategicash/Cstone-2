<?php
/**
 * API endpoint to log body metrics for a user.
 * 
 * Expected POST JSON:
 * {
 *   "user_id": 123,
 *   "weight_kg": 75.5,
 *   "body_fat": 18.2,
 *   "chest_cm": 100.5,
 *   "waist_cm": 85.0,
 *   "hips_cm": 98.0
 * }
 * 
 * Returns JSON:
 * {"success": true, "message": "Metrics logged successfully"}
 * or error: {"success": false, "message": "Error description"}
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed. Use POST.']);
    exit();
}

// Database configuration - UPDATE THESE WITH YOUR ACTUAL CREDENTIALS
$dbHost = 'localhost';
$dbName = 'fitx_db';
$dbUser = 'root';
$dbPass = '';

try {
    $pdo = new PDO("mysql:host=$dbHost;dbname=$dbName;charset=utf8mb4", $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed: ' . $e->getMessage()]);
    exit();
}

// Read JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (!$input) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON payload']);
    exit();
}

// Validate required fields
$userId = $input['user_id'] ?? null;
$weightKg = $input['weight_kg'] ?? null;
$bodyFat = $input['body_fat'] ?? null;
$chestCm = $input['chest_cm'] ?? null;
$waistCm = $input['waist_cm'] ?? null;
$hipsCm = $input['hips_cm'] ?? null;

if ($userId === null) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'user_id is required']);
    exit();
}

// At least one metric should be provided
$metricsProvided = array_filter([
    'weight_kg' => $weightKg,
    'body_fat' => $bodyFat,
    'chest_cm' => $chestCm,
    'waist_cm' => $waistCm,
    'hips_cm' => $hipsCm,
], function($v) { return $v !== null; });

if (empty($metricsProvided)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'At least one body metric is required']);
    exit();
}

// Build dynamic INSERT query
$fields = ['user_id'];
$values = [$userId];
$placeholders = ['?'];

if ($weightKg !== null) {
    $fields[] = 'weight_kg';
    $values[] = $weightKg;
    $placeholders[] = '?';
}
if ($bodyFat !== null) {
    $fields[] = 'body_fat';
    $values[] = $bodyFat;
    $placeholders[] = '?';
}
if ($chestCm !== null) {
    $fields[] = 'chest_cm';
    $values[] = $chestCm;
    $placeholders[] = '?';
}
if ($waistCm !== null) {
    $fields[] = 'waist_cm';
    $values[] = $waistCm;
    $placeholders[] = '?';
}
if ($hipsCm !== null) {
    $fields[] = 'hips_cm';
    $values[] = $hipsCm;
    $placeholders[] = '?';
}

$fields[] = 'recorded_at';
$values[] = date('Y-m-d H:i:s');
$placeholders[] = '?';

$sql = 'INSERT INTO `body_metrics` (' . implode(', ', array_map(fn($f) => "`$f`", $fields)) . ') VALUES (' . implode(', ', $placeholders) . ')';

try {
    $stmt = $pdo->prepare($sql);
    $stmt->execute($values);
    
    echo json_encode(['success' => true, 'message' => 'Metrics logged successfully']);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Failed to log metrics: ' . $e->getMessage()]);
}