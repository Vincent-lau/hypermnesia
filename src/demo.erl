-module(demo).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("stdlib/include/qlc.hrl").

-include("demo.hrl").

debug_level() ->
    debug.

all_nodes() ->
    ['a@127.0.0.1', 'b@127.0.0.1', 'c@127.0.0.1'].

prepare_once() ->
    delete_schema(),
    create_schema().


proxy_start() ->
    application:start(inet_tcp_proxy_dist).
    % erpc:multicall(demo:all_nodes(), application, start, [inet_tcp_proxy_dist]).


netkern_timeout(T) ->
    erpc:multicall(all_nodes(), net_kernel, set_net_ticktime, [T]).

netkern_timeout() ->
    erpc:multicall(all_nodes(), net_kernel, set_net_ticktime, [1000]).

demo_partition() ->
    demo:proxy_start(),
    demo:mnesia_start(),
    % run on a
    erlang:disconnect_node('b@127.0.0.1'),
    erlang:set_cookie(cookie2),
    demo:write_proj(async_ec, 2),
    mnesia:async_ec(fun() -> mnesia:read({project, 2}) end),
    erlang:set_cookie(cookie),
    mnesia_controller:connect_nodes(['b@127.0.0.1', 'c@127.0.0.1']),
    ets:tab2list(project).


demo_dirty() ->
    demo:proxy_start(),
    demo:netkern_timeout(),
    demo:mnesia_start(),
    % demo:set_debug(debug),
    mnesia:delete_table(project),
    demo:init_proj(dist, set),
    BlockAndWriteDirty =
        fun() ->
           inet_tcp_proxy_dist:block('a@127.0.0.1'),
           demo:write_proj(dirty, 2) % op star
        end,
    % stops all communication from b to a, when run at b
    spawn('b@127.0.0.1', BlockAndWriteDirty),

    % see what is going on on each node
    mnesia:async_dirty(fun() -> mnesia:read({project, 2}) end),
    % run on a
    demo:write_proj(dirty, 2),
    mnesia:async_dirty(fun() -> mnesia:delete({project, 2}) end),

    % check what is going on on c, should still see value
    mnesia:async_dirty(fun() -> mnesia:read({project, 2}) end),

    % allow communication from b to a
    spawn('b@127.0.0.1', inet_tcp_proxy_dist, allow, ['a@127.0.0.1']),
    % and see what happens on a write should propagate to a
    % i.e. op star will now reach a
    mnesia:async_dirty(fun() -> mnesia:read({project, 2}) end).
    % we expect b and c to be empty while a has the value


demo_ec() ->
    demo:proxy_start(),
    demo:netkern_timeout(),
    demo:mnesia_start(),
    % demo:set_debug(debug),
    mnesia:delete_table(project),
    demo:init_proj(dist, pawset),
    BlockAndWriteEc =
        fun() ->
           inet_tcp_proxy_dist:block('a@127.0.0.1'),
           demo:write_proj(async_ec, 2)
        end,
    % stops all communication from b to a, when run at b
    spawn('b@127.0.0.1', BlockAndWriteEc),

    % see what is going on on each node
    mnesia:async_ec(fun() -> mnesia:read({project, 2}) end),
    % run on a
    demo:write_proj(async_ec, 2),
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
    demo:write_proj(ec, Key),
    fprof:trace(stop),
    fprof:profile(file, "prof/" ++ Name ++ ".trace"),
    fprof:analyse({dest, "prof/" ++ Name ++ ".analysis"}).

quick_prof(eflame) ->
    eflame:apply(demo, "stacks.out", write_proj, [ec, 3]).



start() ->
    mnesia_start(),
    set_debug(debug),
    timer:sleep(1000),
    write_proj(ec, 1),
    write_proj(ec, 3),
    check_proj(raw).

    % call from a side
    % rpc:call('b@127.0.0.1', demo, write_proj, [2]).

start_dbg() ->
    debugger:start(),
    mnesia:delete_schema([node()]),
    mnesia:create_schema([node()]),
    mnesia:start(),
    mnesia_pawset:register().

start_por() ->
    create_schema(),
    mnesia_start(),
    rpc:multicall(
        demo:all_nodes(), mnesia_pawset, register, []),
    timer:sleep(100),
    init_por(),
    write_proj(dirty, 1).    % timer:sleep(2000),

                      % mnesia:dirty_delete(project, "otp").

litmus_test_por() ->
    start_por(),
    rpc:call('a@127.0.0.1', demo, write_proj, [dirty, 1]),
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


check() ->
    rpc:multicall(all_nodes(), ets, tab2list, []).

check_por() ->
    T = mnesia_lib:val({mnesia_pawset, project}),
    ets:tab2list(T).

load_bin() ->
    rpc:multicall(all_nodes(), code, purge, [demo]),
    rpc:multicall(all_nodes(), code, load_file, [demo]).

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

select_proj() ->
    mnesia:async_ec(fun() -> mnesia:select(project, [{{project, 4, '$1', '_'}, [], ['$1']}])
                    end).

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
                        [{pawset_copies, all_nodes()}, {attributes, record_info(fields, project)}]).

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

init_proj(dist, Type)
    when Type =:= pawset
         orelse Type =:= porbag
         orelse Type =:= prwset
         orelse Type =:= prwbag ->
    mnesia:create_table(project,
                        [{type, Type},
                         {ram_copies, all_nodes()},
                         {attributes, record_info(fields, project)}]);
init_proj(dist, set) ->
    mnesia:create_table(project,
                        [{type, set},
                         {ram_copies, all_nodes()},
                         {attributes, record_info(fields, project)}]);
init_proj(single, pawset) ->
    mnesia:create_table(project,
                        [{type, pawset},
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
             erpc:call('b@127.0.0',
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
        demo:all_nodes(), mnesia, start, []),
    erpc:multicall(
        demo:all_nodes(), mnesia_lib, set, [debug, debug_level()]).

mnesia_stop() ->
    erpc:multicall(
        demo:all_nodes(), mnesia, stop, []).

add_foo_op() ->
    ets:insert(async_op,
               #async_op{oid = {project, "otp"},
                         ts = os:timestamp(),
                         data_rcd =
                             #project{name = "otp",
                                      number = 1,
                                      lang = "Erlang"},
                         op_type = write}).
