<?php
require_once 'config.php';
if (!isset($_SESSION['user_id']) || $_SESSION['role'] !== 'admin') {
    header('Location: index.php'); exit;
}
$admin_name = $_SESSION['full_name'] ?? 'Admin';

$codes = $conn->query("SELECT ac.id, ac.code, ac.status, ac.generated_at, ac.used_at, u.full_name AS used_by_name
                        FROM access_codes ac
                        LEFT JOIN users u ON u.id = ac.used_by_user_id
                        ORDER BY ac.generated_at DESC LIMIT 50");
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>FitX Admin — Access Codes</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet"/>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --bg: #0d0d0d; --surface: #141414; --card: #1a1a1a; --border: #252525; --border2: #303030;
      --text: #f0f0f0; --sub: #666; --muted: #999;
      --red: #dc2626; --red-dim: rgba(220,38,38,0.12);
      --green: #16a34a; --green-dim: rgba(22,163,74,0.12);
      --amber: #d97706; --amber-dim: rgba(217,119,6,0.12);
      --font: 'Inter', sans-serif; --nav-h: 56px;
    }
    body { font-family: var(--font); background: var(--bg); color: var(--text); }
    /* SIDEBAR */
    .sidebar { position: fixed; top: 0; left: 0; width: 240px; height: 100vh; background: var(--surface); border-right: 1px solid var(--border); z-index: 200; display: flex; flex-direction: column; }
    .side-brand { display: flex; align-items: center; gap: 10px; text-decoration: none; padding: 18px 18px 14px; flex-shrink: 0; }
    .side-logo { width: 32px; height: 32px; border-radius: 6px; background: var(--red); display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 13px; color: #fff; flex-shrink: 0; }
    .side-brand-text { font-size: 14px; font-weight: 700; color: var(--text); }
    .side-brand-text span { color: var(--red); }
    .side-nav { flex: 1; padding: 4px 12px; display: flex; flex-direction: column; gap: 2px; overflow-y: auto; }
    .side-link { display: flex; align-items: center; gap: 9px; padding: 9px 12px; border-radius: 0 6px 6px 0; font-size: 13px; font-weight: 500; color: var(--muted); text-decoration: none; border-left: 3px solid transparent; transition: all 0.15s; white-space: nowrap; }
    .side-link:hover { background: var(--card); color: var(--text); }
    .side-link.active { background: var(--red-dim); color: var(--red); font-weight: 600; border-left-color: var(--red); }
    .side-bottom { border-top: 1px solid var(--border); padding: 14px; flex-shrink: 0; }
    .side-chip { display: flex; align-items: center; gap: 8px; background: var(--card); border: 1px solid var(--border2); border-radius: 20px; padding: 4px 12px 4px 5px; margin-bottom: 8px; min-width: 0; }
    .side-avatar { width: 24px; height: 24px; border-radius: 50%; background: var(--red); color: #fff; font-size: 11px; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
    .side-name { font-size: 12px; font-weight: 600; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .side-logout { display: block; text-align: center; font-size: 12px; color: var(--sub); text-decoration: none; padding: 6px 9px; border-radius: 5px; border: 1px solid var(--border); transition: all 0.15s; }
    .side-logout:hover { color: var(--text); border-color: var(--border2); }

    /* MAIN */
    .main { margin-left: 240px; min-height: 100vh; }

    .page { max-width: 900px; margin: 0 auto; padding: 32px 24px; }
    .page h1 { font-size: 22px; font-weight: 700; margin-bottom: 20px; }

    .generate-card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 24px; margin-bottom: 28px; text-align: center; }
    .generate-btn { background: var(--red); color: #fff; border: none; padding: 14px 28px; border-radius: 8px; font-size: 15px; font-weight: 600; cursor: pointer; font-family: var(--font); }
    .generate-btn:hover { background: #ef4444; }
    .generated-code { margin-top: 20px; display: none; }
    .generated-code .code-display { font-size: 42px; font-weight: 700; letter-spacing: 6px; color: var(--green); font-family: monospace; }
    .generated-code .code-hint { font-size: 13px; color: var(--muted); margin-top: 8px; }

    table { width: 100%; border-collapse: collapse; background: var(--card); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
    th { text-align: left; padding: 12px 16px; font-size: 12px; color: var(--muted); text-transform: uppercase; border-bottom: 1px solid var(--border); }
    td { padding: 12px 16px; font-size: 14px; border-bottom: 1px solid var(--border); }
    tr:last-child td { border-bottom: none; }
    .code-mono { font-family: monospace; font-weight: 600; letter-spacing: 1px; }
    .pill { display: inline-block; padding: 3px 10px; border-radius: 20px; font-size: 11px; font-weight: 600; }
    .pill-active { background: var(--amber-dim); color: var(--amber); }
    .pill-used { background: var(--green-dim); color: var(--green); }

    @media (max-width: 768px) { .sidebar { position: static; width: 100%; height: auto; border-right: none; border-bottom: 1px solid var(--border); } .main { margin-left: 0; } .page { padding: 20px 16px; } }
  </style>
</head>
<body>

<!-- SIDEBAR -->
<aside class="sidebar">
  <a href="admin.php" class="side-brand">
    <div class="side-logo">FX</div>
    <div class="side-brand-text">FitX <span>Admin</span></div>
  </a>
  <nav class="side-nav">
    <a href="admin.php" class="side-link">⊞ Dashboard</a>
    <a href="all_members.php" class="side-link">👥 Members</a>
    <a href="payments.php" class="side-link">💳 Payments</a>
    <a href="admin_enroll_rfid.php" class="side-link">📶 Enroll RFID</a>
    <a href="admin_access_codes.php" class="side-link active">🔑 Access Codes</a>
    <a href="admin_checkin.php" class="side-link">🚪 Check-In Kiosk</a>
    <a href="analytics.php" class="side-link">📈 Analytics</a>
    <a href="settings.php" class="side-link">⚙️ Settings</a>
  </nav>
  <div class="side-bottom">
    <div class="side-chip">
      <div class="side-avatar"><?= strtoupper(substr($admin_name, 0, 1)) ?></div>
      <span class="side-name"><?= htmlspecialchars($admin_name) ?></span>
    </div>
    <a href="logout.php" class="side-logout">Log out</a>
  </div>
</aside>

<div class="main">

<div class="page">
  <h1>Access Codes</h1>

  <div class="generate-card">
    <button class="generate-btn" onclick="generateCode()">+ Generate New Access Code</button>
    <div class="generated-code" id="generatedCode">
      <div class="code-display" id="codeText"></div>
      <div class="code-hint">Tell this code to the member — one-time use only</div>
    </div>
  </div>

  <table>
    <thead>
      <tr><th>Code</th><th>Status</th><th>Generated</th><th>Used By</th></tr>
    </thead>
    <tbody>
      <?php while ($row = $codes->fetch_assoc()): ?>
      <tr>
        <td class="code-mono"><?= htmlspecialchars($row['code']) ?></td>
        <td>
          <?php if ($row['status'] === 'used'): ?>
            <span class="pill pill-used">Used</span>
          <?php else: ?>
            <span class="pill pill-active">Active</span>
          <?php endif; ?>
        </td>
        <td><?= date('M j, Y g:i A', strtotime($row['generated_at'])) ?></td>
        <td><?= $row['used_by_name'] ? htmlspecialchars($row['used_by_name']) : '—' ?></td>
      </tr>
      <?php endwhile; ?>
    </tbody>
  </table>
</div><!-- /.main -->

<script>
async function generateCode() {
  const res = await fetch('api_generate_access_code.php', { method: 'POST' });
  const data = await res.json();
  if (data.success) {
    document.getElementById('codeText').textContent = data.code;
    document.getElementById('generatedCode').style.display = 'block';
  } else {
    alert(data.message || 'Failed to generate code');
  }
}
</script>
</body>
</html>