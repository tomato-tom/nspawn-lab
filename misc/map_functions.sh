#!/bin/bash
# misc/map_functions.sh
# シェルスクリプトの関数の関連性を見やすく表示するスクリプト
# /lib/container/container.shに最適化した、ほかは試してない

script=$1
FUNCTION_PATTERN="^[a-zA-Z_][a-zA-Z0-9_]*()"

# 関数一覧を取得
get_functions() {
    function_pattern="^[a-zA-Z_][a-zA-Z0-9_]*()"
    grep "$FUNCTION_PATTERN" "$script" | sed 's/().*$//'
}

# 個別の関数の範囲行数を取得 (start, end)
get_function_range() {
    local func="$1"
    local start_line=$(grep -n "^$func()" "$script" | cut -d: -f1)
    
    if [ -z "$start_line" ]; then
        return 1
    fi
    
    # 関数終了位置を検索
    local line_num=$start_line
    local found_end=0
    
    while IFS= read -r line && [ $found_end -eq 0 ]; do
        ((line_num++))
        if [[ "$line" == "}" ]]; then
            found_end=1
        fi
    done < <(tail -n +$((start_line + 1)) "$script")
    
    # 結果を呼び出し元に返す
    echo "$start_line $line_num"
    return 0
}

show() {
    local line="$1"
    local indent="$2"

    local spaces=""
    local i
    for ((i=0; i<indent; i++)); do
        spaces+=" "
    done

    echo "$spaces$line"
}

trim_head_spaces() {
    sed 's/^[[:space:]]*//'
}

# 関数呼び出し行をトリムする関数
trim_function_call() {
    local line="$1"
    local func_name="$2"
    
    # 関数名より前の部分をトリム
    line=$(echo "$line" | sed -E "s/^.*$func_name/$func_name/")
    # 末尾の不要な部分を除去
    # ; then, ; do, ; else, ; elif を除去
    line=$(echo "$line" | sed -E 's/;[[:space:]]*(then|do|else|elif)[[:space:]]*$//')
    # && または || 以降のすべてを除去
    line=$(echo "$line" | sed -E 's/[[:space:]]*(\&\&|\|\|).*$//')
    # 変数の引用符を除去
    line=$(echo "$line" | sed -E 's/\"*\$([a-zA-Z_][a-zA-Z0-9_]*)\"*/\1/g')
    
    echo "$line"
}

# 個別の関数から呼び出した関数のリストを取得
get_called_functions() {
    local func="$1"
    local range="$2"
    local functions="$3"

    local start_line=$(echo $range | cut -d' ' -f1)
    local end_line=$(echo $range | cut -d' ' -f2)
    local function_code=$(sed -n "$((start_line + 1)),$((end_line - 1))p" "$script")

    local case_pattern='case "$action" in'
    local case_arg_pattern="^[a-zA-Z0-9_|*]+)$"
    local case_flag=false
    local indent=2

    show $func $indent
    ((indent += 2))
    
    # プロセス置換を使用してサブシェルを避ける
    while IFS= read -r line; do
        line=$(echo "$line" | trim_head_spaces)
        [ -z "$line" ] && continue

        # case文内を検出
        if [ "$line" == "$case_pattern" ]; then
            case_flag=true
            show "case:" $indent
            ((indent += 2))

        elif [ "$line" == "esac" ]; then
            case_flag=false
            ((indent -= 2))
            show "end case" $indent
            
        elif [[ "$line" =~ $case_arg_pattern ]]; then
            line="$(echo "$line" | cut -d'|' -f1 | sed -E 's/\)//')"
            show "$line" $indent
        fi

        # 関数内で呼び出される定義済み関数それぞれについてチェック
        echo "$functions" | \
            while IFS= read -r function; do
                echo "$line" | grep -w "$function" >/dev/null && {
                    line=$(trim_function_call "$line" "$function")
                    ((indent += 2))
                    show "-> $line" $indent
                    ((indent -= 2))
                }
            done
            
    done <<< "$function_code"
}

# メイン処理
main() {
    echo "function map:"
    local functions=$(get_functions)
    
    # 各関数の情報を表示
    while IFS= read -r func; do
        if [ -n "$func" ]; then
            
            # 関数の範囲を取得
            local range=$(get_function_range "$func")
            if [ -n "$range" ]; then
                # 呼び出されている関数を取得
                get_called_functions "$func" "$range" "$functions"
            fi
        fi
    done <<< "$functions"
}

main
