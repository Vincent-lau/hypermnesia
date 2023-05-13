-module(mnesia_porset_admin).

-compile(export_all).

-spec ensure_started() -> ok.
ensure_started() ->
    case whereis(?MODULE) of
        undefined ->
            do_start();
        _ ->
            ok
    end.

do_start() ->
    application:ensure_all_started(converl).
    % TODO consider when to use mnesia_ext_sup:start_proc/6


    % case mnesia_ext_sup:start_proc(?MODULE,
    %                                ?MODULE,
    %                                start_link,
    %                                [],
    %                                [{restart, permanent},
    %                                 {shutdown, 10000},
    %                                 {type, worker},
    %                                 {modules, [?MODULE]}])
    % of
    %     {ok, _Pid} ->
    %         ok;
    %     {error, {already_started, _Pid}} ->
    %         ok
    % end.
