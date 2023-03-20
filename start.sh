#!/bin/zsh

../otp/bin/erl -mnesia dir '"priv/b"' debug debug -name b@127.0.0.1 -pa `rebar3 path` -pa '/home/vincent/proj/inet_tcp_proxy/_build/default/lib/inet_tcp_proxy_dist/ebin' -config 'config/sys.config' -debug -proto_dist inet_tcp_proxy

