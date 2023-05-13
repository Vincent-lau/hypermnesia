-module(test).

-compile(export_all).
-compile(nowarn_export_all).

% -import(foo, [start/0]).

% -record(student, {student_id :: integer()}).



start(A, B) when A == a, B == 2; B == 3 ->
    case A of
        a -> hello;
        b -> world
    end.

loop() ->
    receive
        {student, Student} ->
            io:format("Student: ~p~n", [Student]),
            loop()
    after 0 ->
        io:format("Timeout~n")
    end.
