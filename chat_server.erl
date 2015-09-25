-module(chat_server).
-behavior(gen_server).

-export([init/1,handle_call/3]).
-export([start_server/0]).
-record(state,{server_state,server_port,listen_socket,server_pid,clients,clientpid}).

start_server()->
    {ok, _ServerPid} = gen_server:start_link({global,chat_server},?MODULE,server_init,[{timeout,infinity}]),
	case gen_tcp:listen(9000,[binary,{active,false}]) of
		{ok,ListenSocket} ->
			spawn_a_accept_conn(ListenSocket);		
		{error, Reason} ->
			io:format("The reason for not starting the listen socket is :~p~n",[Reason])
	end.

spawn_a_accept_conn(ListenSocket) ->
	check_for_connections(ListenSocket).
	
check_for_connections(ListenSocket) ->
	case gen_tcp:accept(ListenSocket) of
		{ok,Socket} -> 
			spawn(fun() -> start_listen_on_socket(Socket) end),
			spawn_a_accept_conn(ListenSocket);
		{error,Reason} ->
			io:format("The reason for not starting the accept socket is :~p~n",[Reason]);
		Accept ->
			io:format("Still accepting : ~p~n",[Accept])
	end.

start_listen_on_socket(Socket) ->
	case gen_tcp:recv(Socket,0) of
		{ok,Packet} ->
			io:format("Received the following: ~p~n",[binary_to_list(Packet)]),
			differentiate(binary_to_list(Packet),Socket),
			start_listen_on_socket(Socket);
		{error, Reason} ->
			io:format("Response from client:~p~n",[Reason])
	end.

differentiate([1|ClientDetails],Socket) ->
	case gen_server:call({global,chat_server},{link_client,list_to_atom(ClientDetails),Socket},infinity) of
		client_linked ->
			case gen_tcp:send(Socket,"client_linked") of
				ok ->
					ok;
				Reason ->
					io:format("link ack not sent client,reason ~p~n",[Reason])
			end;
		Reason ->
			io:format("client not linked, reason ~p~n",[Reason])
	end;

differentiate([2|[LEN|INMSG]],Socket) ->
	{ClientName,MSG} = lists:split(LEN,INMSG),
	ClientList = gen_server:call({global,chat_server},{in_msg,INMSG,client_name,list_to_atom(ClientName),socket,Socket},infinity),
	io:format("Clients list before going broadcast ~p ~n",[ClientList]),
	broadcast_all(ClientList,MSG,{list_to_atom(ClientName),Socket}).

broadcast_all([],_MSG,{_ClientName,_Socket}) ->
	ok;
	
broadcast_all([{ClientName,Socket}|Rem],MSG,{ClientName,Socket}) ->
	broadcast_all(Rem,MSG,{ClientName,Socket});

broadcast_all([EachClient|Rem],MSG,{ClientName,Socket}) ->
	spawn(fun() -> send_broadcast(EachClient,MSG) end),
	broadcast_all(Rem,MSG,{ClientName,Socket}).
	
send_broadcast({ClientName,Socket},MSG) ->
	case gen_tcp:send(Socket,MSG) of
		ok ->
			io:format("Broadcast sent to ~p~n",[ClientName]);
		Reason ->
			io:format("Broadcast was not sent to ~p, reason is ~p~n",[ClientName,Reason])
	end.

	
init(INIT)->
    process_flag(trap_exit,true),
	State = #state{server_state = INIT,
						clients = [],clientpid = []},
    {ok, State}.
    
    
handle_call({link_client,ClientName,Socket}, _From, State) ->
	Clients = [{ClientName,Socket}|State#state.clients],
	NewState = #state{clients = Clients},
    {reply,client_linked,NewState};

handle_call({in_msg,INMSG,client_name,ClientName,socket,Socket}, {_FromPid,_Ref}, State) ->
    io:format("In msg : ~p~nPresent state~p~n",[INMSG,State]),
    case lists:filtermap(fun(A) -> case A of {ClientName,Socket} -> true;_ -> false end end,State#state.clients) of
		[] -> 
			io:format("~nAn Anonymous has sent you ~p~n",[INMSG]);
			%%lists:foreach(fun(ClientName) -> gen_server:cast(element(1,ClientName),{broadcast,anonymous,INMSG}) end,State#state.clients);
		{FoundName,_} ->
			io:format("~p has sent you ~p~n",[FoundName,INMSG])
			%%lists:foreach(fun({_,ClientName}) -> gen_server:cast(ClientName,{broadcast,FoundName,INMSG}),io:format("message ~p broadcasted to ~p",[INMSG,ClientName]) end,State#state.clients)
    end,
    {reply,State#state.clients,State}.
