# Git Server

lighttpd + git-http-backend でGitサーバー構築

インストール
```bash
apt install lighttpd git
```

## lighttpd設定

`/etc/lighttpd/lighttpd.conf`:
```conf
server.document-root = "/var/www/html"
server.port = 80
server.username = "www-data"
server.groupname = "www-data"

server.modules += ("mod_cgi", "mod_alias", "mod_rewrite", "mod_setenv")

url.rewrite-once = (
    "^/git/(.*/git-upload-pack)$" => "/git/$1",
    "^/git/(.*/git-receive-pack)$" => "/git/$1",
    "^/git/(.*/info/refs)$" => "/git/$1",
    "^/git/(.*/HEAD)$" => "/git/$1"
)

$HTTP["url"] =~ "^/git" {
    alias.url += ( "/git" => "/usr/lib/git-core/git-http-backend" )
    cgi.assign = ( "" => "" )

    setenv.set-environment = (
        "GIT_PROJECT_ROOT" => "/var/www/git",
        "GIT_HTTP_EXPORT_ALL" => "1",
        "REMOTE_USER" => "dummy"
    )
}
```

サービス再起動
```bash
service lighttpd restart
```

## 動作確認

テスト用のリポジトリ作成
```bash
# ベアリポジトリ作成
git init --bare /var/www/git/hello.git

# 権限設定
chown -R www-data:www-data /var/www/git

# クローン
git clone http://localhost/git/hello.git
cd hello

# ファイル追加＆プッシュ
echo "test" > README.md
git add README.md
git commit -m "first commit"
git push origin master
```

