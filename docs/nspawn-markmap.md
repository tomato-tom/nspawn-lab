---
title: nspawn
markmap:
  colorFreezeLevel: 2
---

## 特徴
- 高機能なchroot
- 軽量コンテナ
- systemdサービス

## 用途
- 開発・テスト環境
- 軽量サーバー
- CI/CD

## 主要ツール

### コンテナ管理
- systemd-nspawn
- machinectl

### ネットワーク管理
- systemd-networkd
  - 永続的な設定
  - machinectl/systemd-nspawn の一部機能に依存されてる
- iproute2
  - コマンド・スクリプトでの設定
  - 一時的な設定向け
- nftables
  - NAT
  - パケットフィルタリング

### イメージ作成
- debootstrap: debian, ubuntu
- pacstrap: Archlinux
- dnf: Fedora
- mkosi: 各種ディストリ

## ファイルシステム
### ローカルファイルシステム  
- ext4  
  - デフォルトの標準ファイルシステム、安定性と互換性重視
- XFS  
  - 大容量ファイル・高スループット向け（例：データベース、ストレージサーバー）
- Btrfs  
  - 先進機能（スナップショット、サブボリューム、圧縮）
- ZFS  
  - データ整合性・スケーラビリティに優れる（大規模ストレージ向け）
- F2FS  
  - SSD/フラッシュストレージ向けに最適化

### 論理ボリューム管理
- LVM (Logical Volume Manager)  
  - 物理ストレージを柔軟に管理

### ネットワーク/分散ファイルシステム  
- NFS (Network File System)  
  - シンプルなファイル共有
- CephFS  
  - 分散ストレージ向け（クラウド/大規模ストレージ）
- GlusterFS  
  - スケーラブルな分散ファイルシステム（複数サーバーでストレージプール化）

### 4. 特殊用途/軽量ファイルシステム  
- SquashFS  
  - 圧縮された読み取り専用ファイルシステム（Live CD/Dockerイメージで利用）
- OverlayFS  
  - 複数のレイヤーを重ねたファイルシステム（Docker/コンテナで標準利用）

### 用途別選択例  
| 用途 | 推奨ファイルシステム |  
|------|---------------------|  
| デスクトップ/通常サーバー | ext4（安定性）、XFS（パフォーマンス） |  
| 大容量ストレージ/データ整合性 | ZFS、Btrfs |  
| SSD/フラッシュストレージ | F2FS |  
| コンテナ | OverlayFS、Btrfs |  
| ネットワーク共有 | NFS（小規模）、CephFS/GlusterFS（大規模） |  
| 読み取り専用（Live OS） | SquashFS |  


## 参考リンク
- [systemd-nspawn](https://www.freedesktop.org/software/systemd/man/latest/systemd-nspawn.html)
- [machinectl](https://www.freedesktop.org/software/systemd/man/latest/machinectl.html#)

