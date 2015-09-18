-module(chat_client).
-behavior(gen_server).

-export([init/1,handle_call/3]).
-export([start_client/2]).

-record(state,{client_state,server_pid}).

start_client(ClientName,ServPid)->
    gen_server:start_link({local,ClientName},?MODULE,{ServPid,client_initialised},[{timeout,100}]).
    
init({ServPid,INIT}) ->
    process_flag(trap_exit,true),
    State = #state{client_state = INIT,server_pid=ServPid},
    %%io:format("server pid assigned to  client is ~p~n",[State]),
    {ok,State}.

handle_call({go_live,ClientName},From,State) ->
    keep_listening(ClientName).

keep_listening(ClientName) ->
    INMSG = io:get_line(atom_to_list(ClientName)++"> "),
    gen_server:call({global,chat_server},{in_msg,INMSG},infinity),
    keep_listening(ClientName).
