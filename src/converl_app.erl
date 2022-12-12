%%%-------------------------------------------------------------------
%% @doc converl public API
%% @end
%%%-------------------------------------------------------------------

-module(converl_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    % HACK assume name only has one letter
    Name = hd(atom_to_list(node())),
    Dir = "priv/" ++ Name,
    io:format("Starting converl on node ~p with mnesia dir ~p~n", [Name, Dir]),
    application:set_env(mnesia, dir, Dir),
    converl_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
