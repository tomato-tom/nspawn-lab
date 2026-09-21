# hsflowd
Debian Trixie 環境での `hsflowd` (host-sflow) インストール手順

## 依存パッケージのインストール
ビルドに必要なツールとライブラリをインストールします。
```bash
apt update
apt install -y wget build-essential clang libpcap-dev libcurl4-openssl-dev pkg-config
```

## ソースコードの取得と展開

```
root@trixie-04:~# wget -qO- https://api.github.com/repos/sflow/host-sflow/tags | grep '"name"' | head -n 5
    "name": "v2.1.26-1",
    "name": "v2.1.25-6",
    "name": "v2.1.25-5",
    "name": "v2.1.25-4",
    "name": "v2.1.25-3",
```

最新の安定版タグ（例: `v2.1.26-1`）を使用します。
```bash
wget https://github.com/sflow/host-sflow/archive/refs/tags/v2.1.26-1.tar.gz
tar xzf v2.1.26-1.tar.gz
cd host-sflow-2.1.26-1
```

## ビルドとインストール
`clang` を使用してビルドし、システムにインストールします。
```bash
make
make install
```

## サービスの起動と有効化
systemd を使って自動起動設定を行い、サービスを開始します。
```bash
systemctl daemon-reload
systemctl enable --now hsflowd
```

## 動作確認
バージョン表示とステータス確認を行います。
```bash
hsflowd -v
systemctl status hsflowd
```


*   **設定ファイル**: `/etc/hsflowd.conf` に sFlow コレクタの IP アドレスなどを記述します。
*   **ログ確認**: 問題が発生した場合は `journalctl -u hsflowd` でログを確認できます。
*   **ファイアウォール**: sFlow データを送受信する場合は、UDP 6343 ポート等の開放が必要です。
