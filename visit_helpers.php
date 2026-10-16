<?php
const MAX_VISIT_HOURS = 3; // auto check-out after this many hours

function auto_close_stale_visits(mysqli $conn): void {
    $h = (int)MAX_VISIT_HOURS;
    $stmt = $conn->prepare(
        "UPDATE access_logs
         SET checked_out_at = DATE_ADD(checked_in_at, INTERVAL ? HOUR), auto_checked_out = 1
         WHERE access_granted = 1 AND checked_out_at IS NULL
           AND checked_in_at <= DATE_SUB(NOW(), INTERVAL ? HOUR)"
    );
    $stmt->bind_param('ii', $h, $h);
    $stmt->execute();
    $stmt->close();
}