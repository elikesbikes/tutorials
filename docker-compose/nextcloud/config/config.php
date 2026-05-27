<?php
$CONFIG = array (
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => 
  array (
    0 => 
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => 
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'instanceid' => 'ocvfy7labqv5',
  'passwordsalt' => '1RVBekUQiw6fYjZj/DYN+BtFBNjwoe',
  'secret' => 'WwRkweZwFnoAv5Lnnlh+LPDKa7IUucP9mrawKrIH5cMWAf2i',
  #'trusted_domains' => 
  #array (
  #  0 => '192.168.5.20:8888',
  #),
  #######
  'trusted_domains' =>
  array (
    0 => 'nextcloud.home.elikesbikes.com',
  ),
  'trusted_proxies' =>
  array (
    0 => '192.168.5.20',
  ),
  'overwrite.cli.url' => 'https://nextcloud.home.nextcloud.com',
  'overwriteprotocol' => 'https',
  'forwarded_for_headers' => ['HTTP_X_FORWARDED', 'HTTP_FORWARDED_FOR'],
  ######


  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'mysql',
  'version' => '27.0.2.1',
  #'overwrite.cli.url' => 'http://192.168.5.20:8888',
  'dbname' => 'nextcloud',
  'dbhost' => 'emidocknextcloud-db.emi.dock',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloud',
  'dbpassword' => '60204397',
  'installed' => true,
);