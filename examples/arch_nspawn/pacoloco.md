# pacoloco

現在はpacman標準パッケージにある
```
sudo pacman -S pacoloco
```

設定ファイルほぼデフォルト、ミラーは日本の
```
[root@arch-01 ~]# cat /etc/pacoloco.yaml
cache_dir: /var/cache/pacoloco
port: 9129
download_timeout: 3600 ## downloads will timeout if not completed after 3600 sec, 0 to disable timeout
purge_files_after: 2592000 ## purge file after 30 days
set_timestamp_to_logs: true ## uncomment to add timestamp, useful if pacoloco is being ran through docker

repos:
  archlinux:
    urls: ## add or change official mirror urls as desired, see https://archlinux.org/mirrors/status/
      - http://jp.mirrors.cicku.me/archlinux
      - http://mirror.aria-on-the-planet.es/archlinux

prefetch: ## optional section, add it if you want to enable prefetching
 cron: 0 0 3 * * * * ## standard cron expression (https://en.wikipedia.org/wiki/Cron#CRON_expression) to define how frequently prefetch, see https://github.com/gorhill/cronexpr#implementation for documentation.
```

設定適用
```
systemctl enable --now pacoloco
```

コンテナ自身のクライアント設定
```
[root@arch-01 ~]# cat /etc/pacman.d/mirrorlist
# pacoloco
Server = http://localhost:9129/repo/archlinux/$repo/os/$arch
```
> 他のクライアントも同様に
> 例:
>   Server = http://pacoloco.local:9129/repo/archlinux/$repo/os/$arch


何か試しにインストール
```
pacman -Syyu
pacman -S git curl

# キャッシュが作られたか確認
ls -l /var/cache/pacoloco/pkgs/archlinux/core/os/x86_64/

# pacoloco のログ
journalctl -u pacoloco
```

回線安定時に、使いそうなパッケージをあらかじめダウンロード
```
pacman -Syw --noconfirm \
  git \
  curl \
  arch-install-scripts \
  debootstrap \
  systemd-container \
  dosfstools \
  e2fsprogs \
  openssh \
  sudo \
  vim \
  base \
  base-devel
```

