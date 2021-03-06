%Copyright [2012] [Farruco Sanjurjo Arcay]

%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at

%       http://www.apache.org/licenses/LICENSE-2.0

%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.
-module(coello_basic).
-include_lib("amqp_client/include/amqp_client.hrl").

-export([publish/4, publish/5, consume/3, consume/4, cancel/2, ack/3, reject/3]).

-spec publish(Channel::pid(), Data::binary() | list(), Exchange::bitstring(), RoutingKey::bitstring(), ReplyTo::bitstring()) -> ok.
publish(Channel, Data, Exchange, RoutingKey, ReplyTo) when is_binary(Data)->
  Msg = build_amqp_msg([{payload, Data}, {reply_to, ReplyTo}]),
  publish_msg(Channel, Msg, Exchange, RoutingKey);

publish(Channel, Data, Exchange, RoutingKey, ReplyTo) when is_list(Data)->
  publish(Channel, list_to_binary(Data), Exchange, RoutingKey, ReplyTo).

-spec publish(Channel::pid(), Data::binary() | list(), Exchange::bitstring(), RoutingKey::bitstring()) ->ok.
publish(Channel, Data, Exchange, RoutingKey) when is_binary(Data) ->
  Msg = build_amqp_msg([{payload, Data}]),
  publish_msg(Channel, Msg, Exchange, RoutingKey);

publish(Channel, Data, Exchange, RoutingKey) when is_list(Data) ->
  publish(Channel, list_to_binary(Data), Exchange, RoutingKey).

-spec consume(Channel::pid(), QueueName::bitstring(), Callback::fun()) -> {pid(), term()}.
consume(Channel, QueueName, Callback) ->
  consume(Channel, QueueName, Callback, []).
-spec consume(Channel::pid(), QueueName::bitstring(), Callback::fun() , Options ::list({atom(), term()})) ->  {pid(), term()}.
consume(Channel, QueueName, Callback, Options) ->
  Consumer = coello_consumer:start(Callback),

  Method = #'basic.consume'{
    queue = QueueName,
    no_ack = proplists:get_value(no_ack, Options, false)
  },
  Response = amqp_channel:subscribe(Channel, Method, Consumer),
  {Consumer, Response#'basic.consume_ok'.consumer_tag}.

-spec cancel(Channel::pid(), {Consumer::pid(), ConsumerTag::bitstring()}) -> ok.
cancel(Channel, {Consumer, ConsumerTag}) ->
  Method = #'basic.cancel'{consumer_tag = ConsumerTag},
  amqp_channel:call(Channel, Method),
  coello_consumer:stop(Consumer).

-spec ack(Channel :: pid(), DeliveryTag :: term(), Multiple :: byte()) -> ok.
ack(Channel, DeliveryTag, Multiple) ->
  Method = #'basic.ack'{delivery_tag = DeliveryTag, multiple = Multiple},
  amqp_channel:cast(Channel, Method).


-spec reject(Channel :: pid(), DeliveryTag :: term(), Requeue :: boolean()) -> ok.
reject(Channel, DeliveryTag, Requeue) ->
  Method = #'basic.reject'{delivery_tag = DeliveryTag, requeue = Requeue},
  amqp_channel:cast(Channel, Method).

%==================
%
% Internal
%
%==================

-spec build_amqp_msg(list({atom(), term()})) -> #amqp_msg{}.
build_amqp_msg(Options) ->
  build_amqp_msg(#amqp_msg{}, Options).

-spec build_amqp_msg(Msg::#amqp_msg{}, list({atom(), term()})) -> #amqp_msg{}.
build_amqp_msg(Msg, [{payload, Payload} | Tail ]) ->
  build_amqp_msg(Msg#amqp_msg{ payload = Payload}, Tail);

build_amqp_msg(Msg, [{reply_to, ReplyTo} | Tail]) ->
  Props = Msg#amqp_msg.props#'P_basic'{ reply_to = ReplyTo},
  build_amqp_msg(Msg#amqp_msg{ props = Props}, Tail);

build_amqp_msg(Msg, []) ->
  Msg.

-spec publish_msg(Channel::pid, Msg::#amqp_msg{}, Exchange::bitstring(), RoutingKey::bitstring()) ->
  ok.
publish_msg(Channel, Msg, Exchange, RoutingKey) ->
  Method = #'basic.publish'{ exchange = Exchange, routing_key = RoutingKey},
  amqp_channel:cast(Channel, Method, Msg).
