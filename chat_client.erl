-module(chat_client).
-behavior(gen_server).

-export([init/1,handle_call/3,handle_cast/2]).
-export([start_client/1,new_client/1]).

-record(state,{client_state,server_name,socket}).

new_client(ClientName) ->
	start_client(ClientName).

start_client(ClientName)->
    ClientDetails = case gen_server:start_link({local,ClientName},?MODULE,{client_initialised},[{timeout,100}]) of 
		{ok, ClientPid} ->
		    {client_started,ClientName,ClientPid};
		_ ->
		    not_started
	    end,
	case gen_tcp:connect({192,168,1,13},9000,[binary,{active,false}]) of
		{ok,Socket} ->
			ConnectionRequest = [1]++[atom_to_list(element(2,ClientDetails))],
			case gen_tcp:send(Socket,ConnectionRequest) of 
				ok ->
					case gen_tcp:recv(Socket,0) of
						{ok,<<"client_linked">>} ->
							gen_server:call(ClientName,{go_live,ClientName,Socket},infinity),
							io:format("client ~p linked to chat_server~n",[ClientName]),
							spawn(fun() -> listen_broadcast(Socket,ClientName) end);
						_ ->
							io:format("client ~p : not successfully linked~n",[ClientName])
					end;
				Reason ->
					io:format("The data was not sent,reason ~p~n",[Reason])
				end;
		{error,Reason} ->
			io:format("connection request wasn't successful ~p~n",[Reason])
	end.

listen_broadcast(Socket,ClientName) ->
	case gen_tcp:recv(Socket,0) of
		{ok,INMSG} ->
			io:format("~p broadcasted ~n~p",[ClientName,INMSG]),
			gen_server:cast(ClientName,{broadcast,ClientName,INMSG});
		Reason ->
			io:format("Incoming broadcast failed,reason ~p ~p ~p~n",[Reason,Socket,ClientName])
	end,
	listen_broadcast(Socket,ClientName).
    
init({INIT}) ->
    process_flag(trap_exit,true),
    State = #state{client_state = INIT,server_name=chat_server},
    io:format("server pid assigned to  client is ~p~n",[State]),
    {ok,State}.

handle_call({go_live,ClientName,Socket},_From,State) ->
	NewState = State#state{socket = Socket},
    keep_listening(ClientName,Socket),
	{reply,gone_live,NewState}.

keep_listening(ClientName,Socket) ->
    OUTMSG = io:get_line(atom_to_list(ClientName)++"> "),
	OUTMSG1 = [2|[length(atom_to_list(ClientName))|[atom_to_list(ClientName) ++ ">" ++ OUTMSG]]],
	io:format("out msg from client ~p~n",[OUTMSG1]),
	case gen_tcp:send(Socket,OUTMSG1) of
		ok ->
			keep_listening(ClientName,Socket);
		Reason ->
			io:format("The data was not sent,reason ~p",[Reason])
	end.

handle_cast({broadcast,ClientName,INMSG},_State) ->
    io:fwrite("~p> ~p~n",[ClientName,INMSG]),
	io:format("~p> ~p~n",[ClientName,INMSG]).
    
