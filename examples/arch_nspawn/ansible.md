# Ansible
> qwen生成

## 

trixie-02 controle node


Ansibleは、エージェント不要・SSH経由・YAML記述が特徴のIT自動化ツールです。設定管理、アプリデプロイ、インフラ構成の統一などに広く使われています。

---
### 🔧 1. インストール（コントロールノードで実行）
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install ansible
```
> 💡 補足：近年の `ansible` パッケージは **`ansible-core` + コレクション** のメタパッケージです。実行エンジンだけ欲しい場合は `pip install ansible-core` でも構いません。Python 3.9以降が推奨されます。

---
### 📁 2. 基本的なファイル構成
```
my-ansible/
├── inventory.ini      # 対象サーバー一覧
├── group_vars/        # グループ別変数
│   └── all.yml
├── site.yml           # Playbook（メイン）
└── roles/             # 再利用可能な構成単位（任意）
```

---
### 📝 3. インベントリファイルの作成
`inventory.ini`
```ini
[webservers]
web01 ansible_host=192.168.1.10
web02 ansible_host=192.168.1.11

[all:vars]
ansible_user=deploy
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```
- パスワード認証の場合は `ansible_password=` を追加するか、実行時に `--ask-pass` を使用
- SSH鍵認証が強く推奨されます

---
### 🚀 4. 最初のPlaybook作成
`site.yml`
```yaml
- name: Webサーバー初期設定
  hosts: webservers
  become: true  # sudo実行
  tasks:
    - name: パッケージキャッシュ更新 (Debian系)
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"

    - name: Nginxをインストール
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Nginxを有効化＆起動
      ansible.builtin.service:
        name: nginx
        enabled: true
        state: started
```
> 💡 モジュールは `名前空間.コレクション.モジュール` 形式（例：`ansible.builtin.package`）が公式推奨です。

---
### ⚡ 5. 実行コマンド
```bash
# 疎通確認
ansible -i inventory.ini all -m ping

# ドライラン（実際には適用せず、変更内容だけ表示）
ansible-playbook -i inventory.ini site.yml --check --diff

# 本番適用
ansible-playbook -i inventory.ini site.yml

# 特定タグのみ実行
ansible-playbook -i inventory.ini site.yml --tags "nginx"
```

---
### 📘 6. 重要なコンセプト
| 用語 | 説明 |
|------|------|
| **モジュール** | タスクの最小実行単位（`package`, `service`, `copy`, `template`, `user` など） |
| **Playbook** | モジュールを順に実行するYAMLファイル |
| **インベントリ** | 管理対象ホストとグループの定義 |
| **Roles** | タスク・変数・テンプレート・ハンドラを構造化した再利用単位 |
| **コレクション** | モジュール・プラグイン・ロールをパッケージ化した配布単位（Ansible Galaxyから入手） |

---
### ✅ 7. 実務向けベストプラクティス
1. **べき等性（Idempotency）を意識**：何度実行しても同じ状態になるよう書く
2. `--check --diff` で必ず確認してから適用
3. 変数は `group_vars/` や `host_vars/` に分離。Playbook内にハードコードしない
4. シークレットは `ansible-vault` で暗号化管理（`ansible-vault encrypt secret.yml`）
5. 構文チェックに `ansible-lint` を導入（`pip install ansible-lint`）
6. モジュール名は完全修飾名（`ansible.builtin.xxx`）を使用
7. 大きな構成は `roles/` または `collections/` で分割

---
### 📚 学習・参考リソース
- 公式ドキュメント：https://docs.ansible.com/ansible/latest/
- コレクション検索：https://galaxy.ansible.com/
- `ansible-doc <モジュール名>` でローカルヘルプ確認可能
- 実践入門書：『Ansible実践ガイド』やRed Hat公式トレーニングが体系的です

---
💡 **次のステップ提案**
- 既存サーバーで `ansible -m setup all` を実行し、自動取得できるファクト変数を把握する
- CI/CDパイプラインに `ansible-playbook --check` を組み込んで構成ドリフトを防止する

