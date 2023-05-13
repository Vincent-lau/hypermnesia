-module(foo).

-export([start/0, random_call/1, handle_call/3, handle_cast/2, handle_info/2,
terminate/2, init/1]).

-behaviour(gen_server).

-record(state, {}).


start() -> 
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, #state{}}.


random_call(Pid)->
    gen_server:call(?MODULE, {random_call, Pid}).


%% gen_server callbacks
%% ===================================================================

handle_call({random_call, Pid}, From, State) ->
    gen_server:reply(From, ok),
    io:format("hello world~n"),
    Pid ! ok2,
    {noreply, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

