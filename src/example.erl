-module(example).

-export([t/4]).

t(Pid, Pid2, Request1, Request2) ->
    %% example.erl:5: OPTIMIZED: reference used to mark a 
    %%                           message queue position
    Mref1 = monitor(process, Pid),
    Mref2 = monitor(process, Pid2),
    Pid ! {self(), Mref1, Request1},
    Pid2 ! {self(), Mref2, Request2},
    %% example.erl:7: INFO: passing reference created by
    %%                      monitor/2 at example.erl:5
    await_result(Mref1),
    await_result(Mref2).

await_result(Mref) ->
    %% example.erl:10: OPTIMIZED: all clauses match reference
    %%                            in function parameter 1
    receive
        {Mref, ok} ->
            erlang:demonitor(Mref, [flush]),
            {ok, ok};
        {Mref, no} ->
            erlang:demonitor(Mref, [flush]),
            {no, no}
    end.
