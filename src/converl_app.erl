%%%-------------------------------------------------------------------
%% @doc converl public API
%% @end
%%%-------------------------------------------------------------------

-module(converl_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    converl_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
