#!/usr/bin/env python3
"""
nspawn コンテナ情報表示スクリプト
config/default.json からコンテナとブリッジの情報を読み込んで表示
"""

import json
import sys
from pathlib import Path


def load_config(config_path="config/default.json"):
    """設定ファイルを読み込む"""
    config_file = Path(config_path)
    if not config_file.exists():
        print(f"エラー: 設定ファイル '{config_path}' が見つかりません")
        sys.exit(1)
    
    with open(config_file, 'r', encoding='utf-8') as f:
        return json.load(f)


def display_bridges(bridges):
    """ブリッジ情報を表示"""
    print("\n" + "="*70)
    print("🌐 ブリッジ情報")
    print("="*70)
    
    for bridge in bridges:
        name = bridge.get('name', 'N/A')
        network = bridge.get('network', 'N/A')
        ip_address = bridge.get('ip_address', 'N/A')
        port_forwards = bridge.get('port_forwards', [])
        
        print(f"\n📡 {name}")
        print(f"   ネットワーク: {network}")
        print(f"   IPアドレス:   {ip_address}")
        
        if port_forwards:
            print(f"   ポートフォワード:")
            for pf in port_forwards:
                container = pf.get('container_name', 'N/A')
                host_port = pf.get('host_port', 'N/A')
                guest_port = pf.get('guest_port', 'N/A')
                protocol = pf.get('protocol', 'tcp')
                print(f"     - {container}: ホスト:{host_port} → ゲスト:{guest_port}/{protocol}")
        else:
            print(f"   ポートフォワード: なし")


def display_containers(containers):
    """コンテナ情報を表示"""
    print("\n" + "="*70)
    print("📦 コンテナ情報")
    print("="*70)
    
    for i, container in enumerate(containers, 1):
        name = container.get('name', 'N/A')
        role = container.get('role', 'N/A')
        bridge = container.get('bridge', 'N/A')
        ip_address = container.get('ip_address', 'N/A')
        dns = container.get('dns', 'N/A')
        proxy = container.get('proxy', 'なし')
        mount = container.get('mount', 'なし')
        
        print(f"\n{i}. 🖥️  {name}")
        print(f"   ロール:       {role}")
        print(f"   ブリッジ:     {bridge}")
        print(f"   IPアドレス:   {ip_address}")
        print(f"   DNS:          {dns}")
        print(f"   プロキシ:     {proxy}")
        if mount != 'なし':
            print(f"   マウント:     {mount}")


def display_summary(containers, bridges):
    """概要を表示"""
    print("\n" + "="*70)
    print("📊 概要")
    print("="*70)
    print(f"   ブリッジ数:   {len(bridges)}")
    print(f"   コンテナ数:   {len(containers)}")
    
    # ブリッジごとのコンテナ数
    print(f"\n   ブリッジ別コンテナ数:")
    bridge_counts = {}
    for container in containers:
        bridge = container.get('bridge', 'unknown')
        bridge_counts[bridge] = bridge_counts.get(bridge, 0) + 1
    
    for bridge_name, count in sorted(bridge_counts.items()):
        print(f"     - {bridge_name}: {count} コンテナ")


def main():
    """メイン関数"""
    # スクリプトのあるディレクトリを基準に設定ファイルを探す
    script_dir = Path(__file__).parent
    config_path = script_dir / "config/default.json"
    
    # コマンドライン引数で指定された場合
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
    
    config = load_config(config_path)
    
    bridges = config.get('bridges', [])
    containers = config.get('containers', [])
    
    # ヘッダー
    print("\n" + "█"*70)
    print("  nspawn コンテナ構成情報")
    print("  設定ファイル: " + str(config_path))
    print("█"*70)
    
    display_bridges(bridges)
    display_containers(containers)
    display_summary(containers, bridges)
    
    print("\n" + "="*70 + "\n")


if __name__ == "__main__":
    main()
