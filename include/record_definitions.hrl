%%%-------------------------------------------------------------------
%%% @author Roman Shestakov <>
%%% @copyright (C) 2011, Roman Shestakov
%%% @doc
%%%
%%% @end
%%% Created : 22 Jun 2011 by Roman Shestakov <>
%%%-------------------------------------------------------------------


%% possible FSM states
-define(STATE_UNRNBLE, unrunnable).
-define(STATE_LINKING, linking).
-define(STATE_WAITING, waiting).
-define(STATE_CLONING, cloning).
-define(STATE_READY, ready).
-define(STATE_LAUNCHED, launched).
-define(STATE_RUNNING, running).
-define(STATE_CANCELD, cancelled).
-define(STATE_SUCCESS, succeeded).
-define(STATE_DONE, done).
-define(STATE_FAILED, fail).
-define(STATE_SKIPPED, skipped).

%%--------------------------------------------------------------------
%% @doc
%% Possible states for fsm process.
%% @end
%%--------------------------------------------------------------------
-type state() :: 
	?STATE_UNRNBLE | 
	?STATE_LINKING |
	?STATE_WAITING |
	?STATE_READY |
	?STATE_LAUNCHED |
	?STATE_RUNNING |
	?STATE_DONE |
	?STATE_FAILED |
	?STATE_SUCCESS |
	?STATE_CANCELD |
	?STATE_CLONING |
	?STATE_SKIPPED.


%% possible type for processes
-define(TYPE_REGULAR, regular).
-define(TYPE_NOP, 'NOP').
-define(TYPE_CLONE_BASE, clone_base).
-define(TYPE_TIMER, timer).
-type process_type() :: ?TYPE_NOP |
			?TYPE_REGULAR |
			?TYPE_CLONE_BASE |
			?TYPE_TIMER.

%% -type(date()::{Year::integer(),
%% 	       Month::integer(),
%% 	       Day::integer()}).

%% -type(time()::{Hour::integer(),
%% 	       Minute::integer(),
%% 	       Second::integer()}).

-type dayofweek()::'mon' | 
		   'tue' |
		   'wed' |
		   'thu' |
		   'fri' |
		   'sat' |
		   'sun'.

-type numbered_day_of_week() :: 1..7.

-type dayofmonth() :: 1..31.
-type dayofyear() :: 1..365.

%% copy from calendar module as this types are not exported 
-type year() :: non_neg_integer().
%% -type year1970() :: 1970..10000.	% should probably be 1970..
-type month()    :: 1..12.
-type day()      :: 1..31.
-type hour()     :: 0..23.
-type minute()   :: 0..59.
-type second()   :: 0..59.
%% -type daynum()   :: 1..7.
%% -type ldom()     :: 28 | 29 | 30 | 31. % last day of month
%% -type weeknum()  :: 1..53.

%% -type t_now()    :: {MegaSecs :: non_neg_integer(),
%%                      Secs :: non_neg_integer(),
%%                      MicroSecs :: non_neg_integer()}.

-type date()         :: {year(),month(),day()}.
-type t_time()         :: {hour(),minute(),second()}.
%% -type t_datetime()     :: {t_date(),t_time()}.
%% -type t_datetime1970() :: {{year1970(),month(),day()},t_time()}.
%% -type t_yearweeknum()  :: {year(),weeknum()}.

-type filename() :: file:filename().
-type dirname() :: filename().
-type processfile() :: {{file, filename()}, {template, filename()}}.

%% types to define running dates/ time schedule for a job. 
-record(schedule, {time :: start_time(), days :: start_date()}).
-type offset_type() :: none | b.
-type start_time() :: {{offset, non_neg_integer(), offset_type()}, {time, t_time()}}.
%% 0 in dom and doy means nor restrictions on mnth or year days.
-type start_date() :: {{dow, [dayofweek()]},{dom, [dayofmonth() | 0]}, {doy, [dayofyear() | 0]}}.
-type schedule() :: #schedule{}.


%% full process name {process_name, scheduler_name}, returned by macro PNAME_SNAME
-type full_name() :: {atom(), atom()}.

%% %% RunDate
%% -type(rundate() :: date()).

%% parsers and scanners
-type parser() :: 'ec_daytime_parser' | 'ec_parser'.
-type scanner() :: 'ec_daytime_scanner' | 'ec_scanner'.

-type state_history() :: {From::atom(), To::atom()}.
			 
%% used to pass extra info about the source process which posted event
-record(evn_src, {name, run_date, state}).

%% used as state for fsm process
-record(fsm_state, {name :: string(), %% process name
		    description :: string(), %% short description
		    command :: string(),
		    env = [], %% application environment, list of variables
		    host = [] :: [string()], %% hosts where the processes will be scheduled to run
		    depends_on = [] :: [string()], %% depent on processes - children
		    repeat :: integer(),
		    start_after :: string(),
		    days :: string(),
		    type = regular :: process_type(),
		    clonesourcelist :: {file, Filename::string()},
		    run_date :: date(), %% rundate for the process
		    scheduler_name :: atom(), %% name of scheduler for a process, e.g.'20110620'
		    parents = dict:new() :: dict(),
		    children = dict:new() :: dict(),
		    pid :: any(), %% self(), pid of local process running the task 
		    tsk_pid :: any(), %% pid of the remote process executing task
		    state :: state(), %% current fsm state of the process
		    job_definition :: string(),
		    node :: {string(), pid()},
		    date_offset :: integer(),
		    schedule :: schedule(), %% full date/time schedule for job execution. 
		    start_time :: t_time(), %% time a process started executing.
		    end_time :: t_time(),   %% time the process completed execution.
		    exit_status :: any(), %% exit status of the external executable.
		    exit_description :: any(), %% more detailes of exit_status in case of errors
		    logfile :: string(), 
		    helper_pid :: any(), %% pid of the helper process , spawns for each fsm
		    state_history = [] :: [state_history()], %% history of states the process has been to
		    is_clonned = false :: boolean() %% used by clone_base to indicate that process was cloned
 		   }).
	      
-type fsm_node() :: #fsm_state{}.

%% record task is defined in _ec_dispatcher project

%% used to pass info from parent to children
-record(parent_info, {name,
		      pid,
		      state,
		      type,
		      clonesourcelist,
		      is_clonned}).

%%--------------------------------------------------------------------
%% @doc
%% Gives process name and scheduler name pair for a process
%% @end
%%--------------------------------------------------------------------
-define(PNAME_SNAME(State), {State#fsm_state.name, State#fsm_state.scheduler_name}).
-define(SNAME(State), State#fsm_state.scheduler_name).
-define(SEND_ALL_EVENT(Pid, Event), gen_fsm:send_all_state_event(Pid, Event)).
-define(SEND_EVENT(Pid, Event), send_event(Pid, Event)).
-define(ADD_NODE(PName_SName, Data), ec_graph:update_graph(vertex, PName_SName, Data)).
-define(ADD_EDGE(PName_SName, Data), ec_graph:update_graph(edge, PName_SName, Data)).
-define(SEND_CHECK_STATE_EVENT(DepName, DepStateName),
	gen_fsm:send_all_state_event(self(), {?EVENT_PARENT_STATE_CNG, DepName, DepStateName})).
-define(NTF_CHLDR(State, NameRunDate, Event), notify_children(State#fsm_state.children, NameRunDate, Event)).
-define(RCV_MSG, "RCV_MSG: Event: ~p, STATE: ~p, Name: ~p").
-define(UNX_MSG, "UNX_MSG: Event: ~p, STATE: ~p, Name: ~p, Date: ~p").
-define(NO_INTERLEAF, false).
-define(INTERLEAF, true).
-define(TIMER_NAME, "TimerJobName").
-define(TIME_NOW, time()).
-define(DATE_OFFSET(State), ec_time_fns:get_date_offset(date(), State#fsm_state.run_date)). 
-define(STATE_HISTORY(From, To, State), [{From, To} | State#fsm_state.state_history]).
%% events
-define(EVENT_INIT_FSM, init_fsm).
-define(EVENT_PARENT_STATE_CNG, parent_state_change).
-define(EVENT_CHK_INTERLEAVING, check_interleaving).
-define(EVENT_LINK, link_to_parents).
%%-define(EVENT_LINK_TO_CLN, link_to_clones).
-define(EVENT_CHECK_DAYS, check_days).
-define(EVENT_TRG_INTERL, trigger_intrl).
-define(EVENT_DPCY_SATISF, dpcy_satisfied).
%%-define(EVENT_CLN_DPCY_SATISF, cln_dpcy_satisfied).
-define(EVENT_RPL_TO_LINK_MSG, reply_link).
-define(EVENT_SET_TIMER, set_timer).
-define(EVENT_TIME_IS_UP, time_is_up).
-define(EVENT_INIT_CLN, init_cloning).
-define(EVENT_DONE, done).
-define(EVENT_NO_UNLNKD_PRN, no_unlinked_parents).
-define(EVENT_UPD_NODE, update_node).
-define(EVENT_CHK_DEPENDENCY, check_dependency).
-define(EVENT_ADD_EDGE, add_edge).
-define(EVENT_NTF_CHILDREN, notify_children).
-define(EVENT_START_CLN, start_clones).
-define(DISPATCHER, ec_dispatcher).

%% name of default timer, if a process doesn't have start_after dependency, it will have dependency on default timer
%% and this will be hidden dependency, so we need to define the constant to be able to filter out this node from the graph.
-define(DEFAULT_TIMER_NAME, "Start:0+00:00:00").
