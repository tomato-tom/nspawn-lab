# nspawn script

nspawnコンテナの雑多なスクリプトとメモ

## ディレクトリ構造

libは解体して、snippetsに入れよう
```
.
├── config
│   ├── custom.conf
│   ├── custom-nat-template.nft
│   ├── default.conf
│   ├── default_container.conf
│   └── example_nspawn.yml
├── docs
│   ├── apt_cacher.md
│   ├── chrony.md
│   ├── etckeeper.md
│   ├── getting-started-nspawn.md
│   ├── index.md
│   ├── lighttpd_rootfs_server.md
│   └── nspawn-markmap.md
├── examples
│   ├── ansible
│   │   └── ansible.md
│   ├── apt-cacher
│   │   ├── prefetch
│   │   │   ├── acng_additional.txt
│   │   │   ├── acng_container_packages.list
│   │   │   ├── acng-prefetch.service
│   │   │   ├── acng-prefetch.timer
│   │   │   ├── apt-cacher.nspawn
│   │   │   ├── aptcacher_prefetch.sh
│   │   │   ├── bookworm_baremetal_additional_packages.txt
│   │   │   ├── bookworm_minbase_packages.list
│   │   │   ├── debian_installed_packages_2026-04-05.list
│   │   │   ├── deploy.sh
│   │   │   ├── notes.md
│   │   │   └── systemd
│   │   │       ├── 80-container-host0.network
│   │   │       ├── br0.netdev
│   │   │       └── br0.network
│   │   └── setup.md
│   ├── arch_nspawn
│   │   ├── all.json
│   │   ├── apt.json
│   │   ├── arch_firsttime_setup.sh
│   │   ├── default.json
│   │   ├── empty.json
│   │   ├── fix_wifi.sh
│   │   ├── host_benchmark.sh
│   │   ├── notes.md
│   │   ├── ollama.md
│   │   ├── pacoloco.md
│   │   ├── setup_script.md
│   │   ├── setup.sh
│   │   ├── test.json
│   │   ├── test_prompt.md
│   │   ├── trixie_firsttime_setup.sh
│   │   ├── trixie.json
│   │   ├── update_all.sh
│   │   └── zram_host_results.csv
│   ├── debian_install
│   │   ├── first-boot-setup.service
│   │   ├── first-boot-setup.sh
│   │   ├── install_debian.sh
│   │   └── notes.md
│   └── git_server
│       ├── lighttpd.conf
│       ├── nftables.conf
│       ├── notes.md
│       └── setup.sh
├── lib
│   ├── common.sh
│   ├── container
│   │   ├── container_image.sh
│   │   ├── container.sh
│   │   └── container_state.sh
│   ├── logger.sh
│   ├── query.sh
│   ├── setup_nspawn.sh
│   └── vnet
│       ├── bridge.sh
│       ├── netns.sh
│       ├── network.sh
│       └── veth.sh
├── notes.md
├── README.md
├── snippets
│   ├── assert.sh
│   ├── debian_static_address.sh
│   ├── map_functions.sh
│   ├── nat.sh
│   ├── parse_script.py
│   ├── run_unshare.sh
│   ├── show_network_info.sh
│   └── stop_unshare.sh
└── tests
    ├── logger_test.sh
    ├── test_bridge.sh
    └── test_veth.sh

16 directories, 78 files
