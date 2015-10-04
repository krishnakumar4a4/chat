-module(lslave).
-behavior(gen_server).

-export([start_slave/1]).
-export([init/1,handle_call/3,terminate/2]).

-record(state,{slave_name,slave_listen_process}).

start_slave(SlaveName) ->
    gen_server:start_link({global,SlaveName},?MODULE,[SlaveName],[{timeout,100}]),
    io:format("started with no prompt"),
    no_prompt().

no_prompt() ->
    no_prompt().

init(SlaveName) ->
    PID = spawn(fun() -> get_broadcast() end),
    State = #state{slave_name = SlaveName,slave_listen_process = PID},
    {ok,State}.

handle_call({in_msg,INMSG},From,State) ->
    %%io:format("~p",[INMSG]),
    State#state.slave_listen_process ! {in_msg,INMSG},
    {reply,delivered,State}.

get_broadcast() ->
    receive
	{in_msg,MSG} ->
	    io:format("~p~n",[MSG]),
	    get_broadcast();
	'EXIT' ->
	    ok
    end.

terminate(Reason,State) ->
    io:format("slave terminated, reason ~p",[Reason]),
    State#state.slave_listen_process ! 'EXIT',
    ok.
    

