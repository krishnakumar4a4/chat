-module(chat_server).
-behavior(gen_server).

-export([init/1,handle_call/3]).
-export([start_server/0,new_client/1]).
-record(state,{server_state,server_pid,clients,clientpid}).

start_server()->
    {ok, ServerPid} = gen_server:start_link({global,chat_server},?MODULE,server_init,[{timeout,infinity}]).

init(INIT)->
    process_flag(trap_exit,true),
    State = #state{server_state = INIT,
                    clients = [],clientpid = []},
    {ok, State}.
    
new_client(ClientName) ->
    case gen_server:call({global,chat_server}, {start_client,ClientName}, infinity) of
	{client_started,_,_} ->
	    gen_server:call(ClientName,{go_live,ClientName},infinity);
	_ ->
	    io:format("client ~p : not successfully started",[ClientName])
    end.
    
handle_call({start_client,ClientName}, From, State) ->
    Reply = case chat_client:start_client(ClientName,self()) of
		{ok, ClientPid} ->
		    {client_started,ClientName,ClientPid};
		_ ->
		    not_started
	    end,
    Clients = [{ClientName,element(3,Reply)}|State#state.clients],
    NewState = #state{clients = Clients},
    %% Clients = [ClientName|State#state.clients],
    %% ClientPids = [element(3,Reply)|State#state.clientpid],
    %% NewState = #state{clients = Clients,clientpid = ClientPids},
    %%io:format("~p~p",[Reply,NewState]),
    {reply,Reply,NewState};

handle_call({in_msg,INMSG}, {FromPid,_Ref}, State) ->
    io:format("In msg : ~p~nPresent state~p~n",[INMSG,State]),
    case lists:keyfind(FromPid,2,State#state.clients) of
	false-> 
	    io:format("~nAn Anonymous has sent you ~p~n",[INMSG]),
	    lists:foreach(fun(ClientName) -> gen_server:cast(element(1,ClientName),{broadcast,anonymous,INMSG}) end,State#state.clients);
	{FoundName,_} ->
	    io:format("~p has sent you ~p~n",[FoundName,INMSG]),
	    lists:foreach(fun(ClientName) -> gen_server:cast(element(1,ClientName),{broadcast,FoundName,INMSG}) end,State#state.clients)
    end,
    {reply,"delivered",State}.
