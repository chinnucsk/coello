-module(coello_basic_spec).
-include_lib("espec/include/espec.hrl").
-include_lib("hamcrest/include/hamcrest.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

spec() ->
  before_all(fun() ->
        meck:new([amqp_channel]),
        meck:expect(amqp_channel, cast, 3, ok)
    end),
  after_all(fun() ->
        meck:unload([amqp_channel])
    end),
  describe("publish/4", fun() ->
        it("should publish a binary message", fun()->
              Exchange   = <<"unexchangedocarallo">>,
              RoutingKey = <<"tienrutaporahi">>,
              Data = crypto:rand_bytes(30),
              Msg       = #amqp_msg{payload = Data },
              Method     = #'basic.publish'{ exchange = Exchange, routing_key = RoutingKey},
              ok         = coello_basic:publish(channel, Data, Exchange,RoutingKey),

              assert_that(meck:called(amqp_channel, cast, [channel, Method, Msg]), is(true))
          end),
        it("should publish a text message", fun()->
              Exchange   = <<"unexchangedocarallo">>,
              RoutingKey = <<"tienrutaporahi">>,
              Msg       = #amqp_msg{payload = <<"abc">> },
              Method     = #'basic.publish'{ exchange = Exchange, routing_key = RoutingKey},
              ok         = coello_basic:publish(channel, "abc", Exchange,RoutingKey),

              assert_that(meck:called(amqp_channel, cast, [channel, Method, Msg]), is(true))
          end)
    end),
  describe("consume", fun() ->
        it("should consume messages and invoke the passed in callback", fun()->
              meck:expect(amqp_channel, subscribe, 3, ok),

              QueueName = <<"queue">>,
              Method = #'basic.consume'{ queue = QueueName},
              Pid        = self(),
              Consumer = coello_basic:consume(channel, QueueName, fun(_) -> Pid ! on_message end),
              Consumer ! {#'basic.deliver'{}, #amqp_msg{}},

              assert_that(
                receive
                  on_message ->
                    true
                after 500 ->
                    false
                end, is(true)),
              assert_that(meck:called(amqp_channel, subscribe, [channel, Method, Consumer]), is(true))
          end)
    end),
  describe("cancel", fun() ->
        it("should cancel a consumer", fun() ->
              meck:new(coello_consumer),
              meck:expect(coello_consumer, stop, 1, ok),

              ok = coello_basic:cancel(consumer),

              assert_that(meck:called(coello_consumer, stop, [consumer]), is(true)),

              meck:unload(coello_consumer)
          end)
    end).