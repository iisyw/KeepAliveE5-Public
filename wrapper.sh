#!/usr/bin/env bash

UPSTREAM="https://github.com/vcheckzen/KeepAliveE5.git"
BOT_USER="github-actions[bot]"
BOT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
CONFIG_PATH="config"

exit_on_error() {
    min_secs="$1"
    max_time="$2"
    cmd="$3"

    start=$(date +%s)
    # https://man7.org/linux/man-pages/man1/timeout.1.html
    # https://stackoverflow.com/questions/29936956/linux-how-does-the-kill-k-switch-work-in-timeout-command
    # https://stackoverflow.com/questions/42615374/the-linux-timeout-command-and-exit-codes
    # do not quote $cmd
    # shellcheck disable=SC2086
    # output="$(2>&1 timeout -s KILL "$max_time" $cmd)"
    output="$(timeout 2>&1 --preserve-status -k 1m "$max_time" $cmd)"
    ret=$?
    end=$(date +%s)
    [ "$output" ] && echo "$output"

    [ $ret -ne 0 ] && exit 1
    [ $((end - start)) -lt "$min_secs" ] && exit 1
    # https://man7.org/linux/man-pages/man1/grep.1.html
    # https://unix.stackexchange.com/questions/305547/broken-pipe-when-grepping-output-but-only-with-i-flag
    echo "$output" | grep '成功' >/dev/null || exit 1
    echo "$output" | grep -iE '错误|失败|error|except' >/dev/null && exit 1

    return 0
}

last_advice() {
    echo -n "$1"
    # omit default
    [ "$2" != "o" ] &&
        echo -n " Before doing that, check if your usernames are matched with \
the relevant passwords, and if the security defaults are disabled."
    echo
    exit 1
}

trim() {
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$1"
}

check_env() {
    fix_advice="请修正后重新执行应用注册."

    for k in USER PASSWD; do
        # v="$(eval "echo "\$$k"")"
        v="${!k}"
        trimmed="$(trim "$v")"
        [ "$trimmed" != "$v" ] && {
            last_advice "$k 变量中存在多余的空白字符，$fix_advice" "o"
        }
        [ "$trimmed" ] || {
            last_advice "未添加 $k 变量，或变量值为空白字符，$fix_advice" "o"
        }
    done

    # https://ss64.com/bash/mapfile.html
    mapfile -t users < <(echo -e "$USER")
    mapfile -t passwords < <(echo -e "$PASSWD")
    len="$(echo -e "${#users[@]}\n${#passwords[@]}" | sort -n | tail -1)"
    for ((i = 0; i < "$len"; i++)); do
        [ "$(trim "${users[$i]}")" ] || {
            last_advice "USER 变量中存在多余的换行，$fix_advice" "o"
        }
        [ "$(trim "${passwords[$i]}")" ] || {
            last_advice "PASSWD 变量中存在多余的换行，$fix_advice" "o"
        }
    done
}

has_valid_cfg() {
    [ -d "$CONFIG_PATH" ] || return 1

    [ "$(wc 2>/dev/null -c "$CONFIG_PATH"/* |
        tail -1 | cut -d' ' -f1 | xargs | sed 's/^$/0/')" -eq 0 ] &&
        return 1

    cfg_files=("$CONFIG_PATH"/*.json)
    [ ${#cfg_files[@]} -eq "$(echo -e "$USER" | wc -l)" ]
}

register() {
    (
        cd register || exit 1
        exit_on_error "90" "5m" "bash register_apps_by_force.sh"
    )
    ret=$?

    fix_advice="please rerun Register APP Action."
    has_valid_cfg ||
        last_advice "Configuration files were not completely generated, $fix_advice"

    poetry run python crypto.py e ||
        last_advice "File encryption failed, $fix_advice"

    [ $ret -ne 0 ] &&
        last_advice "APP registration is not completely finished, $fix_advice"

    exit $ret
}

invoke() {
    has_valid_cfg ||
        last_advice "配置文件不合法, 请执行应用注册 Action." "o"

    # sleep $((RANDOM % 127))
    fix_advice="rerun Register APP Action if this condition has occurred more \
than 3 times."
    poetry run python crypto.py d ||
        last_advice "Configuration file decryption failed, $fix_advice"

    (exit_on_error "25" "4m" "poetry run python task.py")
    ret=$?

    poetry run python crypto.py e ||
        last_advice "The configure file encryption failed, $fix_advice"

    [ $ret -ne 0 ] && last_advice "Invoking APIs failed, $fix_advice"

    exit $ret
}

sync() {
    action="$1"
    message="$2"

    # call windows git from wsl
    git=git
    command -v git.exe 1>/dev/null && git=git.exe

    $git config user.name "$BOT_USER"
    $git config user.email "$BOT_EMAIL"

    [ "$action" = "pull" ] && {
        [ -d "$CONFIG_PATH" ] && {
            tmp_path="$(mktemp -d)"
            mv "$CONFIG_PATH" "$tmp_path"
        }

        $git remote add upstream "$UPSTREAM"
        $git pull upstream master 1>/dev/null 2>&1
        $git reset --hard upstream/master

        [ -z ${tmp_path+x} ] || {
            mv "$tmp_path"/* ./
            rm -rf "$tmp_path"
        }

        # exit 0
        message="sync with upstream"
    }

    $git checkout --orphan latest_branch
    $git rm -rf --cached .
    $git add -A
    $git commit -m "$message"
    $git branch -D master
    $git branch -m master
    $git push -f origin master
}

case $1 in
check_env | has_valid_cfg | register | invoke)
    $1
    ;;
pull | push)
    sync "$@"
    ;;
upg)
    sed -i \
        "s/\(version@\)[0-9]\+/\1$(env TZ=Asia/Shanghai date +%Y%m%d%H%M)/" \
        README.md
    sync push reset
    ;;
*)
    echo "Not supported"
    exit 1
    ;;
esac
