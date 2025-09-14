# 目次

### 基本操作
- 01-getting-started-nspawn.md
    - ツールのインストール
    - コンテナイメージの作成
    - コンテナの起動
    - コンテナを削除
- 02-nspawn-basic.md
    - 主要ツール
        - systemd-nspawn
        - machinectl
    - イメージの作成
        - debootstrap
        - pacstrap
        - dnf
    - ライフサイクル管理
        - 作成、実行、停止、削除
        - クローン
        - コンテナにログイン
        - ホストからコンテナ内スクリプト実行
        - コンテナのリスト表示
        - 各コンテナの情報表示
    - ネットワーク
        - ホストのネットワークをそのまま使用
        - 自動的なネットワーク、要systemd-networkd, systemd-resolved
    - ファイルシステム
        - ディレクトリバインドマウント（--bind=/path）
        - 読み込み専用マウント（--read-only）
    - リソース制限
        - CPU/Memory制限の基本（--cpu-shares, --memory=）
    - 環境変数の渡し方（--setenv=KEY=VALUE）

### ネットワーク
- nspawn-network.md
    - bridge作成
    - vethペア接続
    - ホスト、コンテナの静的IPアドレス設定
    - NAT
    - 動作確認
- network-mangement-tools.md
    - iproute2
    - systemd-networkd
    - networkmanager
    - netplan
- vlan.md
- custom-routing.md
- ipvlan-macvlan.md
- port-forwarding.md
- firewall.md
- network-monitering.md

### システム管理
- nspawn-systemd-integration.md
- nspawn-resource-control.md
- nspawn-cgroups.md
- nspawn-journal-logging.md
- nspawn-boot-options.md

### セキュリティ編
- nspawn-security-hardening.md
- nspawn-selinux.md
- nspawn-capabilities.md
- nspawn-readonly-containers.md
- nspawn-user-namespace.md

### 高度な設定編
- nspawn-custom-rootfs.md
- nspawn-overlayfs.md
- nspawn-btrfs-integration.md
- nspawn-multi-arch.md
- nspawn-pxeboot.md

### トラブルシューティング編
- nspawn-debugging.md
- nspawn-common-errors.md
- nspawn-boot-failures.md
- nspawn-network-troubleshooting.md

