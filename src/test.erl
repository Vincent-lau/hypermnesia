-module(test).

-compile(export_all).


-record(studnet, {student_id:: integer()}).


main() ->
  S = #studnet{student_id = 1},
  io:format("~p~n", [S]).
