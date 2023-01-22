-module(porset_ele_tests).

-include_lib("eunit/include/eunit.hrl").

-define(setup(F), {setup, fun start/0, F}).

obsolete_test_() ->
    [{"Delete operation is obsoleted by any other elements",
      {setup, fun start/0, fun remove_obsoleted_by_any/1}},
     {"Write obsoleted by later write or delete",
      {setup, fun start/0, fun remove_obsolete_add/1}},
     {"Different values are obsoleted by each other",
      ?setup(fun different_val_not_obsolete/1)}].

start() ->
    ok.

remove_obsoleted_by_any(_) ->
    {Ts1, Ts2} = {mnesia_causal:new(), mnesia_causal:new()},
    {V1, V2} = {{project, "hello"}, {project, "world"}},
    {O1, O2, O3} =
        {porset_ele:add_meta(V1, Ts1, write),
         porset_ele:add_meta(V2, Ts2, write),
         porset_ele:add_meta(V2, Ts2, delete)},
    {E1, E2, E3} = {porset_ele:obj2ele(O1), porset_ele:obj2ele(O2), porset_ele:obj2ele(O3)},
    [?_assert(porset_ele:obsolete(E3, E2)), ?_assert(porset_ele:obsolete(E3, E1))].

remove_obsolete_add(_) ->
    {Ts1, Ts2} = {#{a => 1, b => 3}, #{a => 1, b => 2}},
    {V1, V2} = {{project, "hello"}, {project, "world"}},
    {O1, O2, O3} =
        {porset_ele:add_meta(V2, Ts1, write),
         porset_ele:add_meta(V2, Ts2, write),
         porset_ele:add_meta(V2, Ts2, delete)},
    {E1, E2, E3} = {porset_ele:obj2ele(O1), porset_ele:obj2ele(O2), porset_ele:obj2ele(O3)},
    [?_assert(porset_ele:obsolete(E2, E1)), ?_assert(porset_ele:obsolete(E3, E1))].

different_val_not_obsolete(_) ->
    {Ts1, Ts2} = {#{a => 1, b => 3}, #{a => 1, b => 2}},
    {V1, V2} = {{project, "hello"}, {project, "world"}},
    {O1, O2, O3} =
        {porset_ele:add_meta(V1, Ts1, write),
         porset_ele:add_meta(V2, Ts2, write),
         porset_ele:add_meta(V2, Ts2, delete)},
    {E1, E2, E3} = {porset_ele:obj2ele(O1), porset_ele:obj2ele(O2), porset_ele:obj2ele(O3)},
    [?_assertNot(porset_ele:obsolete(E2, E1)), ?_assertNot(porset_ele:obsolete(E1, E3))].
