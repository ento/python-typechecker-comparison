#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

speed_dir=""
accuracy_dir=""
declare -a typecheckers

options=$(getopt --longoptions "speed:,accuracy:,mypy,pytype,pyre,pyright" -o "" -- "$@")
eval set -- "$options"

while true
do
case $1 in
--speed)
    shift
    speed_dir=$1
    ;;
--accuracy)
    shift
    accuracy_dir=$1
    ;;
--mypy)
    typecheckers+=("mypy")
    ;;
--pytype)
    typecheckers+=("pytype")
    ;;
--pyre)
    typecheckers+=("pyre")
    ;;
--pyright)
    typecheckers+=("pyright")
    ;;
--)
    shift
    break;;
esac
shift
done

if [ ${#typecheckers[@]} -eq 0 ]; then
    typecheckers=("mypy" "pytype" "pyre" "pyright")
fi

if [ -z "$speed_dir" -a -z "$accuracy_dir" ]; then
    echo "Specify --speed [path] and/or --accuracy [path]"
    exit 1
fi

if [[ " ${typecheckers[*]} " =~ " mypy " ]]; then
    echo "================================"
    echo "mypy"
    echo "================================"

    if [ ! -z "$speed_dir" ]; then
        mypy_prepare="rm -rf .mypy_cache/"
        mypy_command="mypy $speed_dir --ignore-missing-imports"

        echo "speed: initial"
        run hyperfine --ignore-failure --prepare "$mypy_prepare" "$mypy_command"

        echo "speed: cached"
        run hyperfine --ignore-failure --warmup 3 "$mypy_command"
    fi

    if [ ! -z "$accuracy_dir" ]; then
        echo "accuracy"
        mypy "$accuracy_dir"
    fi
fi

if [[ " ${typecheckers[*]} " =~ " pytype " ]]; then
    echo "================================"
    echo "pytype"
    echo "================================"

    if [ ! -z "$speed_dir" ]; then
        pytype_prepare="watchman shutdown-server; rm -rf .pytype/"
        pytype_command="pytype --config pytype.cfg $speed_dir"

        echo "speed: initial"
        hyperfine --ignore-failure --prepare "$pytype_prepare" "$pytype_command"

        echo "speed: cached"
        hyperfine --ignore-failure --warmup 3 "$pytype_command"
    fi

    if [ ! -z "$accuracy_dir" ]; then
        echo "accuracy"
        pytype --config pytype.cfg "$accuracy_dir"
    fi
fi

if [[ " ${typecheckers[*]} " =~ " pyre " ]]; then
    echo "================================"
    echo "pyre"
    echo "================================"

    if [ ! -z "$speed_dir" ]; then
        site_packages_path=$(python3 -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')
        pyre_prepare="pyre stop; rm -rf $speed_dir/.pyre/"
        pyre_command="pyre --search-path $site_packages_path --source-directory $speed_dir check"
        pyre_cached_command="pyre --search-path $site_packages_path --source-directory $speed_dir incremental"

        echo "speed: initial"
        hyperfine --ignore-failure --prepare "$pyre_prepare" "$pyre_command"

        echo "speed: cached"
        hyperfine --ignore-failure --warmup 3 "$pyre_cached_command"
    fi

    if [ ! -z "$accuracy_dir" ]; then
        echo "accuracy"
        pyre --source-directory "$accuracy_dir" check
    fi
fi

if [[ " ${typecheckers[*]} " =~ " pyright " ]]; then
    echo "================================"
    echo "pyright"
    echo "================================"

    if [ ! -z "$speed_dir" ]; then
        socket_file="$SCRIPT_DIR/aio_socket"
        pyright_prepare=""
        pyright_command="pyright $speed_dir"
        pyright_cached_prepare="curl --unix-socket $socket_file http://hello/flush"
        pyright_cached_command="echo '#' >> $speed_dir/__init__.py; curl --unix-socket $socket_file http://hello/wait"

        echo "speed: initial"
        hyperfine --ignore-failure --prepare "$pyright_prepare" "$pyright_command"

        echo "speed: cached"
        FORCE_COLOR=true python "$SCRIPT_DIR/buffered_tail.py" "$SCRIPT_DIR/node_modules/.bin/pyright" --watch "$speed_dir" &
        pyright_pid=$!
        curl --connect-timeout 1000 --retry 10 --retry-delay 1 --retry-connrefused --unix-socket "$socket_file" http://hello/wait
        hyperfine --ignore-failure --warmup 3 --prepare "$pyright_cached_prepare" "$pyright_cached_command"
        kill -9 "$pyright_pid"
    fi

    if [ ! -z "$accuracy_dir" ]; then
        echo "accuracy"
        pyright "$accuracy_dir"
    fi
fi
