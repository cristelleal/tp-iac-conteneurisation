<?php
$host     = getenv('DB_HOST') ?: 'db';
$username = getenv('DB_USER') ?: 'root';
$password = getenv('DB_PASS') ?: 'root';
$dbname   = getenv('DB_NAME') ?: 'gestion_produits';
$DB_TYPE  = getenv('DB_TYPE') ?: 'mysql';

if ($DB_TYPE === 'pgsql') {
    $db = new PDO("pgsql:host=$host;dbname=$dbname", $username, $password);
} else {
    $db = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
}
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
?>
