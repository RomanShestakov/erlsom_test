%%%-------------------------------------------------------------------
%%% @author Roman Shestakov <>
%%% @copyright (C) 2011, Roman Shestakov
%%% @doc
%%% API to render graph in dot format.
%%% @end
%%% Created : 18 Jun 2011 by Roman Shestakov <>
%%%-------------------------------------------------------------------

-module(ec_digraphdot).
-export([get_svg/1,
	 convert_graph/1,
	 generate_dot/1]).

-include("../include/record_definitions.hrl").

-define(QUOTED(Val), [$",Val,$"]). 
-define(EDGE(V1, V2), [?QUOTED(V1), "->", ?QUOTED(V2), ";\n"]).
-define(ATTR(V1, V2), [atom_to_list(V1), "=", V2]).
-define(VERTEX_LABEL(V, L), [?QUOTED(V), "[", write_attr(L, [], ","), "]\n"]).
-define(CMD, "dot -Tsvg").
-define(TIMEOUT, 200). 

%%-type vertices() :: [mdigraph:vertex()].
-type mdigraph() :: mdigraph:mdigraph().

-type graph() :: {{graph, {name, Name::string()},
		   {attributes, tuple()},
		   {edges, [any()]},
		   {vertices, [any()]}}}.

%% defaults for graph attributes.
-record(graph_attributes, {ratio = "compress", ranksep = ".75", size = ?QUOTED("7.5, 7.5")}).

record_to_proplist(#graph_attributes{} = Rec) ->
    lists:zip(record_info(fields, graph_attributes), tl(tuple_to_list(Rec))).


%%--------------------------------------------------------------------
%% @doc
%% Generate graph in svg format from mdigraph. 
%% calls dot.exe and collects output from dot.exe which returns to calling function.
%% http://erlang.org/pipermail/erlang-questions/2007-February/025213.html
%% @end
%%--------------------------------------------------------------------
-spec get_svg(mdigraph()) -> [].
get_svg(G) ->
    Dot = generate_dot(G),
    Cmd = ?CMD,
    Opt = [stream, exit_status, use_stdio, stderr_to_stdout, eof],
    Port = open_port({spawn, Cmd}, Opt),
    port_command(Port, Dot),
    get_data_from_port(Port, []).

%%--------------------------------------------------------------------
%% @doc
%% Generate a binary with graph specification in dot format from mdigraph.
%% @end
%%--------------------------------------------------------------------
-spec generate_dot(mdigraph()) -> binary().
generate_dot(G) ->
    %% convert mdigraph into simpler representation.
    IoList = write_dot(convert_graph(G)),
    file:write_file("dotgraph_test.dot", IoList),   
    erlang:iolist_to_binary(IoList).

%% Internal functions.
%%--------------------------------------------------------------------
%% @doc
%% collect output from the port
%% as dot doesn't sent eof, there is no good way to
%% determine the end of output stream, so use timeout
%% @end
%%--------------------------------------------------------------------
-spec get_data_from_port(port(), list()) -> [].
get_data_from_port(Port, Data) ->
    receive
	{P, {data, D1}} ->
	    get_data_from_port(P, [D1 | Data])
    after ?TIMEOUT ->
	    port_close(Port),
	    lists:reverse(Data)
    end.


%%--------------------------------------------------------------------
%% @doc
%% Convert mdigraph or digraph into a simpler representation.
%% @end
%%--------------------------------------------------------------------
-spec convert_graph(mdigraph() | digraph()) -> graph().
convert_graph(G) ->
    %% get edges without default timer name
    Es = filter_hidden([get_edge(mdigraph:edge(G, E)) || E <- mdigraph:edges(G)]),
    Vs = [get_vertex(mdigraph:vertex(G, {V, L})) || {V,L} <- mdigraph:vertices(G), V =/= ?DEFAULT_TIMER_NAME],
    {{graph, {name, get_graph_name(G)}, {attributes, #graph_attributes{}}, {edges, Es}, {vertices, Vs}}}.

%% helper function
-spec get_edge(tuple()) -> {any(), any()}.
get_edge({_E, V1, V2, _L}) ->
    {V1, V2}.

filter_hidden(E)->
    [{V1, V2} || {V1,V2} <- E, V1 =/= ?DEFAULT_TIMER_NAME, V2 =/= ?DEFAULT_TIMER_NAME].

-spec get_vertex({any(), #fsm_state{}}) -> {any(), list(tuple())}.
get_vertex({V, L}) ->
    R = [{state, L#fsm_state.state}, {type, L#fsm_state.type}],
    {V, vertex_attr(R, [])}.

vertex_attr([], Acc) ->
    %% common attributes
    Acc ++ [{style, "filled"}];
vertex_attr([{state, State} | T], Acc) ->
    Attr = 
	case State of
	    ?STATE_UNRNBLE  -> {fillcolor, "blue"};
	    ?STATE_WAITING  -> {fillcolor, "lightblue"};
	    ?STATE_READY    -> {fillcolor, "lightblue"};
	    ?STATE_LAUNCHED -> {fillcolor, "green"};
	    ?STATE_RUNNING  -> {fillcolor, "green"};
	    ?STATE_DONE     -> {fillcolor, "green"};
	    ?STATE_SUCCESS  -> {fillcolor, "green"};
	    ?STATE_FAILED   -> {fillcolor, "red"};
	    ?STATE_CANCELD  -> {fillcolor, "green"};
	    ?STATE_CLONING  -> {fillcolor, "lightblue"};
	    ?STATE_SKIPPED  -> {fillcolor, "lightblue"}
	end,
    vertex_attr(T, [Attr | Acc]);
vertex_attr([{type, Type} | T], Acc) ->
    Attr = 
	case Type of
	    timer   -> {shape, "ellipse"};
	    regular -> {shape, "box"};
	    clone_base -> {shape, "hexagon"};
	    clone -> {shape, "box"}; %% check if correct type
	    'NOP' -> {shape, "ellipse"}
	end,
    vertex_attr(T, [Attr | Acc]).


%%--------------------------------------------------------------------
%% @doc
%% Builts a graph in dot format at a iolist.
%% @end
%%--------------------------------------------------------------------
-spec write_dot(graph()) -> iolist().
write_dot({{graph, {name, Name}, {attributes, Attrb}, {edges, Edges}, {vertices, Vertices}}}) ->
    Acc = write_dot({name, Name}, []),
    Acc1 = write_dot({attributes, Attrb}, Acc),
    Acc2 = write_dot({edges, Edges}, Acc1),
    write_dot({vertex_labels, Vertices}, Acc2).

write_dot({name, Name}, Acc) ->
    [["digraph ", Name, "{\n"] | Acc];
write_dot({attributes, Attrb}, Acc) ->
    write_attr(record_to_proplist(Attrb), Acc, ";\n");
write_dot({edges, Edges}, Acc) ->
    write_edges(Edges, Acc);
write_dot({vertex_labels, Vs}, Acc) ->
    write_vertex_labels(Vs, Acc).


%% writes edges
write_edges([], Acc) ->
    %%["}\n" | Acc];
    Acc;
write_edges([{V1, V2} | T], Acc) ->
    Row = ?EDGE(V1, V2),
    write_edges(T, [Row | Acc]).

%% writes edges
write_attr([], Acc, _D) ->
    Acc;
write_attr([{V1, V2} | T], Acc, D) ->
    Row = ?ATTR(V1, V2) ++ D,
    write_attr(T, [Row | Acc], D).

write_vertex_labels([], Acc) ->
    lists:reverse(["}\n" | Acc]);
write_vertex_labels([{V, L} | T], Acc) ->
    %%Row = ?EDGE(V1, V2),
    Row = ?VERTEX_LABEL(V, L), 
    write_vertex_labels(T, [Row | Acc]).


%%--------------------------------------------------------------------
%% @doc
%% Determine if the graph if mdigraph or digraph.
%% @end
%%--------------------------------------------------------------------
-spec graph_type(mdigraph() | digraph()) -> mdigraph | digraph.	     
graph_type(G)->    
    case element(1, G) of
	mdigraph -> mdigraph;
	digraph -> digraph
    end.

%%--------------------------------------------------------------------
%% @doc
%% Generate the name for graph used in dot file.
%% @end
%%--------------------------------------------------------------------
-spec get_graph_name(mdigraph() | digraph()) -> string().
get_graph_name(G) ->
    case graph_type(G) of
	mdigraph -> "mdigraph";
	digraph -> "digraph"
    end.

