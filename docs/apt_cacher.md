---
title: Apt Cacher
description: Apt Cache server
update: 2026-04-05
status: wip
tags:
- debian
- bookworm
- apt-cacher-ng
- proxy
---
# APT Cache Server

> 複数のコンテナ、VM、ホストマシンなどでキャッシュを共有
> インターネット接続が不安定な環境でも高速でパッケージのインストール
> 何度も作成と破棄を繰り返すコンテナ等で効果的

[Apt-Cacher-NG User Manual](
https://www.unix-ag.uni-kl.de/~bloch/acng/html/index.html
)

## セットアップ

1. パッケージのインストール
2. サーバの設定
3. クライアントの設定

サーバー設定
```
# server
sudo apt install apt-cacher-ng
sudo ufw allow 3142/tcp

# サーバー自身のキャッシュも取得
echo 'Acquire::http::Proxy "http://localhost:3142";' | sudo tee /etc/apt/apt.conf.d/02proxy
```

各クライアント設定
```
# client
echo 'Acquire::http::Proxy "http://apt-cacher.local:3142";' | sudo tee /etc/apt/apt.conf.d/02proxy
```

以上で完了、クライアントから`apt update`などするとキャッシュサーバに取得しに行く

> ファイル名は`02proxy`など自由に設定可、アルファベット順にaptが読み込む
> サーバ自身のプロキシもやった
> デフォルトのポートは`3142`


インストール時に以下のように聞かれたが、とりあえずyesにした
"allow HTTP tunnels through Apt-Cacher NG"

スクリプトなどですべてデフォルト、対話スキップするには
```
DEBIAN_FRONTEND=noninteractive apt-get install -y apt-cacher-ng
```

インストールで自動的にサービス起動・有効化されてる
```
systemctl status apt-cacher-ng
```


## サーバの設定

デフォルトでもOK、必要に応じて設定ファイルを編集

設定例
`/etc/apt-cacher-ng/acng.conf`
```ini
# キャッシュディレクトリの設定
# デフォルト: /var/cache/apt-cacher-ng
CacheDir: /srv/apt-cacher-ng

# ポート番号の変更
# デフォルト: 3142
Port:1234

squidなどのプロキシを経由する場合
Proxy: http://proxy.local:8080
```

設定変更後はサービス再起動 
```bash
sudo systemctl restart apt-cacher-ng
```


## クライアント側の設定

```bash
echo 'Acquire::http::Proxy "http://<cach-server>:3142";' | sudo tee /etc/apt/apt.conf.d/02proxy
```
キャッシュサーバのIPアドレスまたはホスト名を指定する
> `02proxy`など任意のファイル名
> どちらの書き方でもいいみたい
>   Acquire::http::Proxy "<url>:<port>";
>   Acquire::http { Proxy "<url>:<port>"; }


## 動作確認
キャッシュサーバーのログを確認
```bash
tail -f /var/log/apt-cacher-ng/apt-cacher.log
```
クライアントで `apt update`

キャッシュの統計情報を確認
ブラウザで以下にアクセス：
```
http://apt-cacher-.local:3142/acng-report.html
```
キャッシュヒット率やダウンロード量を確認


## プリフェッチ

公式docもあまり参考にならず、スクリプトでwgetで日々更新
> とりあえず設定して様子見
`/etc/apt-cacher-ng/acng.conf`
```
# Example:
# PrecacheFor: debrep/dists/unstable/*/source/Sources* debrep/dists/unstable/*/binary-amd64/Packages*

# Debian:
#PrecacheFor: debrep/dists/bookworm/*/binary-amd64/Packages*
#PrecacheFor: debrep/dists/bookworm-updates/*/binary-amd64/Packages*
PrecacheFor: debrep/dists/trixie/*/binary-amd64/Packages*
PrecacheFor: debrep/pool/**/*.deb

# Debian Security:
PrecacheFor: secdeb/dists/*/*/binary-amd64/Packages*
PrecacheFor: secdeb/pool/**/*.deb
```


## トラブルシューティング

接続できない場合  

サーバー側で
```
# ファイアウォールを確認 
sudo ufw status

# ポート
ss -tuln | grep 3142 

# サービスが動いているか
sudo systemctl status apt-cacher-ng.service

# 設定ファイル
cat /etc/apt/apt.conf.d/02proxy
```


### クライアントでBADSIG error

```sh
$ sudo apt udpate

...

Reading state information... Done
2 packages can be upgraded. Run 'apt list --upgradable' to see them.
W: An error occurred during the signature verification. The repository is not updated and the previous index files will be used. GPG error: http://security.ubuntu.com/ubuntu noble-security InRelease: The following signatures were invalid: BADSIG 871920D1991BC93C Ubuntu Archive Automatic Signing Key (2018) <ftpmaster@ubuntu.com>
W: An error occurred during the signature verification. The repository is not updated and the previous index files will be used. GPG error: http://jp.archive.ubuntu.com/ubuntu noble-updates InRelease: The following signatures were invalid: BADSIG 871920D1991BC93C Ubuntu Archive Automatic Signing Key (2018) <ftpmaster@ubuntu.com>
W: Failed to fetch http://jp.archive.ubuntu.com/ubuntu/dists/noble-updates/InRelease  The following signatures were invalid: BADSIG 871920D1991BC93C Ubuntu Archive Automatic Signing Key (2018) <ftpmaster@ubuntu.com>
W: Failed to fetch http://security.ubuntu.com/ubuntu/dists/noble-security/InRelease  The following signatures were invalid: BADSIG 871920D1991BC93C Ubuntu Archive Automatic Signing Key (2018) <ftpmaster@ubuntu.com>
W: Some index files failed to download. They have been ignored, or old ones used instead.
```

サーバーで
```
# 署名ファイルを削除（パッケージキャッシュは保持）
sudo rm /var/cache/apt-cacher-ng/uburep/dists/noble/InRelease
sudo rm /var/cache/apt-cacher-ng/uburep/dists/noble-updates/InRelease
sudo rm /var/cache/apt-cacher-ng/security.ubuntu.com/ubuntu/dists/noble-security/InRelease
```

その後クライアントで更新
```
sudo apt update
```
これでBADSIGが更新されてエラー解消されてる
しかし頻繁になる、定期的にパッケージの更新すれば大丈夫


### キャッシュの削除
```bash
sudo apt-cacher-ng -c /var/cache/apt-cacher-ng cleanup
```
> これはやったことない

> ubuntu desktop含む物理１０台程度、３〜４ヶ月でこの程度なら放置で
```
debian@sz6-2:~$ sudo machinectl shell c2 /bin/du -sh /var/cache/apt-cacher-ng
Connected to machine c2. Press ^] three times within 1s to exit session.
14G     /var/cache/apt-cacher-ng
Connection to machine c2 terminated.
```


## ログ

ディレクトリ構成
```
debian@c2:~$ ls -l /var/log/apt-cacher-ng/
total 2344
-rw-r--r-- 1 apt-cacher-ng apt-cacher-ng       0 Nov 10 04:13 apt-cacher.dbg
-rw-r--r-- 1 apt-cacher-ng apt-cacher-ng       0 Nov 10 04:13 apt-cacher.err
-rw-r--r-- 1 apt-cacher-ng apt-cacher-ng 2346802 Feb 21 09:57 apt-cacher.log
-rw-r--r-- 1 apt-cacher-ng apt-cacher-ng    1894 Feb 10 06:25 maint_1770722701.log.html
-rw-r--r-- 1 apt-cacher-ng apt-cacher-ng    1896 Feb 11 06:25 maint_1770809101.log.html
-rw-r--r-- 1 apt-cacher-ng apt-cacher-ng    1897 Feb 12 06:25 maint_1770895501.log.html
```

> 2025-11-10 ~ 2026-02-22 約３ヶ月で2MBのログ、そのまま放置でも大丈夫そう
> その後5.1M
```
$ date
Sun Apr  5 09:03:36 AM UTC 2026
$ sudo machinectl shell c2 /bin/du -sh /var/log/apt-cacher-ng
Connected to machine c2. Press ^] three times within 1s to exit session.
5.1M    /var/log/apt-cacher-ng
Connection to machine c2 terminated.
```

初期のログ
```
debian@c2:~$ head /var/log/apt-cacher-ng/apt-cacher.log
1762766529|I|29564|fe80::e096:3dff:fe95:8134%host0|debrep/dists/bookworm/InRelease
1762766529|O|102|fe80::e096:3dff:fe95:8134%host0|debrep/dists/bookworm/InRelease
1762766529|I|22606|fe80::e096:3dff:fe95:8134%host0|secdeb/dists/bookworm-security/InRelease
1762766529|O|102|fe80::e096:3dff:fe95:8134%host0|secdeb/dists/bookworm-security/InRelease
1762766529|I|56848|fe80::e096:3dff:fe95:8134%host0|debrep/dists/bookworm-updates/InRelease
1762766529|O|55717|fe80::e096:3dff:fe95:8134%host0|debrep/dists/bookworm-updates/InRelease
1762766542|I|133424|192.168.148.239|debrep/pool/main/l/less/less_590-2.1~deb12u2_amd64.deb
1762766542|O|132331|192.168.148.239|debrep/pool/main/l/less/less_590-2.1~deb12u2_amd64.deb
1762766542|I|94364|192.168.148.239|debrep/pool/main/libe/libedit/libedit2_3.1-20221030-2_amd64.deb
1762766542|O|93287|192.168.148.239|debrep/pool/main/libe/libedit/libedit2_3.1-20221030-2_amd64.deb
```
> I = Incoming (外部から取得)
> O = Outgoing (クライアントへ送信)

日付を見やすく
```
$ date -d @1762766529
Mon Nov 10 04:22:09 EST 2025

$ head /var/log/apt-cacher-ng/apt-cacher.log | awk -F'|' '{
    ts = strftime("%Y-%m-%d %H:%M:%S", $1);
    print ts "|" $2 "|" $3 "|" $4 "|" $5
}'
2025-11-10 04:22:09|I|29564|fe80::e096:3dff:fe95:8134%host0|debrep/dists/bookworm/InRelease
2025-11-10 04:22:09|O|102|fe80::e096:3dff:fe95:8134%host0|debrep/dists/bookworm/InRelease
2025-11-10 04:22:09|I|22606|fe80::e096:3dff:fe95:8134%host0|secdeb/dists/bookworm-security/InRelease
2025-11-10 04:22:09|O|102|fe80::e096:3dff:fe95:8134%host0|secdeb/dists/bookworm-security/InRelease
2025-11-10 04:22:09|I|56848|fe80::e096:3dff:fe95:8134%host0|debrep/dists/bookworm-updates/InRelease
2025-11-10 04:22:09|O|55717|fe80::e096:3dff:fe95:8134%host0|debrep/dists/bookworm-updates/InRelease
2025-11-10 04:22:22|I|133424|192.168.148.239|debrep/pool/main/l/less/less_590-2.1~deb12u2_amd64.deb
2025-11-10 04:22:22|O|132331|192.168.148.239|debrep/pool/main/l/less/less_590-2.1~deb12u2_amd64.deb
2025-11-10 04:22:22|I|94364|192.168.148.239|debrep/pool/main/libe/libedit/libedit2_3.1-20221030-2_amd64.deb
2025-11-10 04:22:22|O|93287|192.168.148.239|debrep/pool/main/libe/libedit/libedit2_3.1-20221030-2_amd64.deb
```

最新のログを見やすく整形
```
$ tail -n 30 /var/log/apt-cacher-ng/apt-cacher.log | awk -F'|' '
BEGIN {
    printf "%-19s | %-4s | %8s | %-20s | %s\n",
           "date", "i/o", "size", "address", "file"
    printf "%-19s-+-%-4s-+-%8s-+-%-20s-+-%s\n",
           "-------------------", "----", "--------", "--------------------", "------------------------------"
}
{
    cmd = "date -d @" $1 " +\"%Y-%m-%d %H:%M:%S\"";
    cmd | getline ts;
    close(cmd);

    # SHAの長い部分を省略（/by-hash/SHA256/以降の文字を「...」に）
    file = $5
    gsub(/\/by-hash\/SHA256\/[a-f0-9]+/, "/by-hash/SHA256/...", file)
    printf "%-19s | %-4s | %8s | %-20s | %s\n",
           ts, $2, $3, $4, file
}'
date                | i/o  |     size | address              | file
--------------------+------+----------+----------------------+-------------------------------
2026-02-21 08:53:54 | O    |    31526 | 192.168.10.15        | uburep/pool/main/e/etckeeper/etckeeper_1.18.20-2_all.deb
2026-02-21 09:01:24 | I    |      415 | 192.168.10.119       | uburep/dists/noble/InRelease
2026-02-21 09:01:24 | O    |      102 | 192.168.10.119       | uburep/dists/noble/InRelease
2026-02-21 09:01:24 | I    |      415 | 192.168.10.119       | security.ubuntu.com/ubuntu/dists/noble-security/InRelease
2026-02-21 09:01:24 | O    |   126402 | 192.168.10.119       | security.ubuntu.com/ubuntu/dists/noble-security/InRelease
2026-02-21 09:01:24 | O    |    21891 | 192.168.10.119       | security.ubuntu.com/ubuntu/dists/noble-security/main/dep11/by-hash/SHA256/...
2026-02-21 09:01:24 | O    |      571 | 192.168.10.119       | security.ubuntu.com/ubuntu/dists/noble-security/restricted/dep11/by-hash/SHA256/...
2026-02-21 09:01:24 | O    |    74539 | 192.168.10.119       | security.ubuntu.com/ubuntu/dists/noble-security/universe/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | I    |      414 | 192.168.10.119       | uburep/dists/noble-updates/InRelease
2026-02-21 09:01:25 | O    |   126398 | 192.168.10.119       | uburep/dists/noble-updates/InRelease
2026-02-21 09:01:25 | I    |      414 | 192.168.10.119       | uburep/dists/noble-backports/InRelease
2026-02-21 09:01:25 | O    |   126448 | 192.168.10.119       | uburep/dists/noble-backports/InRelease
2026-02-21 09:01:25 | O    |   175142 | 192.168.10.119       | uburep/dists/noble-updates/main/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | O    |      569 | 192.168.10.119       | uburep/dists/noble-updates/restricted/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | O    |   386334 | 192.168.10.119       | uburep/dists/noble-updates/universe/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | O    |     1297 | 192.168.10.119       | uburep/dists/noble-updates/multiverse/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | O    |     7638 | 192.168.10.119       | uburep/dists/noble-backports/main/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | O    |      575 | 192.168.10.119       | uburep/dists/noble-backports/restricted/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | O    |    10867 | 192.168.10.119       | uburep/dists/noble-backports/universe/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | O    |      571 | 192.168.10.119       | security.ubuntu.com/ubuntu/dists/noble-security/multiverse/dep11/by-hash/SHA256/...
2026-02-21 09:01:25 | O    |      571 | 192.168.10.119       | uburep/dists/noble-backports/multiverse/dep11/by-hash/SHA256/...
2026-02-21 09:57:37 | I    |      415 | 192.168.10.18        | uburep/dists/noble/InRelease
2026-02-21 09:57:37 | O    |      102 | 192.168.10.18        | uburep/dists/noble/InRelease
2026-02-21 09:57:37 | I    |      414 | 192.168.10.18        | uburep/dists/noble-updates/InRelease
2026-02-21 09:57:37 | O    |      102 | 192.168.10.18        | uburep/dists/noble-updates/InRelease
2026-02-21 09:57:37 | I    |      415 | 192.168.10.18        | security.ubuntu.com/ubuntu/dists/noble-security/InRelease
2026-02-21 09:57:37 | O    |      102 | 192.168.10.18        | security.ubuntu.com/ubuntu/dists/noble-security/InRelease
2026-02-21 09:57:37 | I    |      414 | 192.168.10.18        | uburep/dists/noble-backports/InRelease
2026-02-21 09:57:37 | O    |      102 | 192.168.10.18        | uburep/dists/noble-backports/InRelease
2026-02-21 18:32:12 | E    |      661 | 192.168.10.119       | favicon.ico/ [HTTP error, code: 503]
```
> Oが連続してキャッシュ効いてることを確認できる
> この範囲でinはGPGエラーで削除したInReleaseのみ

