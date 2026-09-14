# ollama

Debian 13 (trixie) への Ollama 手動インストール手順
nspawnコンテナ


## 1. バイナリのダウンロードと展開

回線の切断（タイムアウト）に強い `wget -c` を使用してアーカイブをダウンロードし、`/usr/local` に展開します。

```bash
# 必要パッケージのインストール
apt update && apt install -y wget zstd

# アーカイブのダウンロード（中断しても -c で再開可能）
wget -c https://ollama.com/download/ollama-linux-amd64.tar.zst

# /usr/local へ展開
tar --zstd -xvf ollama-linux-amd64.tar.zst -C /usr/local

# インストールファイルの削除
rm ollama-linux-amd64.tar.zst
```

## 2. 専用ユーザーの作成

Ollama を実行するための専用システムユーザー・グループを作成します。

```bash
useradd -r -s /bin/false -m -d /usr/share/ollama ollama

# ディレクトリの所有者を設定
chown ollama:ollama /usr/share/ollama
```

> 各オプションの意味
### `-r` (system)
- **システムアカウント**としてユーザーを作成します
- システムアカウントは通常のユーザーとは異なり:
  - UIDが通常1000未満（ディストリビューションによる）
  - `/etc/login.defs` の設定で管理される
  - パスワードロック状態で作成される
  - 一般にサービスやデーモン用

### `-s /bin/false` (shell)
- ログインシェルを `/bin/false` に設定
- `/bin/false` は常に失敗（exit code 1）を返すプログラム
- **このユーザーでのログインを事実上不可能**にする
- サービス専用アカウントのセキュリティ対策として一般的

### `-m` (create-home)
- ホームディレクトリを**自動作成**する
- `-d` で指定したパスにディレクトリを作成

### `-d /usr/share/ollama` (home-dir)
- ホームディレクトリのパスを `/usr/share/ollama` に指定
- Ollamaのモデルデータなどをここに保存する想定


## 3. systemd サービスの設定

バックグラウンドで自動起動させるために Service ファイルを作成し、起動します。

```bash
# ユニットファイルの作成
cat << 'EOF' > /etc/systemd/system/ollama.service
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=default.target
EOF

# systemd 読み込みとサービス有効化・起動
systemctl daemon-reload
systemctl enable --now ollama

# ステータス確認
systemctl status ollama
```

## 4. 動作確認

モデルをダウンロードして実行します。

```bash
# モデルのテスト実行
ollama run qwen3.5:0.8b --verbose --think=false "Hello!"
```

```
root@trixie-01:~# grep -rI "qwen" /usr/share/ollama
/usr/share/ollama/.ollama/models/blobs/sha256-b14c6eab49f986e99b2daf9cedac5183c74d4f5ce2585ebb52b8492778adec39:{"model_format":"gguf","model_family":"qwen35","model_families":["qwen35"],"model_type":"873.44M","file_type":"Q8_0","renderer":"qwen3.5","parser":"qwen3.5","requires":"0.17.1","architecture":"amd64","os":"linux","rootfs":{"type":"layers","diff_ids":["sha256:afb707b6b8fac6e475acc42bc8380fc0b8d2e0e4190be5a969fbf62fcc897db5","sha256:9be69ef463066202c1b1bd299aaf42bad370a01ba4b40d293617859720776c17","sha256:9371364b27a52acac9d87f88bd93c9db1174d8d6ec57f6888925cdc1788871ff"]}}
```

```
root@trixie-01:~# cat /usr/share/ollama/.ollama/models/manifests/registry.ollama.ai/library/qwen3.5/0.8b | jq .
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
  "config": {
    "mediaType": "application/vnd.docker.container.image.v1+json",
    "digest": "sha256:b14c6eab49f986e99b2daf9cedac5183c74d4f5ce2585ebb52b8492778adec39",
    "size": 476
  },
  "layers": [
    {
      "mediaType": "application/vnd.ollama.image.model",
      "digest": "sha256:afb707b6b8fac6e475acc42bc8380fc0b8d2e0e4190be5a969fbf62fcc897db5",
      "size": 1036034688
    },
    {
      "mediaType": "application/vnd.ollama.image.license",
      "digest": "sha256:9be69ef463066202c1b1bd299aaf42bad370a01ba4b40d293617859720776c17",
      "size": 11354
    },
    {
      "mediaType": "application/vnd.ollama.image.params",
      "digest": "sha256:9371364b27a52acac9d87f88bd93c9db1174d8d6ec57f6888925cdc1788871ff",
      "size": 65
    }
  ]
}
```
