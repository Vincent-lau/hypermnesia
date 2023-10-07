-record(employee, {emp_no,
                   name,
                   salary,
                   sex,
                   phone,
                   room_no}).

-record(dept, {id, 
               name}).

-record(project, {id,
                  lang}).


-record(manager, {emp,
                  dept}).

-record(at_dep, {emp,
                 dept_id}).

-record(in_proj, {emp,
                  proj_name}).

-record(async_op, {oid, ts, data_rcd, op_type}).


-record(test_table, {id, name, age}).
