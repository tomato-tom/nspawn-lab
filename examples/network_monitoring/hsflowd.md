# hsflowd
> https://sflow.net/

## インストール
Debian Trixie 環境での `hsflowd` (host-sflow) インストール手順

ビルドに必要なツールとライブラリをインストール
```bash
apt update
apt install -y wget build-essential clang libpcap-dev libcurl4-openssl-dev pkg-config
```

タグ一覧取得
```
root@trixie-04:~# wget -qO- https://api.github.com/repos/sflow/host-sflow/tags | grep '"name"' | head -n 5
    "name": "v2.1.26-1",
    "name": "v2.1.25-6",
    "name": "v2.1.25-5",
    "name": "v2.1.25-4",
    "name": "v2.1.25-3",
```

最新のタグ`v2.1.26-1`を使用してソースコードの取得と展開
```bash
wget https://github.com/sflow/host-sflow/archive/refs/tags/v2.1.26-1.tar.gz
tar xzf v2.1.26-1.tar.gz
cd host-sflow-2.1.26-1
```

ビルドとインストール
```bash
make
make install
```

クリーンアップ
```bash
rm -rf v2.1.26-1.tar.gz host-sflow-2.1.26-1
```

サービスの起動と有効化
```bash
systemctl daemon-reload
systemctl enable --now hsflowd
```

確認
```bash
hsflowd -v
systemctl status hsflowd
```

> 設定ファイル: `/etc/hsflowd.conf`
> ログ確認: `journalctl -u hsflowd`


## 設定

基本的な設定例 (`/etc/hsflowd.conf`)
```ini
# hsflowd configuration file
# http://sflow.net/host-sflow-linux-config.php
sflow {
  # Sampling rate (1 out of N packets)
  sampling = 100

  # Polling interval (seconds)
  polling = 1

  # Collector destination
  collector { ip=192.168.1.105 udpport=6343 }

  # Monitor host0 interface
  pcap { dev = host0 }
}
```

### 主な調整ポイント

| 項目           | 説明                         | 推奨値（実験用）       |
| :---           | :---                         | :---                   |
| `sampling`     | パケットのサンプリング間隔   | `100` 〜 `1000`        |
| `collector.ip` | データを受け取るサーバーのIP | 収集ツールのIP         |
| `pcap.dev`     | 監視対象のNIC                | `eth0` や `ens18` など |
| `polling`      | リソース統計の送信間隔       | `30` (秒)              |

### 設定後の反映
設定を変更したら、サービスを再起動

```bash
systemctl restart hsflowd
```

### 動作確認のコツ
設定したコレクタ側（例: `tcpdump -i any port 6343`）でパケットが届いているか確認
