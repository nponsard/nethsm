#!/usr/bin/env bash

set -ex

test_one () {
    "../../../keyfender/_build/default/test/test_server.exe" &
    PID=$!
    sleep 2
    ./setup.sh || (kill $PID ; exit 3)

    # if exists, run ./wrong_json_cmd.sh and see if we get a 400
    if [ -e wrong_json_cmd.sh ]; then
      ./wrong_json_cmd.sh || (kill $PID ; exit 4)
      diff -w -u <(head -n 1 wrong_json_headers.out | cut -f 2 -d ' ') <(echo "400")
    fi

    # if exists, run ./wrong_key_cmd.sh and see if we get a 404
    if [ -e wrong_key_cmd.sh ]; then
      ./wrong_key_cmd.sh || (kill $PID ; exit 4)
      diff -w -u <(head -n 1 wrong_key_headers.out | cut -f 2 -d ' ') <(echo "404")
    fi

    # if exists, run ./wrong_user_cmd.sh and see if we get a 404
    if [ -e wrong_user_cmd.sh ]; then
      ./wrong_user_cmd.sh || (kill $PID ; exit 4)
      diff -w -u <(head -n 1 wrong_user_headers.out | cut -f 2 -d ' ') <(echo "404")
    fi

    # if exists, run ./wrong_auth_cmd.sh and see if we get a 404
    if [ -e wrong_auth_cmd.sh ]; then
      ./wrong_auth_cmd.sh || (kill $PID ; exit 4)
      diff -w -u <(head -n 1 wrong_auth_headers.out | cut -f 2 -d ' ') <(echo "403")
    fi

    ./command.sh || (kill $PID ; exit 4)
    ./shutdown.sh || (kill $PID ; exit 5)

    diff -w -u <(grep "^HTTP" headers.out) <(grep "^HTTP" headers.expected)
    if [ ! -f body.skip ]; then
      diff -w -u body.out body.expected
    fi

}

for test_dir in $(ls generated/); do
    (cd generated/${test_dir}; test_one)
done
