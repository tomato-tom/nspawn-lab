# Systemd Nspawn Script

bashスクリプト・メイン
Ansibleなどで管理?

## ディレクトリ構造

```
.
├── bin
│   └── paw.sh
├── config
│   ├── custom.conf
│   ├── custom-nat-template.nft
│   ├── default.conf
│   ├── default_container.conf
│   └── example_nspawn.yml
├── docs
│   ├── getting-started-nspawn.md
│   ├── index.md
│   └── nspawn-markmap.md
├── lib
│   ├── common.sh
│   ├── logger.sh
│   ├── query.sh
│   ├── setup_nspawn.sh
│   ├── container
│   │   ├── container_image.sh
│   │   └── container.sh
│   └── vnet
│       ├── bridge.sh
│       ├── netns.sh
│       ├── network.sh
│       └── veth.sh
├── logs
│   └── script.log
├── Makefile
├── misc
│   ├── assert.sh
│   ├── debian_static_address.sh
│   ├── map_functions.sh
│   ├── nat.sh
│   ├── parse_script.py
│   └── show_network_info.sh
├── README.md
└── tests
    ├── logger_test.sh
    ├── logs
    │   ├── test.log
    │   ├── test.log.1
    │   ├── test.log.2
    │   └── test.log.3
    ├── test_bridge.sh
    └── test_veth.sh
```


## 設定ファイルテンプレートの例

**1. ラボ環境用 (lab.yaml)**
- default
- root:rootでシンプルに
- カスタムネットワーク
- 一時的なストレージ設定
- 自動クリーンアップ設定
- リソース制限

**2. 開発環境用 (dev.yaml)**
- sudoユーザー追加
- リソース制限
- ソースコードのバインドマウント
- デバッグ用のケーパビリティ追加
- ポートフォワーディング多数

**3. 本番環境用 (prod.yaml)**
- リソース制限
- 読み取り専用ファイルシステム
- セキュリティ制限強化
- 最小限のケーパビリティ

## 進化の流れ
1. まずは基本的なテンプレートを提供
2. 利用パターンを分析
3. 使いながら調整


### テンプレート

lab.yaml - ラボ環境用
```yaml
container:
  name: "lab-container"
  description: "実験環境"
  user:
    name: "root"
    pasword: "root"

network:
  type: "none"

storage:
  ephemeral: true
  tmpfs: true
  binds:
    - "/tmp"

resources:
  memory: "8G"
  cpus: 8
```

dev.yaml - 開発環境用
```yaml
container:
  name: "dev-container"
  description: "開発用環境"
  user:
    name: admin
    pasword:********  # .env等で

network:
  type: "nat"
  ports:
    - "8000~8999"

storage:
  binds:
    - "$(pwd):/app"

resources:
  memory: 32
  cpus: 16
```

prod.yaml - 本番環境用
```yaml
container:
  name: "prod-container"
  description: "本番用環境"
  user: "app"
  password: ""  # vaultなど使用

network:
  type: "bridge"
  interface: "prod-br0"
  ports:
    - "443:8443"
    - "80:8080"

storage:
  ephemeral: false
  binds:
    - "/opt/app:/app:ro"
    - "/var/log/app:/var/log/app"
    - "/etc/ssl/certs:/etc/ssl/certs:ro"

resources:
  memory: 4
  cpus: 2
  memory_swap: 4

security:
  level: "strict"
  user_ns: true
  private_network: false
  capabilities_drop: ["ALL"]
  capabilities_add: ["NET_BIND_SERVICE", "SETUID", "SETGID"]
  readonly_paths: ["/", "/usr", "/lib", "/bin", "/sbin"]
  readwrite_paths: ["/tmp", "/var/log/app", "/run"]
  no_new_privileges: true
  
logging:
  journal: true
  syslog: true
  audit: true

health:
  auto_restart: true
  watchdog: 30s
  max_restart: 5
```
