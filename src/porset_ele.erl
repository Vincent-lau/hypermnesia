-module(porset_ele).

-export([obj2ele/1, ele2obj/1, get_val_ele/1, get_val_tup/1, obsolete/2, get_val_key/1,
         add_meta/3, delete_meta/1, tup_is_write/1]).

-type op() :: write | delete.
-type val() :: any().
-type ts() :: mnesia_causal:vclock().
-type element() :: {ts(), {op(), val()}}.

key_pos() ->
    2.

-spec obj2ele(tuple()) -> element().
obj2ele(Obj) ->
    {get_ts(Obj), {get_op(Obj), get_val_tup(Obj)}}.

ele2obj({Ts, {Op, Val}}) ->
    add_meta(Val, Ts, Op).

get_val_ele({_Ts, {_Op, V}}) ->
    V.

%% @equiv delete_meta/1
get_val_tup(Obj) ->
    delete_meta(Obj).

%% @returns true if second element obsoletes the first one
-spec obsolete({ts(), {op(), val()}}, {ts(), {op(), val()}}) -> boolean().
obsolete({Ts1, {write, V1}}, {Ts2, {write, V2}}) ->
    equals(V1, V2) andalso mnesia_causal:compare_vclock(Ts1, Ts2) =:= lt;
obsolete({Ts1, {write, V1}}, {Ts2, {delete, V2}}) ->
    lager:debug("equals ~p~n", [equals(V1, V2)]),
    lager:debug("vclock V1~p V2~p ~p~n", [V1, V2, mnesia_causal:compare_vclock(Ts1, Ts2)]),
    equals(V1, V2) andalso mnesia_causal:compare_vclock(Ts1, Ts2) =:= lt;
obsolete({_Ts1, {delete, _V1}}, _X) ->
    true.

-spec equals(tuple(), tuple()) -> boolean().
equals(V1, V2) ->
    element(key_pos(), V1) =:= element(key_pos(), V2).

-spec get_val_key(tuple()) -> term().
get_val_key(V) ->
    element(key_pos(), V).

-spec add_ts(tuple(), ts()) -> tuple().
add_ts(Obj, Ts) ->
    erlang:append_element(Obj, Ts).

add_op(Obj, Op) ->
    erlang:append_element(Obj, Op).

get_op(Obj) ->
    element(tuple_size(Obj), Obj).

get_ts(Obj) ->
    element(tuple_size(Obj) - 1, Obj).

-spec add_meta(tuple(), ts(), op()) -> tuple().
add_meta(Obj, Ts, Op) ->
    add_op(add_ts(Obj, Ts), Op).

-spec delete_meta(tuple()) -> tuple().
delete_meta(Obj) ->
    Last = tuple_size(Obj),
    erlang:delete_element(Last - 1, erlang:delete_element(Last, Obj)).

tup_is_write(Tup) ->
    get_op(Tup) =:= write.
