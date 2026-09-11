# apt-cacherのインストールとセットアップ

```
# server
sudo apt install apt-cacher-ng

# サーバー自身のキャッシュも取得する設定
echo 'Acquire::http::Proxy "http://localhost:3142";' | sudo tee /etc/apt/apt.conf.d/02proxy
```

各クライアントでApt-Cachサーバーに向ける
```
# client
echo 'Acquire::http::Proxy "http://apt-cacher.local:3142";' | sudo tee /etc/apt/apt.conf.d/02proxy
```

