%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 1996-2022. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

-module(mnesia_porset).

-behaviour(mnesia_backend_type).

%% Initializations
-export([init_backend/0, add_aliases/1, remove_aliases/1, check_definition/4,
         semantics/2]).
-export([create_table/3, load_table/4, delete_table/2, close_table/2, sync_close_table/2,
         sender_init/4, receiver_first_message/4, receive_data/5, receive_done/4,
         index_is_consistent/3, is_index_consistent/2, real_suffixes/0, tmp_suffixes/0, info/3,
         fixtable/3, validate_key/6, validate_record/6, first/2, last/2, next/3, prev/3, slot/3,
         insert/3, update_counter/4, lookup/3, delete/3, match_delete/3, select/1, select/3,
         select/4, repair_continuation/2]).
-export([register/0, register/1, create_schema/1, create_schema/2]).

-define(DEBUG, 1).

-ifdef(DEBUG).

-define(DBG(DATA), lager:debug("~p:~p: ~p", [?MODULE, ?LINE, DATA])).
-define(DBG(FORMAT, ARGS), lager:debug("~p:~p: " ++ FORMAT, [?MODULE, ?LINE] ++ ARGS)).

-else.

-define(DBG(DATA), ok).
-define(DBG(FORMAT, ARGS), ok).

-endif.

%% types() ->
%%     [{fs_copies, ?MODULE},
%%      {raw_fs_copies, ?MODULE}].

%%% convenience functions

%% @equiv register(porset_copies)
register() ->
    register(default_alias()).

register(Alias) ->
    Module = ?MODULE,
    case mnesia:add_backend_type(Alias, Module) of
        {atomic, ok} ->
            lager:debug("backend successfully registered"),
            {ok, Alias};
        {aborted, {backend_type_already_exists, _}} ->
            lager:debug("backend already registered"),
            {ok, Alias};
        {aborted, Reason} ->
            {error, Reason}
    end.

%%% mnesia_backend_type callbacks

semantics(porset_copies, storage) ->
    ram_copies;
semantics(porset_copies, types) ->
    [set, ordered_set, bag];
semantics(porset_copies, index_types) ->
    [ordered];
semantics(_Alias, _) ->
    undefined.

%% valid_op(_, _) ->
%%     true.

init_backend() ->
    %% cheat and stuff a marker in mnesia_gvar
    mnesia_porset_admin:ensure_started(),
    lager:info("init porset backend").

default_alias() ->
    porset_copies.

add_aliases(_As) ->
    lager:debug("add_aliases(~p)", [_As]),
    mnesia_porset_admin:ensure_started(),
    % TODO add alias
    ok.

remove_aliases(_) ->
    % TODO remove alias
    ok.

create_schema(Nodes) ->
    create_schema(Nodes, [default_alias()]).

create_schema(Nodes, Aliases) when is_list(Nodes), is_list(Aliases) ->
    mnesia:create_schema(Nodes, [{backend_types, [{A, ?MODULE} || A <- Aliases]}]).

%% Table operations

check_definition(porset_copies, _Tab, _Nodes, _Props) ->
    lager:debug("~p ~p ~p~n", [_Tab, _Nodes, _Props]),
    ok.

create_table(porset_copies, Tab, Props) when is_atom(Tab) ->
    Tid = ets:new(Tab, [public, bag, {keypos, 2}]),
    % Tid = ets:whereis(Name),
    lager:debug("table created 1: ~p with tid ~p and prop ~p~n", [Tab, Tid, Props]),
    mnesia_lib:set({?MODULE, Tab}, Tid),
    ok;
create_table(_, Tag = {Tab, index, {_Where, Type0}}, _Opts) ->
    Type =
        case Type0 of
            ordered ->
                ordered_set;
            _ ->
                Type0
        end,
    Tid = ets:new(Tab, [public, Type]),
    lager:debug("table created 2: tag ~p", [Tag]),
    mnesia_lib:set({?MODULE, Tag}, Tid),
    ok;
create_table(_, Tag = {_Tab, retainer, ChkPName}, _Opts) ->
    Tid = ets:new(ChkPName, [bag, public, {keypos, 2}]),
    lager:debug("table created 3: ~p(~p) ~p", [_Tab, Tid, Tag]),
    mnesia_lib:set({?MODULE, Tag}, Tid),
    ok.

delete_table(porset_copies, Tab) ->
    try
        ets:delete(
            mnesia_lib:val({?MODULE, Tab})),
        mnesia_lib:unset({?MODULE, Tab}),
        ok
    catch
        _:_ ->
            ?DBG({double_delete, Tab}),
            ok
    end.

load_table(porset_copies, _Tab, init_index, _Cs) ->
    ok;
load_table(porset_copies, _Tab, _LoadReason, _Cs) ->
    ?DBG("Load ~p ~p~n", [_Tab, _LoadReason]),
    ok.

%%     mnesia_monitor:unsafe_create_external(Tab, porset_copies, ?MODULE, Cs).

sender_init(Alias, Tab, _RemoteStorage, _Pid) ->
    KeysPerTransfer = 100,
    {standard,
     fun() -> mnesia_lib:db_init_chunk({ext, Alias, ?MODULE}, Tab, KeysPerTransfer) end,
     fun(Cont) -> mnesia_lib:db_chunk({ext, Alias, ?MODULE}, Cont) end}.

receiver_first_message(Sender, {first, Size}, _Alias, Tab) ->
    ?DBG({first, Size}),
    {Size, {Tab, Sender}}.

receive_data(Data, porset_copies, Name, Sender, {Name, Tab, Sender} = State) ->
    ?DBG({Data, State}),
    true = ets:insert(Tab, Data),
    {more, State};
receive_data(Data, Alias, Tab, Sender, {Name, Sender}) ->
    receive_data(Data, Alias, Tab, Sender, {Name, mnesia_lib:val({?MODULE, Tab}), Sender}).

receive_done(_Alias, _Tab, _Sender, _State) ->
    ?DBG({done, _State}),
    ok.

close_table(Alias, Tab) ->
    sync_close_table(Alias, Tab).

sync_close_table(porset_copies, _Tab) ->
    ?DBG(_Tab).

fixtable(porset_copies, Tab, Bool) ->
    ?DBG({Tab, Bool}),
    ets:safe_fixtable(
        mnesia_lib:val({?MODULE, Tab}), Bool).

info(porset_copies, Tab, Type) ->
    ?DBG({Tab, Type}),
    Tid = mnesia_lib:val({?MODULE, Tab}),
    try ets:info(Tid, Type) of
        Val ->
            Val
    catch
        _:_ ->
            undefined
    end.

real_suffixes() ->
    [".dat"].

tmp_suffixes() ->
    [].

%% Index

index_is_consistent(_Alias, _Ix, _Bool) ->
    ok.  % Ignore for now

is_index_consistent(_Alias, _Ix) ->
    false.      % Always rebuild

%% Record operations

validate_record(_Alias, _Tab, RecName, Arity, Type, _Obj) ->
    {RecName, Arity, Type}.

validate_key(_Alias, _Tab, RecName, Arity, Type, _Key) ->
    {RecName, Arity, Type}.

-spec effect(mnesia:table(), tuple()) -> ok.
effect(Tab, Tup) ->
    case causal_compact(Tab, porset_ele:obj2ele(Tup)) of
        true ->
            lager:debug("not redundant, inserting ~p into ~p~n",
                        [Tup, mnesia_lib:val({?MODULE, Tab})]),
            ets:insert(
                mnesia_lib:val({?MODULE, Tab}), Tup);
        false ->
            lager:debug("redundant"),
            ok
    end.

insert(Alias, Tab, {Obj, Ts}) ->
    lager:debug("running my own insert function on ~p and table ~p with val "
                "~p and ts ~p~n",
                [Alias, Tab, Obj, Ts]),
    try
        Tup = porset_ele:add_meta(Obj, Ts, write),
        lager:debug("inserting ~p into ~p~n", [Tup, mnesia_lib:val({?MODULE, Tab})]),
        effect(Tab, Tup)
    catch
        _:Reason ->
            lager:warn("CRASH ~p ~p~n", [Reason, mnesia_lib:val({?MODULE, Tab})])
    end.

lookup(porset_copies, Tab, Key) ->
    Res = ets:lookup(
              mnesia_lib:val({?MODULE, Tab}), Key),
    lager:debug("running my own lookup function on ~p, got ~p", [Tab, Res]),
    lists:filtermap(fun(Tup) ->
                       case porset_ele:tup_is_write(Tup) of
                           false -> false;
                           true -> {true, porset_ele:get_val_tup(Tup)}
                       end
                    end,
                    Res).

delete(porset_copies, Tab, {Key, Ts}) ->
    lager:debug("running custom delete function key: ~p, ts: ~p tab: ~p", [Key, Ts, Tab]),
    DummyVal = {Tab, Key},
    Tup = porset_ele:add_meta(DummyVal, Ts, delete),
    effect(Tab, Tup).

match_delete(porset_copies, Tab, Pat) ->
    ets:match_delete(
        mnesia_lib:val({?MODULE, Tab}), Pat).

first(porset_copies, Tab) ->
    ets:first(
        mnesia_lib:val({?MODULE, Tab})).

last(Alias, Tab) ->
    first(Alias, Tab).

next(porset_copies, Tab, Key) ->
    ets:next(
        mnesia_lib:val({?MODULE, Tab}), Key).

prev(Alias, Tab, Key) ->
    next(Alias, Tab, Key).

slot(porset_copies, Tab, Pos) ->
    ets:slot(
        mnesia_lib:val({?MODULE, Tab}), Pos).

update_counter(porset_copies, Tab, C, Val) ->
    ets:update_counter(
        mnesia_lib:val({?MODULE, Tab}), C, Val).

select('$end_of_table' = End) ->
    End;
select({porset_copies, C}) ->
    ets:select(C).

select(Alias, Tab, Ms) ->
    Res = select(Alias, Tab, Ms, 100000),
    select_1(Res).

select_1('$end_of_table') ->
    [];
select_1({Acc, C}) ->
    case ets:select(C) of
        '$end_of_table' ->
            Acc;
        {New, Cont} ->
            select_1({New ++ Acc, Cont})
    end.

select(porset_copies, Tab, Ms, Limit) when is_integer(Limit); Limit =:= infinity ->
    ets:select(
        mnesia_lib:val({?MODULE, Tab}), Ms, Limit).

repair_continuation(Cont, Ms) ->
    ets:repair_continuation(Cont, Ms).

%%% pure op-based orset implementation

%% removes obsolete elements
%% @returns whether this element should be added
-spec causal_compact(mnesia:table(), porset_ele:element()) -> boolean().
causal_compact(Tab, Ele) ->
    ok = remove_obsolete(Tab, Ele),
    not redundant(Tab, Ele).

%% @doc checks whether the input element is redundant
%% i.e. if there are any other elements in the table that obsoletes this element
%% @end
-spec redundant(mnesia:table(), porset_ele:element()) -> boolean().
redundant(_Tab, {_Ts, {delete, _Val}}) ->
    lager:debug("element is a delete, redundant"),
    true;
redundant(Tab, Ele) ->
    lager:debug("checking redundancy"),
    Key = porset_ele:get_val_key(
              porset_ele:get_val_ele(Ele)),
    Tups =
        ets:lookup(
            mnesia_lib:val({?MODULE, Tab}), Key),
    lager:debug("found ~p~n", [Tups]),
    Eles2 = lists:map(fun porset_ele:obj2ele/1, Tups),
    lager:debug("generated ~p~n", [Eles2]),
    lists:any(fun(Ele2) -> porset_ele:obsolete(Ele, Ele2) end, Eles2).

% check_redundant(_Tab, '$end_of_table', _E) ->
%     lager:debug("element ~p is not redundant", [_E]),
%     false;
% check_redundant(Tab, Key, Ele1) ->
%     NextKey = next(porset_copies, Tab, Key),
%     % guaranteed to return a value since we are iterating over all keys
%     Tups =
%         ets:lookup(
%             mnesia_lib:val({?MODULE, Tab}), Key),
%     lager:debug("found ~p~n", [Tups]),
%     Eles2 = lists:map(fun obj2ele/1, Tups),
%     lager:debug("generated ~p~n", [Eles2]),
%     lists:any(fun(Ele2) -> obsolete(Ele1, Ele2) end, Eles2)
%     orelse check_redundant(Tab, NextKey, Ele1).

% TODO there might be better ways of doing the scan
%% removes elements that are obsoleted by Ele
%% When we check for elements obsoleted by Ele, we only care about those with
%% the same key as Ele, no need to go through the entire table
-spec remove_obsolete(mnesia:table(), porset_ele:element()) -> ok.
remove_obsolete(Tab, Ele) ->
    lager:debug("checking obsolete"),
    Key = porset_ele:get_val_key(
              porset_ele:get_val_ele(Ele)),
    lager:debug("key ~p~n", [Key]),
    Tups =
        ets:lookup(
            mnesia_lib:val({?MODULE, Tab}), Key),
    lager:debug("existing tuples ~p~n", [Tups]),
    ets:delete(
        mnesia_lib:val({?MODULE, Tab}), Key),
    Keep =
        lists:filter(fun(Tup) ->
                        not
                            porset_ele:obsolete(
                                porset_ele:obj2ele(Tup), Ele)
                     end,
                     Tups),
    lager:debug("removed obsolete ~p kept ~p~n", [Tups -- Keep, Keep]),
    ets:insert(
        mnesia_lib:val({?MODULE, Tab}), Keep),
    ok.

    % do_remove_obsolete(Tab, first(porset_copies, Tab), Ele).

% -spec do_remove_obsolete(mnesia:table(), term(), element()) -> ok.
% do_remove_obsolete(_Tab, '$end_of_table', _E) ->
%     lager:debug("done removing obsolete"),
%     ok;
% do_remove_obsolete(Tab, Key, Ele2) ->
%     NextKey = next(porset_copies, Tab, Key),
%     % it's possible to have mutliple tuples since the store is keyed by ts
%     Tups =
%         ets:lookup(
%             mnesia_lib:val({?MODULE, Tab}), Key),
%     lager:debug("found ~p~n", [Tups]),
%     Eles1 = lists:map(fun obj2ele/1, Tups),
%     lager:debug("generated ~p, input ele ~p~n", [Eles1, Ele2]),
%     Keep =
%         lists:filtermap(fun(Ele1) ->
%                            case obsolete(Ele1, Ele2) of
%                                true -> false;
%                                false -> {true, ele2obj(Ele1)}
%                            end
%                         end,
%                         Eles1),
%     lager:debug("removed obsolete ~p kept ~p~n", [Tups -- Keep, Keep]),
%     ets:delete(
%         mnesia_lib:val({?MODULE, Tab}), Key),
%     ets:insert(
%         mnesia_lib:val({?MODULE, Tab}), Keep),
%     do_remove_obsolete(Tab, NextKey, Ele2).

%%% Helper
