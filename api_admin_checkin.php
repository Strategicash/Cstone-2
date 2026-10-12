<?php
header('Content-Type: application/json');
require_once 'config.php';

$data = json_decode(file_get_contents('php://input'), true);
$card_id = trim($data['rfid_card_id'] ?? '');

if (empty($card_id)) {
    echo json_encode(['success' => false, 'message' => 'No card scanned']);
    exit;
}

$stmt = $conn->prepare("SELECT id, full_name FROM users WHERE rfid_card_id = ?");
$stmt->bind_param("s", $card_id);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    echo json_encode(['success' => false, 'message' => 'Card not recognized', 'status' => 'unknown_card']);
    exit;
}

$payStmt = $conn->prepare("SELECT expires_at FROM payments WHERE user_id = ? AND status = 'paid' AND expires_at >= NOW() ORDER BY expires_at DESC LIMIT 1");
$payStmt->bind_param("i", $user['id']);
$payStmt->execute();
$membership = $payStmt->get_result()->fetch_assoc();
$payStmt->close();

$granted = $membership ? 1 : 0;

$logStmt = $conn->prepare("INSERT INTO access_logs (user_id, method, access_granted) VALUES (?, 'rfid', ?)");
$logStmt->bind_param("ii", $user['id'], $granted);
$logStmt->execute();
$logStmt->close();

if ($granted) {
    echo json_encode([
        'success' => true,
        'status' => 'granted',
        'name' => $user['full_name'],
        'message' => 'Welcome, ' . $user['full_name'] . '!',
        'expires_at' => $membership['expires_at'],
    ]);
} else {
    echo json_encode([
        'success' => true,
        'status' => 'denied',
        'name' => $user['full_name'],
        'message' => $user['full_name'] . ' — membership expired',
    ]);
}

$conn->close();