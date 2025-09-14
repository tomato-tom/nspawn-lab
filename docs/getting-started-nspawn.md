# Getting Started nspawn

軽量コンテナnspawnを使ってみよう
とりあえずdebianのコンテナで

https://wiki.debian.org/nspawn
https://wiki.archlinux.jp/index.php/Systemd-nspawn


## 1. 動作環境の準備

```bash
sudo apt install debootstrap systemd-container -y
```

## 2. コンテナイメージの作成

`debootstrap`でDebian系の環境を作るのが手軽。

```bash
debootstrap --include=systemd,dbus stable /var/lib/machines/debian
```
> `/var/lib/machines`がデフォルトのイメージディレクトリ
> machinectlでやるにはsystemd,dbusを含めると扱いやすい

初回はビルドに時間かかる、次回以降はrootfsをコピーすれば早い。


## 3. コンテナの起動

作成したディレクトリを指定してコンテナを起動する。

```bash
sudo systemd-nspawn -M my-container
```

コンテナに入ったら、`hostnamectl`や`ip addr`などで環境を確認してみよう。

終了するときは
`exit`
Ctrl-] x3

-----

## 4. 便利コマンド

コンテナ内部で特定のコマンドを実行

```bash
sudo systemd-nspawn -M my-container /bin/echo "Hello from inside the container!"
```

