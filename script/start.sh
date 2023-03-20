#!/bin/zsh


export TYPE=debug
export top="/home/vincent/proj/otp/lib/mnesia/"
export DIR="priv/$1"
cd ../otp && make mnesia && \
cd ../converl && \
rebar3 compile && \
../otp/bin/erl -mnesia dir "$DIR" -name $1@127.0.0.1 -pa `rebar3 path` \
-pa '/home/vincent/proj/inet_tcp_proxy/_build/default/lib/inet_tcp_proxy_dist/ebin' \
-config 'config/sys.config' -debug -proto_dist inet_tcp_proxy
