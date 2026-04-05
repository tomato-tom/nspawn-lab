# APT Cacherのスクリプト

## キャッシュ自動更新

現状CF-SZ6-2 c2に特化、汎用的にする？

systemdファイル
acng-prefetch.service
acng-prefetch.timer

実行ファイル
aptcacher_prefetch.sh

サーバー（コンテナ）に必要なファイル配置
deploy.sh

## インストールしたパッケージのリスト

ミニマルdebootstrapから追加のインストールする場合に参照するリスト
今の所全部bookworm
```
# debootstrap minbase
bookworm_minbase_packages.list

# apt-cacher-ng コンテナのパッケージ
acng_container_packages.list
acng_additional.txt  # minbaseとの差分


# nspawnコンテナ・ホストのパッケージ
debian_installed_packages_2026-04-05.list
bookworm_baremetal_additional_packages.txt # minbaseとの差分
```
ミニマル構築後に追加のインストール

## その他必要な初期設定

ネットワーク・FW
ユーザー設定
...
