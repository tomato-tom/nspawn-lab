---
title: nspawn markmap
updated: 2026-01-28
status: draft
tags:
- systemd-nspawn
- markdown-mindmap
markmap:
  colorFreezeLevel: 2
---
## 特徴
- systemd依存
- OSぽいコンテナ

## 用途
- 開発・テスト
- サーバー
- CI/CD

## 主要ツール

### コンテナ管理
- systemd-nspawn
- machinectl

### ネットワーク管理
- systemd-networkd
  - 設定ファイルで永続的な設定
  - machinectl/systemd-nspawn の一部機能に依存
- iproute2
  - コマンド・スクリプトでの設定
  - 一時的な設定向け
- nftables
  - NAT
  - パケットフィルタリング
  - machinectl/systemd-nspawn の一部機能に依存

### イメージ作成
- debootstrap: debian, ubuntu
- pacstrap: Archlinux
- dnf: Fedora
- mkosi: 各種ディストリ

## ファイルシステム
### ローカルファイルシステム  
- ext4  
  - デフォルトの標準ファイルシステム
- XFS  
  - 大容量ファイル・高スループット向け
- Btrfs  
  - スナップショット、サブボリューム、圧縮
- ZFS  
  - データ整合性・スケーラビリティ
### 論理ボリューム管理
- LVM (Logical Volume Manager)  
  - 物理ストレージを柔軟に管理

### ネットワーク/分散ファイルシステム  
- NFS (Network File System)  
  - シンプルなファイル共有
- CephFS  
  - 分散ストレージ向け
- GlusterFS  
  - スケーラブルな分散ファイルシステム

### その他のファイルシステム
- tmpfs
  - メモリ上に一時的なコンテナ作成
- SquashFS  
  - 圧縮された読み取り専用ファイルシステム（Live CD/Dockerイメージなど）
- OverlayFS  
  - 複数のレイヤーを重ねたファイルシステム（Docker/コンテナで標準利用）
- raw
  - VMで使用可能

## 参考
- man machinectl
- man systemd-nspawn

