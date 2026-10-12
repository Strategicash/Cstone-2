<?php
// Version-controlled mirror of the deployed endpoint.
// Deploy to: htdocs/Capstone Project1/api_get_membership_plans.php
// Requires config.php (mysqli $conn) alongside it on the server.
header('Content-Type: application/json');
require_once 'config.php';

$stmt = $conn->prepare("SELECT id, plan_name, duration_days, price FROM membership_plans WHERE is_active = 1 ORDER BY duration_days ASC");
if (!$stmt) {
    echo json_encode(['success' => false, 'message' => 'Failed to prepare query']);
    $conn->close();
    exit;
}

$stmt->execute();
$result = $stmt->get_result();

$plans = [];
while ($row = $result->fetch_assoc()) {
    $plans[] = [
        'id' => (int) $row['id'],
        'plan_name' => $row['plan_name'],
        'duration_days' => (int) $row['duration_days'],
        'price' => (float) $row['price'],
    ];
}

echo json_encode(['success' => true, 'plans' => $plans]);

$stmt->close();
$conn->close();
