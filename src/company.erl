-module(company).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("stdlib/include/qlc.hrl").

-include("company.hrl").

debug_level() ->
    none.

all_nodes() ->
    ['a@127.0.0.1', 'b@127.0.0.1', 'c@127.0.0.1'].

demo_ec() ->
    company:mnesia_start(),
    company:set_debug(debug),
    mnesia:delete_table(project),
    company:init_proj(dist, porset),
    BlockAndWriteEc =
        fun() ->
           inet_tcp_proxy_dist:block('a@127.0.0.1'),
           company:write_proj(ec, 2)
        end,
    % stops all communcation from b to a
    spawn('b@127.0.0.1', BlockAndWriteEc),

    % see what is going on on each node
    mnesia:async_ec(fun() -> mnesia:read({project, 2}) end),
    % run on a
    company:write_proj(ec, 2),
    mnesia:async_ec(fun() -> mnesia:delete({project, 2}) end),

    % check what is going on on c, should still see value
    mnesia:async_ec(fun() -> mnesia:read({project, 2}) end),

    % allow communication from b to a
    spawn('b@127.0.0.1', inet_tcp_proxy_dist, allow, ['a@127.0.0.1']),
    % and see what happens on a write should propagate to a
    mnesia:async_ec(fun() -> mnesia:read({project, 2}) end).

start_test(dirty) ->
    mnesia_start(),
    set_debug(debug),
    timer:sleep(1000),
    mnesia:delete_table(project),
    init_proj(dist, set),
    write_proj(dirty, 1).

quick_prof(fprof, Name, Key) ->
    fprof:trace(start, "prof/" ++ Name ++ ".trace"),
    company:write_proj(ec, Key),
    fprof:trace(stop),
    fprof:profile(file, "prof/" ++ Name ++ ".trace"),
    fprof:analyse({dest, "prof/" ++ Name ++ ".analysis"}).

quick_prof(eflame) ->
    eflame:apply(company, "stacks.out", write_proj, [ec, 3]).

demo_dirty() ->
    company:mnesia_start(),
    company:set_debug(debug),
    mnesia:delete_table(project),
    company:init_proj(dist, set),
    BlockAndWrite =
        fun() ->
           inet_tcp_proxy_dist:block('a@127.0.0.1'),
           company:write_proj(dirty, 2)
        end,
    spawn('b@127.0.0.1', BlockAndWrite),
    % run on a
    company:write_proj(dirty, 2),
    mnesia:async_dirty(fun() -> mnesia:delete({project, 2}) end),
    % what happens on c? both write should be deleted
    mnesia:async_dirty(fun() -> mnesia:read({project, 2}) end),
    % allow communication from b to a
    spawn('b@127.0.0.1', inet_tcp_proxy_dist, allow, ['a@127.0.0.1']),
    % what happens on a? write from b will propagate from c to a
    mnesia:async_dirty(fun() -> mnesia:read({project, 2}) end).

start() ->
    mnesia_start(),
    set_debug(debug),
    timer:sleep(1000),
    write_proj(ec, 1),
    write_proj(ec, 3),
    check_proj(raw).

    % call from a side
    % rpc:call('b@127.0.0.1', company, write_proj, [2]).

start_dbg() ->
    debugger:start(),
    mnesia:delete_schema([node()]),
    mnesia:create_schema([node()]),
    mnesia:start(),
    mnesia_porset:register().

start_por() ->
    create_schema(),
    mnesia_start(),
    rpc:multicall(
        company:all_nodes(), mnesia_porset, register, []),
    timer:sleep(100),
    init_por(),
    write_proj(dirty, 1).    % timer:sleep(2000),

                      % mnesia:dirty_delete(project, "otp").

litmus_test_por() ->
    start_por(),
    rpc:call('a@127.0.0.1', company, write_proj, [dirty, 1]),
    rpc:call('a@127.0.0.1', mnesia, dirty_delete, [project, "otp"]),
    rpc:call('c@127.0.0.1', mnesia, dirty_read, [project, "otp"]).

load_test_por() ->
    start_por(),
    crazy_write(1000).

crazy_write(N) when N == 3 ->
    ok;
crazy_write(N) ->
    write_proj(dirty, N),
    crazy_write(N - 1).

write_and_read(N) when is_number(N) ->
    write_proj(dirty, N),
    rpc:multicall(all_nodes(), mnesia, dirty_read, [project, N]).

prepare_por() ->
    delete_schema(),
    create_schema(),
    mnesia_start(),
    rpc:multicall(all_nodes(), mnesia_porset, register, []).

check() ->
    rpc:multicall(all_nodes(), ets, tab2list, []).

check_por() ->
    T = mnesia_lib:val({mnesia_porset, project}),
    ets:tab2list(T).

load_bin() ->
    rpc:multicall(all_nodes(), code, purge, [company]),
    rpc:multicall(all_nodes(), code, load_file, [company]).

set_debug(Debug) ->
    erpc:multicall(all_nodes(), mnesia_monitor, set_env, [debug, Debug]).

stop_all() ->
    rpc:eval_everywhere(all_nodes(), erlang, halt, []).

write_proj(trans, N) ->
    Trans =
        fun() ->
           mnesia:write(#project{name = N,
                                 number = 2,
                                 lang = "Erlang"})
        end,
    mnesia:transaction(Trans);
write_proj(async_ec, N) ->
    Fun = fun() ->
             mnesia:write(#project{name = N,
                                   number = 10,
                                   lang = "Erlang"})
          end,
    mnesia:async_ec(Fun);
write_proj(sync_ec, N) ->
    Fun = fun() ->
             mnesia:write(#project{name = N,
                                   number = 10,
                                   lang = "Erlang"})
          end,
    mnesia:sync_ec(Fun);
write_proj(dirty, 1) ->
    Fun = fun() ->
             mnesia:write(#project{name = "otp",
                                   number = 1,
                                   lang = "Erlang"})
          end,
    mnesia:async_dirty(Fun);
% write_proj(dirty, 2) ->
%     case mnesia:dirty_read(project, "otp") of
%         [A = #project{name = "otp",
%                       number = 1,
%                       lang = "Erlang"}] ->
%             mnesia:dirty_write(project,
%                                #project{name = "top",
%                                         number = A#project.number + 1,
%                                         lang = "Erlang"});
%         [] ->
%             write_proj(dirty, 2)
%     end;
write_proj(dirty, N) when is_number(N) ->
    Fun = fun() ->
             mnesia:write(#project{name = N,
                                   number = 1,
                                   lang = "Erlang"})
          end,
    mnesia:async_dirty(Fun).


write_proj(async_ec, K, V) ->
    Fun = fun() ->
                mnesia:write(#project{name = K,
                                    number = V,
                                    lang = "Erlang"})
            end,
    mnesia:async_ec(Fun).



read_proj(ec, N) when is_number(N) ->
    Fun = fun() -> mnesia:read(project, N) end,
    mnesia:async_ec(Fun).

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

init_proj(dist, Type) when Type =:= porset orelse Type =:= porbag->
    mnesia:create_table(project,
                        [{type, Type},
                         {ram_copies, all_nodes()},
                         {attributes, record_info(fields, project)}]);
init_proj(dist, set) ->
    mnesia:create_table(project,
                        [{type, set},
                         {ram_copies, all_nodes()},
                         {attributes, record_info(fields, project)}]);
init_proj(single, porset) ->
    mnesia:create_table(project,
                        [{type, porset},
                         {ram_copies, [node()]},
                         {attributes, record_info(fields, project)}]).

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
    mnesia:create_schema(all_nodes()).

delete_schema() ->
    mnesia:delete_schema(all_nodes()).

check_proj(raw) ->
    ets:tab2list(project);
check_proj(fine) ->
    Keys = mnesia:async_ec(fun mnesia:all_keys/1, [project]),
    lists:map(fun(K) -> mnesia:async_ec(fun mnesia:read/2, [project, K]) end, Keys).

remove_proj() ->
    mnesia:dirty_delete(project, "otp"),
    mnesia:dirty_delete(project, "Naiad").

empty_project() ->
    lists:foreach(fun(K) -> mnesia:dirty_delete(project, K) end,
                  mnesia:dirty_all_keys(project)).

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

mnesia_restart() ->
    mnesia_stop(),
    mnesia_start().

mnesia_start() ->
    erpc:multicall(
        company:all_nodes(), mnesia, start, []),
    erpc:multicall(
        company:all_nodes(), mnesia_lib, set, [debug, debug_level()]).

mnesia_stop() ->
    erpc:multicall(
        company:all_nodes(), mnesia, stop, []).

add_foo_op() ->
    ets:insert(async_op,
               #async_op{oid = {project, "otp"},
                         ts = os:timestamp(),
                         data_rcd =
                             #project{name = "otp",
                                      number = 1,
                                      lang = "Erlang"},
                         op_type = write}).
