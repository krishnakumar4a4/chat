-module(chat_client).
-behavior(gen_server).

-export([init/1,handle_call/3,handle_cast/2]).
-export([start_client/1,new_client/1]).

-record(state,{client_state,server_name}).

new_client(ClientName) ->
	ClientDetails = case start_client(ClientName) of
		{ok, ClientPid} ->
		    {client_started,ClientName,ClientPid};
		_ ->
		    not_started
	    end,
    case gen_server:call({global,chat_server}, {link_client,ClientDetails}, infinity) of
	client_linked ->
	    gen_server:call(ClientName,{go_live,ClientName},infinity),
		io:format("client ~p linked to chat_server",[ClientName]);
	_ ->
	    io:format("client ~p : not successfully linked",[ClientName])
    end.
	
start_client(ClientName)->
    gen_server:start_link({local,ClientName},?MODULE,{client_initialised},[{timeout,100}]).
    
init({INIT}) ->
    process_flag(trap_exit,true),
    State = #state{client_state = INIT,server_name=chat_server},
    io:format("server pid assigned to  client is ~p~n",[State]),
    {ok,State}.

handle_call({go_live,ClientName},_From,_State) ->
    keep_listening(ClientName).

keep_listening(ClientName) ->
    OUTMSG = io:get_line(atom_to_list(ClientName)++"> "),
    gen_server:call({global,chat_server},{in_msg,OUTMSG},infinity),
    keep_listening(ClientName).

handle_cast({broadcast,ClientName,INMSG},_State) ->
    io:fwrite("~p> ~p",[ClientName,INMSG]),
	io:format("~p> ~p",[ClientName,INMSG]).
    
