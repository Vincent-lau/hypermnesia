#!/bin/zsh

# add debug debug after -mnesia dir '"priv/'$1'"' to enable mnesia debug
~/Developer/otp/bin/erl -mnesia dir '"priv/'$1'"' -name $1@127.0.0.1 -pa \
`rebar3 path` -pa '/Users/vincent/Developer/inet_tcp_proxy/_build/default/lib/inet_tcp_proxy_dist/ebin' \
-setcookie cookie $2 $3

# -config 'config/sys.config' -debug -proto_dist inet_tcp_proxy

