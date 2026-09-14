#!/bin/bash
# lib/container/container_state.sh
# 状態管理
# root権限不要

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../.. && pwd)"

if source "$ROOTDIR/lib/common.sh"; then
    load_logger $0
else
    echo "Failed to source common.sh" >&2
    exit 1
fi

STATUS_FILE="$ROOTDIR/var/status.json"

# 使用方法を表示
usage() {
    echo "Usage: $0 <command> [args...]"
    echo "Commands:"
    echo "  add <name>                      - コンテナを追加"
    echo "  remove <name>                    - コンテナを削除"
    echo "  get <name> [field]              - コンテナ情報を取得"
    echo "  update <name> <field> <value>   - コンテナ情報を更新"
    echo "  list                            - 全コンテナ一覧"
    echo "  exists <name>                   - コンテナ存在チェック"
}

# JSONファイルの初期化
init_json() {
    if [ ! -f "$STATUS_FILE" ]; then
        echo '{"containers":{}}' > "$STATUS_FILE"

        if [ -n "$SUDO_USER" ]; then
            chown $SUDO_USER:$SUDO_USER "$STATUS_FILE"
        fi
    fi
}

# ファイル更新
jq_inplace() {
    local temp_file=$(mktemp)
    jq "$@" > "$temp_file" && mv "$temp_file" "$STATUS_FILE"
    local result=$?
    rm -f "$temp_file"
    return $result
}

# コンテナ情報追加
add_container_status() {
    local name="$1"
    
    if [ -z "$1" ]; then
        return 1
    fi
    
    local created=$(date -Iseconds)
    
    jq_inplace --arg name "$name" \
          --arg created "$created" \
          '.containers[$name] = {
              "description": ("Container " + $name),
              "created": $created
          }' "$STATUS_FILE"
}

# コンテナ情報削除
remove_container_status() {
    local name="$1"
    local field="$2"
    
    if [ -n "$field" ]; then
        jq_inplace --arg name "$name"  --arg field "$field" \
              'del(.containers[$name][$field])' "$STATUS_FILE"
    elif [ -n "$name" ]; then
        jq_inplace --arg name "$name" \
              'del(.containers[$name])' "$STATUS_FILE"
    else
        jq_inplace '.containers = {}' "$STATUS_FILE"
    fi
}

# コンテナ情報取得
get_container_status() {
    local name="$1"
    local field="$2"
    
    if [ -n "$field" ]; then
        # 特定フィールドを取得
        jq -r --arg name "$name" \
              --arg field "$field" \
              '.containers[$name][$field] // empty' "$STATUS_FILE"
    elif [ -n "$name" ]; then
        # コンテナ情報を取得
        jq -r --arg name "$name" \
           '.containers[$name] // empty' "$STATUS_FILE"
    else
        jq -r '.containers' "$STATUS_FILE"
    fi
}

# コンテナ情報更新
update_container_status() {
    local name="$1"
    local field="$2"
    local value="$3"
    
    if [ $# -ne 3 ]; then
        echo "Error: update requires 3 arguments" >&2
        return 1
    fi
    
    jq_inplace --arg name "$name" \
          --arg field "$field" \
          --arg value "$value" \
          '.containers[$name][$field] = $value' "$STATUS_FILE"
}

# 全コンテナ一覧
list_containers() {
    jq -r '.containers | keys[]' "$STATUS_FILE" 2>/dev/null
}

# コンテナ存在チェック
exists_container() {
    local name="$1"
    
    if [ $# -ne 1 ]; then
        echo "Error: exists requires 1 argument" >&2
        return 1
    fi
    
    local result=$(jq -r --arg name "$name" \
                      '.containers | has($name)' "$STATUS_FILE")
    
    if [ "$result" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# -----------------
# 状態チェック関数
# -----------------
#コンテナ情報
container_status() {
    local name="$1"
    machinectl status $name
}

# コンテナのリスト
container_list() {
    get_container_status
}

# コンテナの存在確認
check_container_exists() {
    local name=$1
    machinectl image-status "$name" >/dev/null 2>&1
}

# コンテナの状態確認
container_is_running() {
    local name=$1
    local actual_state="$(machinectl show "$name" -p State --value 2>/dev/null)"
    local json_state="$(get_container_status "$name" state)"

    if [ "$actual_state" == "running" ] && [ "$json_state" != "running" ]; then
        update_container_status "$name" state "running"
    fi

    if [ -z "$actual_state" ] && [ "$json_state" == "running" ]; then
        update_container_status "$name" state "stopped"
    fi

    if [ "$actual_state" == "running" ]; then
        return 0
    else
        return 1
    fi
}

container_validate_name() {
    local name="$1"
    
    validate() {
        [[ -n "$name" ]] || return 1
        [[ ${#name} -lt 11 ]] || return 2
        [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || return 3
    }
    
    local exit_code
    validate
    exit_code=$?
    
    case $exit_code in
        1) log error "Container name is required" ;;
        2) log error "Container name too long (max 10 chars): '$name' (${#name} chars)" ;;
        3) log error "Invalid container name format: '$name' (only alphanumeric, _, - allowed)" ;;
        0) return 0 ;;
    esac
    
    return $exit_code
}


# メイン処理
main() {
    init_json
    
    case "$1" in
        add)
            shift
            add_container_status "$@"
            ;;
        remove)
            shift
            remove_container_status "$@"
            ;;
        get)
            shift
            get_container_status "$@"
            ;;
        update)
            shift
            update_container_status "$@"
            ;;
        list)
            list_containers
            ;;
        exists)
            shift
            exists_container "$@"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

