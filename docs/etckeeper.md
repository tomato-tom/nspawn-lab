---
title: etckeeper
description: Virsion control for etc
updated: 2026-02-17
status: done
tags:
- virsion-control
- etc
- configuration
---
# etckeeper

/etcのバージョン管理ツール
Git をバックエンドに使い、**設定ファイルの所有者・パーミッション・パッケージ更新との連携**など `/etc` 向けに最適化されている

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

初期設定
```sh
$ sudo etckeeper init

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

## ローカルgitにpushすればいいだろう

リモートgit server
- host: git-server
- user: user

```
# リモートリポジトリ作成
ssh git-server git init --bare /srv/git/server1-etc.git

# リモートリポジトリ追加
# リモートのrootパスワードない場合はユーザー指定必要ある
sudo git -C /etc remote add origin user@git-server:/srv/git/server1-etc.git

# 確認
sudo git -C /etc remote -v

# push
sudo git -C /etc push -u origin master
```

複数サーバーの設定どうしよう、ブランチ分けるか、それぞれリポジトリにするか
だいたい同じ設定多いからテンプレートをmasterに置いて、それぞれbranchでいいか

