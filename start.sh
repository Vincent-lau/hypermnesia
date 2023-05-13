#!/bin/zsh


~/proj/otp/bin/erl -mnesia dir '"priv/'$1'"' debug debug -name $1@127.0.0.1 -pa \
`rebar3 path` -pa '/home/vincent/proj/inet_tcp_proxy/_build/default/lib/inet_tcp_proxy_dist/ebin' \
-setcookie cookie


# -config 'config/sys.config' -debug -proto_dist inet_tcp_proxy

