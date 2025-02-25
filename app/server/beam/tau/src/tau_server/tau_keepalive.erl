%% Sonic Pi API server process
%% --
%% This file is part of Sonic Pi: http://sonic-pi.net
%% Full project source: https://github.com/sonic-pi-net/sonic-pi
%% License: https://github.com/sonic-pi-net/sonic-pi/blob/main/LICENSE.md
%%
%% Copyright 2021 by Sam Aaron (http://sam.aaron.name/)
%% All rights reserved.
%%
%% Permission is granted for use, copying, modification, and
%% distribution of modified versions of this work as long as this
%% notice is included.
%% ++

-module(tau_keepalive).

-export([start_link/2, init/2, loop/0]).

start_link(KeepAlivePortNum, DaemonPortNum) ->
    spawn_link(?MODULE, init, [KeepAlivePortNum, DaemonPortNum]).

init(KeepAlivePortNum, DaemonPortNum) ->
    logger:error("Connecting tooo Daemon keepalive port via UDP...~p ~p", [KeepAlivePortNum, DaemonPortNum]),

    OSPid = list_to_integer(os:getpid()),
    PidMsg = osc:encode(["/tau/pid", OSPid]),
    {ok, DaemonSocket} = gen_udp:open(0, [binary, {ip, loopback}]),
    erlang:send_after(1000, self(), {send_pid, DaemonSocket, DaemonPortNum, PidMsg, 30}),


    {ok, KeepAliveSocket} = gen_udp:open(0, [binary, {ip, loopback}]),
    KeepAliveMsg = osc:encode(["/daemon/keep-alive"]),
    erlang:send_after(1000, self(), {send_keep_alive, KeepAliveSocket, KeepAlivePortNum, KeepAliveMsg}),
    logger:info("Waiting for keepalive messages..."),
    loop().

loop() ->
    receive
        {send_keep_alive, Sock, PortNum, Msg} ->
            logger:info("Sending keep alive message....", []),
            gen_udp:send(Sock, {127, 0, 0, 1}, PortNum, Msg),
            erlang:send_after(4000, self(), {send_keep_alive, Sock, PortNum, Msg}),
            loop();
        {send_pid, Sock, PortNum, PidMsg, 0} ->
            gen_udp:send(Sock, {127, 0, 0, 1}, PortNum, PidMsg),
            gen_udp:close(Sock),
            loop();
        {send_pid, Sock, PortNum, PidMsg, Count} ->
            gen_udp:send(Sock, {127, 0, 0, 1}, PortNum, PidMsg),
            erlang:send_after(1000, self(), {send_pid, Sock, PortNum, PidMsg, Count - 1}),
            loop();
        Any ->
            logger:error("Tau keepalive received unexpected message: ~p", [Any]),
            loop()
    end.
