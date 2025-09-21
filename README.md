---
title: "nspawn-lab"
description: "Container Management Scripts with systemd-nspawn"
tags:
  - nspawn
  - container
  - shellscript
repository: "https://github.com/tomato-tom/nspawn-lab"
created: "2025-09-14"
updated: "2025-09-21"
---
# nspawnコンテナのスクリプト

コンテナ操作のコマンドをラップしたスクリプト
- systemd-nspawn
- systemd-run
- machinectl


### コンテナ
- base rootfs作成
- コンテナ作成・実行・停止・削除
- コンテナのリスト・情報
- 複数のコンテナを組み合わせるスクリプトのサンプル


### ネットワーク
- ブリッジ、netns、veth
- ネットワーク情報表示、保存、復元


### スクリプト

```mermaid
flowchart TD
    %% メインスクリプト
    PAW["paw.sh<br>main script"]:::mainScript
    
    %% マネジメント層スクリプト
    CONTAINER["container.sh<br>container management"]:::management
    IMAGE["container_image.sh<br>image management"]:::management
    BRIDGE["bridge.sh<br>layer 2 network management"]:::management
    IPROUTE["iproute.sh<br>IP address and routing management"]:::management
    
    %% 低レベルネットワークスクリプト
    VETH[veth.sh]:::network
    NETNS[netns.sh]:::network
    
    %% 関係定義
    PAW --> CONTAINER
    PAW --> IMAGE
    PAW --> BRIDGE
    PAW --> IPROUTE
    CONTAINER --> IMAGE
    BRIDGE --> VETH
    BRIDGE --> NETNS
    BRIDGE --> IPROUTE

    %% スタイル定義
    classDef mainScript fill:#ffebee,stroke:#d32f2f,stroke-width:2px,color:#b71c1c
    classDef management fill:#e3f2fd,stroke:#1976d2,stroke-width:1.5px,color:#0d47a1
    classDef network fill:#e8f5e9,stroke:#388e3c,stroke-width:1.5px,color:#1b5e20
```
