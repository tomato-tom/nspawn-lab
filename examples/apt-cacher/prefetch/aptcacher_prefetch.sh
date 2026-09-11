#!/bin/bash
# ACNGキャッシュ更新

DEBUG=false

ACNG_CACHE="/var/cache/apt-cacher-ng"
LOG_FILE="/var/log/apt-cacher-ng/prefetch.log"

$DEBUG && rm "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') update $ACNG_CACHE" >> "$LOG_FILE"

find "$ACNG_CACHE" -type f  ! -name "_*" | while read file; do
    rel_path="${file#$ACNG_CACHE/}"
    server_alias=$(echo "$rel_path" | cut -d/ -f1)
    path=$(echo "$rel_path" | cut -d/ -f2-)
    
    # エイリアスを実際のURLに変換
    case "$server_alias" in
        uburep)     server="jp.archive.ubuntu.com" ;;
        secdeb)     server="security.debian.org" ;;
        debrep)     server="deb.debian.org" ;;
        *)          server="$server_alias" ;;
    esac
    
    $DEBUG && echo "debug: $server_alias -> $server" >> "$LOG_FILE"

    # 実際に更新ある場合のみダウンロード
    if wget -q -N "http://$server/$path" -P "$ACNG_CACHE/$server_alias/" 2>/dev/null; then
        if [ "$(find "$ACNG_CACHE/$server_alias/$(basename "$path")" -newer "$file" 2>/dev/null)" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') $server/$path" >> "$LOG_FILE"
        fi
    fi
done

echo done

