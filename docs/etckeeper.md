---
title: etckeeper
description: Virsion control for etc
updated: 2026-01-28
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

```

初期設定
```sh
$ sudo etckeeper init

$ sudo etckeeper commit "Initial commit"
[master 27b02e7] Initial commit
 Author: debian <debian@c2>
 1 file changed, 17 insertions(+)
```

確認
```sh
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

ローカルgitにpushすればいいだろう

