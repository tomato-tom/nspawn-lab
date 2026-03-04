---
title: Lighttpd Rootfs Server
update: 2026-03-04
status: draft
tags:
- lighttpd
- php-fpm
- debian
---
# lighttpd rootfs server

各マシンでISO/Rootfsをサクッとダウンロードできるようにローカル配布サーバーに置いとく

コンテナ内のファイル構造
```bash
/var/www/html/     # www-data:www-data
├── index.php          # ISO/rootfs一覧表示
├── iso/               # ISOファイル配布
└── rootfs/            # rootfsファイル配布
```

## lighttpdのセットアップ

### インストール
```bash
# lighttpdインストール
sudo apt install lighttpd

# 動作確認
systemctl status lighttpd
```

### ディレクトリ作成と権限設定
```bash
# 配信用ディレクトリ作成
sudo mkdir -p /var/www/html/iso
sudo mkdir -p /var/www/html/rootfs

# 所有権をwww-dataに統一
sudo chown -R www-data:www-data /var/www/html/
```

### WebDAVモジュールのインストールと有効化
```bash
# WebDAVモジュールインストール
sudo apt install lighttpd-mod-webdav

# モジュール有効化
sudo lighty-enable-mod webdav

# 有効化確認
ls -l /etc/lighttpd/conf-enabled/ | grep webdav
```

### ロックDBの作成
```bash
# ロックDB用ディレクトリ作成
sudo mkdir -p /var/cache/lighttpd

# ロックDB作成
sudo touch /var/cache/lighttpd/lighttpd.webdav_lock.db
sudo chown www-data:www-data /var/cache/lighttpd/lighttpd.webdav_lock.db

# 確認
ls -l /var/cache/lighttpd/
```

### lighttpd設定
```bash
sudo vi /etc/lighttpd/lighttpd.conf
```

以下の設定を追加：
```nginx
server.modules += ("mod_webdav")

# ISOディレクトリ（読み書き可能）
$HTTP["url"] =~ "^/iso(?:/|$)" {
    dir-listing.activate = "enable"
    webdav.activate = "enable"
    webdav.is-readonly = "disable"
    webdav.sqlite-db-name = "/var/cache/lighttpd/lighttpd.webdav_lock.db"
}

# rootfsディレクトリ（読み書き可能）
$HTTP["url"] =~ "^/rootfs(?:/|$)" {
    dir-listing.activate = "enable"
    webdav.activate = "enable"
    webdav.is-readonly = "disable"
    webdav.sqlite-db-name = "/var/cache/lighttpd/lighttpd.webdav_lock.db"
}
```

設定反映
```bash
# 設定ファイルの構文チェック
sudo lighttpd -t -f /etc/lighttpd/lighttpd.conf

# デフォルトではerrorのみだからaccessも有効に
sudo lighty-enable-mod accesslog

# lighttpd再起動
sudo systemctl restart lighttpd

# 状態確認
sudo systemctl status lighttpd
```

### WebDAV動作確認
```bash
# OPTIONSメソッドで確認
curl -X OPTIONS http://localhost/rootfs/ -v
# → Allow: PROPFIND, DELETE, MKCOL, PUT, MOVE, COPY, ... が表示されればOK
```

### ログ
```bash
# エラーログ
sudo tail /var/log/lighttpd/error.log

# アクセスログ
sudo tail /var/log/lighttpd/access.log
```

### ファイル操作テスト
```bash
# アップロード
curl -T test.txt http://localhost/rootfs/test.txt

# ダウンロード
curl -O http://localhost/rootfs/test.txt

# 削除
curl -X DELETE http://localhost/rootfs/test.txt

# ディレクトリ作成
curl -X MKCOL http://localhost/rootfs/testdir/
```


### トラブルシューティング
```bash
# モジュール有効化状態確認
ls -l /etc/lighttpd/conf-enabled/

# 設定ファイル確認
grep -A 10 webdav /etc/lighttpd/lighttpd.conf

# ロックDB存在確認
ls -l /var/cache/lighttpd/lighttpd.webdav_lock.db

# WebDAVモジュールが読み込まれているか確認
lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep webdav
```

これでISOとrootfs両方のディレクトリでWebDAVが有効になり、HTTP経由でのファイル管理が可能になります。


## php-fpmのセットアップ

```
# PHPとPHP-FPMインストール
sudo apt install php8.2 php8.2-fpm

# PHP-FPM起動
sudo systemctl enable --now php8.2-fpm

# lighttpdでPHP有効化
sudo lighty-enable-mod fastcgi fastcgi-php
sudo systemctl restart lighttpd

# テスト
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php
curl http://localhost/info.php | head
```

## nspawnコンテナでの簡易ウェブUI

### index.php
```php
<!DOCTYPE html>
<html>
<head>
    <title>ファイル一覧</title>
    <style>
        .tab-container { display: flex; }
        .tab { padding: 10px 20px; cursor: pointer; }
        .tab.active { background: #007cba; color: white; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        /* その他のスタイル */
    </style>
</head>
<body>
    <div class="tab-container">
        <div class="tab active" onclick="switchTab('iso')">📀 ISOファイル</div>
        <div class="tab" onclick="switchTab('rootfs')">📦 rootfsファイル</div>
    </div>
    
    <!-- ISOタブ -->
    <div id="iso-content" class="tab-content active">
        <!-- ISO一覧表示（既存） -->
    </div>
    
    <!-- rootfsタブ -->
    <div id="rootfs-content" class="tab-content">
        <?php
        $rootfs_dir = '/var/www/html/rootfs/';
        // .gz, .tar ファイルを表示
        ?>
    </div>
    
    <script>
        function switchTab(tab) { /* タブ切り替え処理 */ }
    </script>
</body>
</html>
```

ブラウザから接続して表示やダウンロード
http://local-server

### ファイル操作

他のマシンからpullして更新してpushとかで

```bash
# ローカルのイメージをtarエクスポート
sudo machinectl export-tar bookworm-min bookworm-min.tar.gz

# サーバーにpush
curl -T bookworm-min.tar.gz http://local-server/rootfs/bookworm-min.tar.gz

# 他のマシンでpull
sudo machinectl pull-tar http://local-server/rootfs/bookworm-min.tar.gz
```

