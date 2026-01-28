---
title:  Chrony
description: Setup Chrony NTP server
update: 2026-01-28
status: draft
tags:
- ntp
- chrony
- debian
---

# Chrony NTP server

インストール
```
sudo apt install -y chrony
```

以上で起動してデフォルト設定完了
デフォルトNTP参照でいいなら、このままでもOK


## サーバー

外部のNTPサーバーを優先的に参照する
ローカルも相互参照で冗長化(LBなど不要)
デフォルト設定されてるのdebian.poolもそのまま利用
デフォルト・ポートUDP 123

/etc/chrony/chrony.conf
```
# NICTの公開NTPサーバー
server ntp.nict.jp iburst prefer

# Use Debian vendor zone.
pool 2.debian.pool.ntp.org iburst

# ローカルNTPサーバーを相互参照
# ntp-2
peer 10.0.0.102
# ntp-3
peer 10.0.0.103
...

# ログを有効に
# Uncomment the following line to turn logging on.
log tracking measurements statistics

# NTPサーバーとしてLAN内から接続許可
allow 10.0.0.0/24

# 外部サーバーと接続できない場合でもローカルにフォールバックでstratum 10として動作させる設定
# 複数構成のローカルNTPサーバーあるなら不要?
#local stratum 10
```
> コメントは設定と別の行に書く必要ある、同一行は`faild`に

設定適用
```
sudo systemctl restart chrony
```

確認
```
debian@sz6-1:~$ chronyc activity
200 OK
7 sources online
0 sources offline
0 sources doing burst (return to online)
0 sources doing burst (return to offline)
2 sources with unknown address

debian@sz6-1:~$ chronyc sources
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^* 2001:ce8:78::2                1  10   377   158  -1532us[-1619us] +/- 9618us
^- ntp-2                         2  10   377   446   +534us[ +448us] +/- 8731us
^- ntp-3                         2   6   377    16   -167us[ -167us] +/- 3898us
^- 2001:19f0:7001:4fb1:5400>     2  10   377   626   -829us[ -915us] +/-   46ms
^- ntp.azu15.jp                  2  10   377   681   +750us[ +665us] +/-   20ms
^- time.cloudflare.com           3  10   377   207  +3175us[+3089us] +/-   56ms
^- KD059129234117.ppp-bb.di>     2  10   377   860   +348us[ +264us] +/- 7192us
```


## クライアント

今回はローカルNTPサーバーのみ参照するように設定
/etc/chrony/chrony.conf を編集
```
# ローカルサーバーを追記
# Local NTP server
server 10.0.0.101 iburst
server 10.0.0.102 iburst
server 10.0.0.103 iburst

# 外部NTPサーバーをコメントアウト
# Use Debian vendor zone.
#pool 2.debian.pool.ntp.org iburst
# 各OSごとにデフォルトの外部NTP参照先あるみたい

# コメントアウト解除でロギング
# Uncomment the following line to turn logging on.
log tracking measurements statistics
```

設定適用
```
sudo systemctl restart chrony
```

確認
```
$ chronyc
chrony version 4.3
Copyright (C) 1997-2003, 2007, 2009-2022 Richard P. Curnow and others
chrony comes with ABSOLUTELY NO WARRANTY.  This is free software, and
you are welcome to redistribute it under certain conditions.  See the
GNU General Public License version 2 for details.

chronyc> activity
200 OK
3 sources online
0 sources offline
0 sources doing burst (return to online)
0 sources doing burst (return to offline)
0 sources with unknown address
chronyc> sources
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^+ ntp-2                         2   6   177    47   +459us[ +459us] +/- 8191us
^* ntp-3                         2   6   177    47   -190us[ -176us] +/- 4000us
^+ ntp-1                         2   6   177    47    +20us[  +20us] +/- 8439us
chronyc> quit
```
３つのローカルNTPサーバーを参照できてる

システムクロック詳細
```
$ chronyc tracking
Reference ID    : 0A000066 (ntp-2)
Stratum         : 3
Ref time (UTC)  : Sat Dec 20 17:13:11 2025
System time     : 0.000067670 seconds slow of NTP time
Last offset     : +0.000064511 seconds
RMS offset      : 0.000101831 seconds
Frequency       : 14.210 ppm slow
Residual freq   : +0.025 ppm
Skew            : 0.845 ppm
Root delay      : 0.007449249 seconds
Root dispersion : 0.000532746 seconds
Update interval : 64.4 seconds
Leap status     : Normal
```

> `ntp-2` から時刻を取得中
> Reference ID : 0A000066 = 10.0.0.102 = ntp-2
> 各項目の意味
- Reference ID:     時刻を取得しているNTP サーバーの IP/ホスト名
- Stratum: 階層：   NICT（Stratum 1）→ `ntp-2`（Stratum 2）→ クライアント（Stratum 3）
- Ref time (UTC):   最後に親サーバーと時刻を照合した時刻（UTC）
- System time:      クライアントのシステム時刻がNTPサーバー時刻より67.7 μs遅れている → 良好
- Frequency:        システムクロックの ドリフト率（1秒あたり 14.21 μs 遅れる）
- Residual freq:    chrony が補正した後の 残りドリフト → ほぼゼロで理想に近い
- Update interval:  次回同期までの間隔（自動調整中）

> man chronyc

