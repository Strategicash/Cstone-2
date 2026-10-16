<?php
require_once 'config.php';
if (!isset($_SESSION['user_id'])) { header('Location: index.php'); exit; }
if ($_SESSION['role'] !== 'admin') { header('Location: index.php'); exit; }

require_once 'visit_helpers.php';
auto_close_stale_visits($conn);

$admin_name = $_SESSION['full_name'];

// CSRF token for the remove-member form
if (empty($_SESSION['csrf'])) { $_SESSION['csrf'] = bin2hex(random_bytes(32)); }

// Remove a member
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_member'])) {
    if (!hash_equals($_SESSION['csrf'], (string)($_POST['csrf'] ?? ''))) {
        http_response_code(403); exit('Invalid request.');
    }
    $uid = (int)($_POST['user_id'] ?? 0);
    if ($uid > 0) {
        $s = $conn->prepare("DELETE FROM users WHERE id = ? AND role = 'member'");
        $s->bind_param('i', $uid); $s->execute(); $s->close();
    }
    header('Location: all_members.php?deleted=1'); exit;
}

// ---- Filters ---------------------------------------------------------------
$allowed_status = ['all', 'active', 'expiring', 'expired', 'inside'];
$filter = $_GET['status'] ?? 'all';
if (!in_array($filter, $allowed_status, true)) { $filter = 'all'; }
$search = trim($_GET['search'] ?? '');

// Fixed SQL fragments only (never built from user input)
$status_sql = [
    'all'      => '1=1',
    'active'   => 'expires_at >= NOW()',
    'expiring' => 'expires_at >= NOW() AND expires_at < DATE_ADD(NOW(), INTERVAL 7 DAY)',
    'expired'  => '(expires_at IS NULL OR expires_at < NOW())',
    'inside'   => 'inside_now > 0',
][$filter];

$inner_where = "u.role = 'member'";
$params = []; $types = '';
if ($search !== '') {
    $inner_where .= " AND (u.full_name LIKE ? OR u.email LIKE ?)";
    $params[] = "%$search%"; $params[] = "%$search%"; $types .= 'ss';
}

$sql = "
    SELECT * FROM (
        SELECT u.id, u.full_name, u.email, u.created_at,
               (SELECT MAX(p.expires_at) FROM payments p
                 WHERE p.user_id = u.id AND p.status = 'paid') AS expires_at,
               (SELECT MAX(al.checked_in_at) FROM access_logs al
                 WHERE al.user_id = u.id AND al.access_granted = 1) AS last_visit,
               (SELECT COUNT(*) FROM access_logs al
                 WHERE al.user_id = u.id AND al.access_granted = 1
                   AND MONTH(al.checked_in_at) = MONTH(NOW())
                   AND YEAR(al.checked_in_at) = YEAR(NOW())) AS visits_month,
               (SELECT COUNT(*) FROM access_logs al
                 WHERE al.user_id = u.id AND al.access_granted = 1
                   AND al.checked_out_at IS NULL) AS inside_now
        FROM users u
        WHERE $inner_where
    ) m
    WHERE $status_sql
    ORDER BY (inside_now > 0) DESC,
             (IFNULL(expires_at, '1970-01-01') >= NOW()) DESC,
             full_name ASC
";
if ($params) {
    $st = $conn->prepare($sql);
    $st->bind_param($types, ...$params);
    $st->execute();
    $members = $st->get_result()->fetch_all(MYSQLI_ASSOC);
    $st->close();
} else {
    $members = $conn->query($sql)->fetch_all(MYSQLI_ASSOC);
}

// ---- Stats (always across all members) ------------------------------------
$r = $conn->query("SELECT COUNT(*) c FROM users WHERE role = 'member'");
$total_members = (int)$r->fetch_assoc()['c']; $r->close();

$r = $conn->query("
    SELECT COUNT(*) c FROM users u
    WHERE u.role = 'member'
      AND EXISTS (SELECT 1 FROM payments p WHERE p.user_id = u.id AND p.status = 'paid' AND p.expires_at >= NOW())
");
$total_active = (int)$r->fetch_assoc()['c']; $r->close();

$r = $conn->query("
    SELECT COUNT(*) c FROM users u
    WHERE u.role = 'member'
      AND (SELECT MAX(p.expires_at) FROM payments p WHERE p.user_id = u.id AND p.status = 'paid')
          BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
");
$total_expiring = (int)$r->fetch_assoc()['c']; $r->close();

$total_expired = max(0, $total_members - $total_active);

$r = $conn->query("SELECT COUNT(DISTINCT user_id) c FROM access_logs WHERE access_granted = 1 AND checked_out_at IS NULL");
$total_inside = (int)$r->fetch_assoc()['c']; $r->close();

$conn->close();

// ---- Helpers ---------------------------------------------------------------
function time_ago($datetime) {
    $diff = time() - strtotime($datetime);
    if ($diff < 60)     return 'just now';
    if ($diff < 3600)   return floor($diff / 60) . ' min ago';
    if ($diff < 86400)  return floor($diff / 3600) . ' hr ago';
    if ($diff < 604800) return floor($diff / 86400) . ' day' . (floor($diff / 86400) > 1 ? 's' : '') . ' ago';
    return date('M j', strtotime($datetime));
}

function tab_link($key, $label, $count, $current, $search) {
    $qs = ['status' => $key];
    if ($search !== '') $qs['search'] = $search;
    $cls = 'tab' . ($current === $key ? ' on' : '');
    return '<a class="' . $cls . '" href="all_members.php?' . htmlspecialchars(http_build_query($qs)) . '">'
         . htmlspecialchars($label) . ' <span class="tab-n">' . (int)$count . '</span></a>';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>FitX Admin — Members</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet"/>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --bg:#0d0d0d; --surface:#141414; --card:#1a1a1a; --border:#252525; --border2:#303030;
      --text:#f0f0f0; --sub:#666; --muted:#999;
      --red:#dc2626; --red-dim:rgba(220,38,38,0.12);
      --green:#16a34a; --green-dim:rgba(22,163,74,0.12);
      --blue:#2563eb; --blue-dim:rgba(37,99,235,0.12);
      --amber:#d97706; --amber-dim:rgba(217,119,6,0.12);
      --font:'Inter',sans-serif; --nav-h:56px; --banner-h:140px;
    }
    body { font-family: var(--font); background: var(--bg); color: var(--text); min-height: 100vh; }

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

    /* BANNER */
    .banner { position: relative; height: var(--banner-h); overflow: hidden; border-bottom: 1px solid var(--border); }
    .banner-img { width: 100%; height: 100%; object-fit: cover; opacity: 0.4; display: block; }
    .banner-overlay { position: absolute; inset: 0; background: linear-gradient(to right, rgba(13,13,13,0.88) 0%, rgba(13,13,13,0.5) 55%, rgba(13,13,13,0.15) 100%); }
    .banner-content { position: absolute; inset: 0; display: flex; align-items: center; justify-content: space-between; padding: 0 40px; }
    .banner-eyebrow { font-size: 10px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: var(--red); margin-bottom: 7px; }
    .banner-title { font-size: 28px; font-weight: 700; letter-spacing: -0.5px; line-height: 1.1; }
    .banner-sub { font-size: 13px; color: var(--muted); margin-top: 6px; }
    .banner-right { text-align: right; }
    .banner-stat-val { font-size: 26px; font-weight: 700; line-height: 1; color: #4ade80; }
    .banner-stat-lbl { font-size: 11px; color: var(--sub); margin-top: 3px; }

    /* MAIN */
    .wrapper { max-width: 1400px; margin: 0 auto; padding: 24px 32px; }
    .alert-red { background: var(--red-dim); border: 1px solid rgba(220,38,38,0.2); color: #f87171; font-size: 13px; padding: 10px 16px; border-radius: 7px; margin-bottom: 18px; font-weight: 500; }

    .stats-grid { display: grid; grid-template-columns: repeat(4,1fr); gap: 12px; margin-bottom: 22px; }
    .scard { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 18px 20px; display: flex; align-items: center; gap: 14px; transition: border-color 0.15s; }
    .scard:hover { border-color: var(--border2); }
    .scard-icon { width: 44px; height: 44px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 20px; flex-shrink: 0; }
    .ic-blue { background: var(--blue-dim); } .ic-green { background: var(--green-dim); } .ic-amber { background: var(--amber-dim); } .ic-red { background: var(--red-dim); }
    .scard-val { font-size: 26px; font-weight: 700; letter-spacing: -0.5px; line-height: 1; }
    .scard-lbl { font-size: 12px; color: var(--sub); margin-top: 3px; font-weight: 500; }
    .scard-note { font-size: 11px; color: var(--muted); margin-top: 2px; }

    .section { background: var(--card); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; margin-bottom: 14px; }
    .section-head { padding: 13px 20px; border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; background: rgba(255,255,255,0.018); }
    .section-title { font-size: 13px; font-weight: 700; }
    .section-body { padding: 0 20px 16px; overflow-x: auto; }

    /* Filter tabs */
    .tabs { display: flex; gap: 6px; flex-wrap: wrap; padding: 12px 20px 0; }
    .tab { display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 6px; font-size: 12px; font-weight: 600; color: var(--muted); text-decoration: none; border: 1px solid var(--border); background: transparent; transition: all 0.15s; }
    .tab:hover { color: var(--text); border-color: var(--border2); }
    .tab.on { background: var(--red-dim); color: var(--red); border-color: rgba(220,38,38,0.35); }
    .tab-n { font-size: 10px; background: var(--border); color: var(--muted); padding: 1px 6px; border-radius: 8px; }
    .tab.on .tab-n { background: rgba(220,38,38,0.2); color: #f87171; }

    .search-form { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
    .search-input { background: var(--surface); border: 1px solid var(--border2); border-radius: 6px; padding: 7px 12px; font-family: var(--font); font-size: 12px; color: var(--text); outline: none; width: 230px; }
    .search-input:focus { border-color: #60a5fa; }
    .btn-filter { background: var(--blue); color: #fff; border: none; border-radius: 6px; padding: 7px 14px; font-family: var(--font); font-size: 12px; font-weight: 600; cursor: pointer; }
    .btn-reset { background: transparent; color: var(--sub); border: 1px solid var(--border); border-radius: 6px; padding: 7px 12px; font-family: var(--font); font-size: 12px; cursor: pointer; text-decoration: none; }

    /* Pills */
    .pill { display: inline-block; font-size: 10px; font-weight: 700; padding: 3px 8px; border-radius: 4px; }
    .pill.active   { background: var(--green-dim); color: #4ade80; }
    .pill.expiring { background: var(--amber-dim); color: #fbbf24; }
    .pill.expired  { background: var(--red-dim);   color: #f87171; }
    .pill.none     { background: var(--border);    color: var(--sub); }
    .pill.inside   { background: var(--blue-dim);  color: #60a5fa; }
    .dot { display: inline-block; width: 6px; height: 6px; border-radius: 50%; background: #60a5fa; margin-right: 5px; animation: dotpulse 1.8s infinite; }
    @keyframes dotpulse { 0%,100% { opacity: 1; } 50% { opacity: 0.35; } }

    table { width: 100%; border-collapse: collapse; }
    thead th { text-align: left; padding: 12px 12px 10px 0; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: var(--sub); border-bottom: 1px solid var(--border); white-space: nowrap; }
    tbody td { padding: 11px 12px 11px 0; font-size: 13px; border-bottom: 1px solid var(--border); color: var(--muted); vertical-align: middle; }
    tbody tr:last-child td { border-bottom: none; }
    tbody tr:hover td { background: rgba(255,255,255,0.01); }
    .td-name { font-weight: 600; font-size: 13px; color: var(--text); }
    .td-email { font-size: 11px; color: var(--sub); margin-top: 1px; }
    .td-main { font-size: 13px; color: var(--text); font-weight: 600; }
    .td-sub { font-size: 11px; color: var(--sub); margin-top: 1px; }
    .td-sub.warn { color: #fbbf24; } .td-sub.bad { color: #f87171; }
    .avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--blue-dim); color: #60a5fa; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 13px; flex-shrink: 0; }
    .avatar.in { box-shadow: 0 0 0 2px rgba(96,165,250,0.5); }

    .btn-sm { border: 1px solid var(--border2); background: transparent; color: var(--muted); border-radius: 5px; padding: 4px 10px; font-family: var(--font); font-size: 11px; font-weight: 600; cursor: pointer; transition: all 0.15s; }
    .btn-sm.danger:hover { border-color: #f87171; color: #f87171; background: var(--red-dim); }

    /* Modal */
    .overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.7); z-index: 300; align-items: center; justify-content: center; backdrop-filter: blur(3px); }
    .overlay.open { display: flex; }
    .modal { background: var(--card); border: 1px solid var(--border2); border-radius: 10px; padding: 26px; width: 400px; max-width: 92vw; }
    .modal-tag { font-size: 10px; font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; color: var(--red); margin-bottom: 6px; }
    .modal h3 { font-size: 16px; font-weight: 700; margin-bottom: 4px; }
    .modal .sub { font-size: 12px; color: var(--sub); margin-bottom: 18px; }
    .modal-btns { display: flex; gap: 8px; margin-top: 18px; }
    .btn-danger { flex: 1; background: var(--red); color: #fff; border: none; border-radius: 6px; padding: 10px; font-family: var(--font); font-size: 13px; font-weight: 700; cursor: pointer; }
    .btn-cancel { background: transparent; color: var(--sub); border: 1px solid var(--border2); border-radius: 6px; padding: 10px 16px; font-family: var(--font); font-size: 13px; cursor: pointer; }
    .btn-cancel:hover { color: var(--text); }

    @media (max-width: 1100px) { .stats-grid { grid-template-columns: 1fr 1fr; } }
    @media (max-width: 768px)  { .sidebar { position: static; width: 100%; height: auto; border-right: none; border-bottom: 1px solid var(--border); } .main { margin-left: 0; } .wrapper { padding: 20px 16px; } .banner-content { padding: 0 20px; } .banner-right { display: none; } .tabs { padding: 12px 16px 0; } }
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
    <a href="all_members.php" class="side-link active">👥 Members</a>
    <a href="payments.php" class="side-link">💳 Payments</a>
    <a href="admin_enroll_rfid.php" class="side-link">📶 Enroll RFID</a>
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

<div class="banner">
  <img class="banner-img" src="equipment.jpg.jpg" alt="">
  <div class="banner-overlay"></div>
  <div class="banner-content">
    <div>
      <div class="banner-eyebrow">Admin — Membership</div>
      <div class="banner-title">Members</div>
      <div class="banner-sub"><?= count($members) ?> result<?= count($members) !== 1 ? 's' : '' ?> shown</div>
    </div>
    <div class="banner-right">
      <div class="banner-stat-val"><?= $total_active ?></div>
      <div class="banner-stat-lbl">Active memberships</div>
    </div>
  </div>
</div>

<div class="wrapper">
  <?php if (isset($_GET['deleted'])): ?><div class="alert-red">✓ Member removed.</div><?php endif; ?>

  <div class="stats-grid">
    <div class="scard">
      <div class="scard-icon ic-blue">👥</div>
      <div>
        <div class="scard-val" style="color:#60a5fa"><?= $total_members ?></div>
        <div class="scard-lbl">Total Members</div>
        <div class="scard-note">All registered</div>
      </div>
    </div>
    <div class="scard">
      <div class="scard-icon ic-green">✅</div>
      <div>
        <div class="scard-val" style="color:#4ade80"><?= $total_active ?></div>
        <div class="scard-lbl">Active Members</div>
        <div class="scard-note"><?= $total_expired ?> expired or unpaid</div>
      </div>
    </div>
    <div class="scard">
      <div class="scard-icon ic-amber">⏰</div>
      <div>
        <div class="scard-val" style="color:#fbbf24"><?= $total_expiring ?></div>
        <div class="scard-lbl">Expiring Soon</div>
        <div class="scard-note">Within 7 days</div>
      </div>
    </div>
    <div class="scard">
      <div class="scard-icon ic-green">🟢</div>
      <div>
        <div class="scard-val" style="color:#4ade80"><?= $total_inside ?></div>
        <div class="scard-lbl">Inside Now</div>
        <div class="scard-note">Currently in the gym</div>
      </div>
    </div>
  </div>

  <div class="section">
    <div class="section-head">
      <span class="section-title">Member List</span>
      <form method="GET" action="all_members.php" class="search-form">
        <input type="hidden" name="status" value="<?= htmlspecialchars($filter) ?>"/>
        <input type="text" name="search" class="search-input" placeholder="Search name or email..." value="<?= htmlspecialchars($search) ?>"/>
        <button type="submit" class="btn-filter">Search</button>
        <a href="all_members.php" class="btn-reset">Reset</a>
      </form>
    </div>

    <div class="tabs">
      <?= tab_link('all',      'All',           $total_members,  $filter, $search) ?>
      <?= tab_link('active',   'Active',        $total_active,   $filter, $search) ?>
      <?= tab_link('expiring', 'Expiring Soon', $total_expiring, $filter, $search) ?>
      <?= tab_link('expired',  'Expired',       $total_expired,  $filter, $search) ?>
      <?= tab_link('inside',   'Inside Now',    $total_inside,   $filter, $search) ?>
    </div>

    <div class="section-body">
      <table>
        <thead>
          <tr><th>Member</th><th>Membership</th><th>Expires</th><th>Last Visit</th><th>Visits (Month)</th><th>Joined</th><th></th></tr>
        </thead>
        <tbody>
          <?php if (empty($members)): ?>
            <tr><td colspan="7" style="text-align:center;color:var(--sub);padding:24px 0;">No members found.</td></tr>
          <?php else: foreach ($members as $m):
            $now = time();
            $exp = $m['expires_at'] ? strtotime($m['expires_at']) : null;
            $inside = (int)$m['inside_now'] > 0;
            if ($exp === null) {
                $state = 'none';     $label = 'No payment';
                $exp_main = '—';     $exp_sub = ''; $exp_cls = '';
            } elseif ($exp >= $now) {
                $days = (int)ceil(($exp - $now) / 86400);
                $state = $days <= 7 ? 'expiring' : 'active';
                $label = $days <= 7 ? 'Expiring soon' : 'Active';
                $exp_main = date('M j, Y', $exp);
                $exp_sub  = $days . ' day' . ($days === 1 ? '' : 's') . ' left';
                $exp_cls  = $days <= 7 ? 'warn' : '';
            } else {
                $ago = (int)floor(($now - $exp) / 86400);
                $state = 'expired';  $label = 'Expired';
                $exp_main = date('M j, Y', $exp);
                $exp_sub  = $ago < 1 ? 'Expired today' : 'Expired ' . $ago . ' day' . ($ago === 1 ? '' : 's') . ' ago';
                $exp_cls  = 'bad';
            }
          ?>
          <tr>
            <td>
              <div style="display:flex;align-items:center;gap:10px;">
                <div class="avatar<?= $inside ? ' in' : '' ?>"><?= strtoupper(substr($m['full_name'], 0, 1)) ?></div>
                <div>
                  <div class="td-name"><?= htmlspecialchars($m['full_name']) ?></div>
                  <div class="td-email"><?= htmlspecialchars($m['email']) ?></div>
                </div>
              </div>
            </td>
            <td><span class="pill <?= $state ?>"><?= $label ?></span></td>
            <td>
              <div class="td-main"><?= $exp_main ?></div>
              <?php if ($exp_sub): ?><div class="td-sub <?= $exp_cls ?>"><?= $exp_sub ?></div><?php endif; ?>
            </td>
            <td>
              <?php if ($inside): ?>
                <span class="pill inside"><span class="dot"></span>Inside now</span>
              <?php elseif ($m['last_visit']): ?>
                <div class="td-main"><?= time_ago($m['last_visit']) ?></div>
                <div class="td-sub"><?= date('M j, g:i A', strtotime($m['last_visit'])) ?></div>
              <?php else: ?>
                <span style="color:var(--sub);">Never</span>
              <?php endif; ?>
            </td>
            <td><div class="td-main"><?= (int)$m['visits_month'] ?></div></td>
            <td style="font-size:12px;"><?= date('M j, Y', strtotime($m['created_at'])) ?></td>
            <td>
              <button type="button" class="btn-sm danger"
                      data-id="<?= (int)$m['id'] ?>"
                      data-name="<?= htmlspecialchars($m['full_name'], ENT_QUOTES) ?>"
                      onclick="openDelete(this)">Remove</button>
            </td>
          </tr>
          <?php endforeach; endif; ?>
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- REMOVE MODAL -->
<div class="overlay" id="delete-modal">
  <div class="modal">
    <div class="modal-tag">Danger</div>
    <h3 style="color:#f87171;">Remove Member</h3>
    <p class="sub">This permanently deletes <strong id="delete-name" style="color:var(--text)"></strong> and their records.</p>
    <form method="POST" action="all_members.php">
      <input type="hidden" name="delete_member" value="1"/>
      <input type="hidden" name="csrf" value="<?= htmlspecialchars($_SESSION['csrf']) ?>"/>
      <input type="hidden" name="user_id" id="delete-member-id"/>
      <div class="modal-btns">
        <button type="submit" class="btn-danger">Yes, Remove</button>
        <button type="button" class="btn-cancel" onclick="closeModals()">Cancel</button>
      </div>
    </form>
  </div>
</div>

<script>
  function openDelete(btn) {
    document.getElementById('delete-name').textContent = btn.dataset.name;
    document.getElementById('delete-member-id').value = btn.dataset.id;
    document.getElementById('delete-modal').classList.add('open');
  }
  function closeModals() { document.getElementById('delete-modal').classList.remove('open'); }
  document.getElementById('delete-modal').addEventListener('click', function (e) { if (e.target === this) closeModals(); });
</script>
</div><!-- /.main -->
</body>
</html>