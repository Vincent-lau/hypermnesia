-module(test).

-compile(export_all).


-record(studnet, {student_id:: integer()}).


main() ->
  lager:debug("start").
