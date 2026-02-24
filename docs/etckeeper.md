---
title: etckeeper
description: Virsion control for etc
updated: 2026-02-24
status: done
tags:
- virsion-control
- etc
- configuration
---
# etckeeper

/etcのバージョン管理ツール
Git をバックエンドに使い、設定ファイルの所有者・パーミッション・パッケージ更新との連携など `/etc` 向けに最適化されている

インストール
```sh
$ sudo apt install -y etckeeper git

# 以下のようなリポジトリ作成される
Initialized empty Git repository in /etc/.git/
[master (root-commit) f27e1e8] Initial commit
 Author: debian <debian@ay321s.ay321s.local>
 1028 files changed, 37675 insertions(+)
 create mode 100755 .etckeeper
 create mode 100644 .gitignore
 create mode 100644 .resolv.conf.systemd-resolved.bak
 create mode 100755 X11/Xreset
 create mode 100644 X11/Xreset.d/README
 create mode 100644 X11/Xresources/x11-common

 ...

```

初期設定は特にやることないけど
```sh
# 確認
$ sudo etckeeper vcs status
On branch master
nothing to commit, working tree clean

$ sudo etckeeper vcs log --oneline
27b02e7 (HEAD -> master) Initial commit
195c3c3 daily autocommit
```

設定ファイル、とりあえずデフォルトでOK
```sh
$ ls /etc/etckeeper/
commit.d  daily  etckeeper.conf  init.d  list-installed.d  post-install.d  pre-commit.d  pre-install.d  unclean.d  uninit.d  update-ignore.d  vcs.d
```


## ローカルgitサーバーにpush

設定例
リモートgit server
- host: git-server
- user: ubuntu

サーバーごとにブランチわけ
branch:
- master
- server/sv1
- server/sv2
- server/sv3

```
# gitサーバーにリモートリポジトリ作成
ssh git-server git init --bare /srv/git/etc.git

# 手元にリモートリポジトリ追加
# リモートのrootパスワードない場合はユーザー指定必要ある
sudo etckeeper vcs /etc remote add origin ubuntu@git-server:/srv/git/etckeeper.git
sudo etckeeper vcs /etc remote -v

# branch作成
sudo etckeeper vcs /etc branch origin server/sv1
sudo etckeeper vcs /etc switch server/sv1

# push
sudo etckeeper vcs /etc push -u origin server/sv1
```
> テンプレートをmasterに置いとけばいいんじゃないか

自動push
/etc/etckeeper/etckeeper.conf
```
# To push each commit to a remote, put the name of the remote here.
# (eg, "origin" for git). Space-separated lists of multiple remotes
# also work (eg, "origin gitlab github" for git).
PUSH_REMOTE="origin"
```

