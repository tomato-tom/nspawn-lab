# ollama

Debian 13 (trixie) への Ollama 手動インストール手順


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
```


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
ollama run qwen3.5:0.8b
```

