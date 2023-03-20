#!/usr/bin/env python3


import os
import sys

os.environ["TYPE"]="debug"
os.environ["top"]="/home/vincent/proj/otp/lib/mnesia/"
dir = f"priv/{sys.argv[1]}"


os.system(f"../otp/bin/erl -mnesia dir '\"{dir}\"' -name {sys.argv[1]}@127.0.0.1 -pa `rebar3 path` \
-pa '/home/vincent/proj/inet_tcp_proxy/_build/default/lib/inet_tcp_proxy_dist/ebin' \
-config 'config/sys.config' -debug -proto_dist inet_tcp_proxy")
