-module(chat_server).
-behavior(gen_server).

-export([init/1,handle_call/3]).
-export([start_server/0]).
-record(state,{server_state,server_pid,clients,clientpid}).

start_server()->
    {ok, ServerPid} = gen_server:start_link({global,chat_server},?MODULE,server_init,[{timeout,infinity}]).

init(INIT)->
    process_flag(trap_exit,true),
    State = #state{server_state = INIT,
                    clients = [],clientpid = []},
    {ok, State}.
    
    
handle_call({link_client,ClientDetails}, From, State) ->
    NewState = case ClientDetails of
		{client_started,ClientName,ClientPid} ->
			Clients = [{ClientName,element(3,ClientDetails)}|State#state.clients],
			#state{clients = Clients};
		_ ->
		    State
	    end,
    {reply,client_linked,NewState};

handle_call({in_msg,INMSG}, {FromPid,_Ref}, State) ->
    io:format("In msg : ~p~nPresent state~p~n",[INMSG,State]),
    case lists:keyfind(FromPid,2,State#state.clients) of
	false-> 
	    io:format("~nAn Anonymous has sent you ~p~n",[INMSG]),
	    lists:foreach(fun(ClientName) -> gen_server:cast(element(1,ClientName),{broadcast,anonymous,INMSG}) end,State#state.clients);
	{FoundName,_} ->
	    io:format("~p has sent you ~p~n",[FoundName,INMSG]),
	    lists:foreach(fun({_,ClientName}) -> gen_server:cast(ClientName,{broadcast,FoundName,INMSG}),io:format("message ~p broadcasted to ~p",[INMSG,ClientName]) end,State#state.clients)
    end,
    {reply,"delivered",State}.
