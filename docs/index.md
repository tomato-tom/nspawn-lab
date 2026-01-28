---
title: index
updated: 2026-01-28
status: draft
tags:
- systemd-nspawn
- docs
---
# 目次

### 基本操作
- 01-getting-started-nspawn.md
    - ツールのインストール
    - コンテナイメージの作成
    - 起動
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
        - コンテナ内スクリプト実行
        - 各コンテナの情報表示
    - ネットワーク
        - ホストのネットワーク
        - 自動的なネットワーク、要systemd-networkd, systemd-resolved
        - systemd-networkd
    - ファイルシステム
        - ホストのディレクトリをマウント
        - overlayfs
    - リソース制限
        - CPU/Memory制限
    - 環境変数

### ネットワーク
- nspawn-network.md
    - bridge作成
    - vethペア接続
    - 静的IPアドレス
    - NAT
    - DNS
- network-mangement-tools.md
    - iproute2
    - systemd-networkd

### システム管理
- nspawn-systemd-integration.md
- nspawn-resource-control.md
- nspawn-cgroups.md
- nspawn-journal-logging.md
- nspawn-boot-options.md

### セキュリティ
- nspawn-security-hardening.md
- nspawn-selinux.md
- nspawn-capabilities.md
- nspawn-readonly-containers.md
- nspawn-user-namespace.md

### 各種設定
- nspawn-custom-rootfs.md
- nspawn-overlayfs.md
- nspawn-btrfs-integration.md
- nspawn-multi-arch.md
- nspawn-pxeboot.md

### トラブルシューティング
- nspawn-debugging.md
- nspawn-common-errors.md
- nspawn-boot-failures.md
- nspawn-network-troubleshooting.md

