#!/bin/bash
# lighttpd + git-http-backend でGitサーバー構築

apt install lighttpd git

cat <<'EOF' > /etc/lighttpd/lighttpd.conf
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
EOF

service lighttpd restart
mkdir -p /var/www/git
chown -R www-data:www-data /var/www

# テスト用
git init --bare /var/www/git/hello.git
chown -R www-data:www-data /var/www/git

cd /tmp
git clone http://localhost/git/hello.git
cd hello
echo hello > README.md
git add .
git config --global user.name "git"
git config --global user.email "git@localhost"
git commit -m "first commit"
git push origin master

