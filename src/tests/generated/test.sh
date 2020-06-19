#!/usr/bin/env bash

set -ex

test_one () {
    "../../../keyfender/_build/default/test/test_server.exe" &
    PID=$!
    sleep 1
    ./setup.sh || (kill $PID ; exit 3)
    ./command.sh || (kill $PID ; exit 4)
    kill $PID

    diff <(grep -v "^date: " headers.out) <(grep -v "^date: " headers.expected)
    diff body.out body.expected
}

for x in $(find . -type d -maxdepth 1 | grep -v '^.$' | grep -v '^..$'); do
  cd $x;
  test_one;
  cd ..
done