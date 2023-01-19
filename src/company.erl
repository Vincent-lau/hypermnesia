-module(company).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("stdlib/include/qlc.hrl").

-include("company.hrl").

all_nodes() ->
    ['a@127.0.0.1', 'b@127.0.0.1', 'c@127.0.0.1'].

start() ->
    delete_schema(),
    create_schema(),
    mnesia_start(),
    init_proj(),
    timer:sleep(1000),

    write_proj(1),
    % call from a side
    rpc:call('b@127.0.0.1', company, write_proj, [2]).

start_dbg() ->
    debugger:start(),
    mnesia:delete_schema([node()]),
    mnesia:create_schema([node()]),
    mnesia:start(),
    mnesia_porset:register().

start_por() ->
    mnesia_start(),
    rpc:multicall(
        company:all_nodes(), mnesia_porset, register, []),
    timer:sleep(100),
    init_por(),
    write_proj(1).
    % timer:sleep(2000),
    % mnesia:dirty_delete(project, "otp").


prepare_por() ->
    delete_schema(),
    create_schema(),
    mnesia_start(),
    rpc:multicall(all_nodes(), mnesia_porset, register, []).

check() ->
    rpc:multicall(all_nodes(), ets, tab2list, [mnesia_lib:val({mnesia_porset, project})]).

check_por() ->
    T=mnesia_lib:val({mnesia_porset, project}),
    ets:tab2list(T).

load_bin() ->
    rpc:multicall(all_nodes(), code, purge, [company]),
    rpc:multicall(all_nodes(), code, load_file, [company]).

stop_all() ->
    rpc:eval_everywhere(all_nodes(), init, stop, []).

write_proj(1) ->
    mnesia:dirty_write(project,
                       #project{name = "otp",
                                number = 1,
                                lang = "Erlang"});
write_proj(2) ->
    case mnesia:dirty_read(project, "otp") of
        [A = #project{name = "otp",
                      number = 1,
                      lang = "Erlang"}] ->
            mnesia:dirty_write(project,
                               #project{name = "top",
                                        number = A#project.number + 1,
                                        lang = "Erlang"});
        [] ->
            write_proj(2)
    end;
write_proj(N) when is_list(N) ->
    mnesia:dirty_write(project,
                       #project{name = N,
                                number = 1,
                                lang = "Erlang"}).

    % mnesia:dirty_write(project,
    %                    #project{name = "Naiad",
    %                             number = 3,
    %                             lang = "C#"}).

finish() ->
    mnesia:stop(),
    mnesia:delete_schema([all_nodes()]).

init_rocksdb() ->
    mnesia:create_table(test_table,
                        [{rocksdb_copies, [node()]},
                         {attributes, record_info(fields, test_table)}]).

init_por() ->
    mnesia:create_table(project,
                        [{porset_copies, all_nodes()}, {attributes, record_info(fields, project)}]).

write_por() ->
    mnesia:dirty_write(project,
                       #project{name = "otp",
                                number = 1,
                                lang = "Erlang"}).

finish_por() ->
    mnesia:delete_table(project).

init() ->
    mnesia:create_table(employee, [{attributes, record_info(fields, employee)}]),
    mnesia:create_table(dept, [{attributes, record_info(fields, dept)}]),
    mnesia:create_table(project, [{attributes, record_info(fields, project)}]),
    mnesia:create_table(manager, [{type, bag}, {attributes, record_info(fields, manager)}]),
    mnesia:create_table(at_dep, [{attributes, record_info(fields, at_dep)}]),
    mnesia:create_table(in_proj, [{type, bag}, {attributes, record_info(fields, in_proj)}]).

delete_employee() ->
    mnesia:delete_table(employee).

create_employee() ->
    mnesia:create_table(employee, [{attributes, record_info(fields, employee)}]).

final() ->
    mnesia:delete_table(employee),
    mnesia:delete_table(dept),
    mnesia:delete_table(project),
    mnesia:delete_table(manager),
    mnesia:delete_table(at_dep),
    mnesia:delete_table(in_proj).

init_proj() ->
    mnesia:create_table(project,
                        [{ram_copies, all_nodes()}, {attributes, record_info(fields, project)}]).

dist_init() ->
    mnesia:create_table(employee,
                        [{ram_copies, ['a@127.0.0.1', 'b@127.0.0.1']},
                         {attributes, record_info(fields, employee)}]),
    mnesia:create_table(dept,
                        [{ram_copies, ['a@127.0.0.1', 'b@127.0.0.1']},
                         {attributes, record_info(fields, dept)}]),
    mnesia:create_table(project,
                        [{ram_copies, ['a@127.0.0.1', 'b@127.0.0.1']},
                         {attributes, record_info(fields, project)}]),
    mnesia:create_table(manager,
                        [{type, bag},
                         {ram_copies, ['a@127.0.0.1', 'b@127.0.0.1']},
                         {attributes, record_info(fields, manager)}]),
    mnesia:create_table(at_dep,
                        [{ram_copies, ['a@127.0.0.1', 'b@127.0.0.1']},
                         {attributes, record_info(fields, at_dep)}]),
    mnesia:create_table(in_proj,
                        [{type, bag},
                         {ram_copies, ['a@127.0.0.1', 'b@127.0.0.1']},
                         {attributes, record_info(fields, in_proj)}]).

create_schema() ->
    mnesia_porset:create_schema(all_nodes()).

delete_schema() ->
    mnesia:delete_schema(all_nodes()).

check_proj() ->
    lists:map(fun(K) -> mnesia:dirty_read(project, K) end, mnesia:dirty_all_keys(project)).

remove_proj() ->
    mnesia:dirty_delete(project, "otp"),
    mnesia:dirty_delete(project, "Naiad").

empty_project() ->
    lists:foreach(fun(K) -> mnesia:dirty_delete(project, K) end,
                  mnesia:dirty_all_keys(project)).

local_copy() ->
    mnesia:create_table(async_op,
                        [{type, bag},
                         {local_content, true},
                         {ram_copies, ['a@127.0.0.1', 'b@127.0.0.1']},
                         {disc_copies, []},
                         {disc_only_copies, []},
                         {attributes, record_info(fields, async_op)}]).

conflict_write() ->
    spawn(fun() ->
             erpc:call('a@127.0.0.1',
                       mnesia,
                       dirty_write,
                       [project,
                        #project{name = "otp",
                                 number = 2,
                                 lang = "Elixir"}])
          end),
    spawn(fun() ->
             erpc:call('b@127.0.0.1',
                       mnesia,
                       dirty_write,
                       [project,
                        #project{name = "otp",
                                 number = 1,
                                 lang = "Erlang"}])
          end).

mnesia_start() ->
    erpc:multicall(
        company:all_nodes(), mnesia, start, []).

add_foo_op() ->
    ets:insert(async_op,
               #async_op{oid = {project, "otp"},
                         ts = os:timestamp(),
                         data_rcd =
                             #project{name = "otp",
                                      number = 1,
                                      lang = "Erlang"},
                         op_type = write}).
