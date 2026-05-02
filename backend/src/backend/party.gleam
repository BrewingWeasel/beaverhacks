import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/json
import gleam/otp/actor

pub type ToClientMessage {
  ChatMessageSent(contents: String)
}

pub fn to_client_message_to_json(
  to_client_message: ToClientMessage,
) -> json.Json {
  let ChatMessageSent(contents:) = to_client_message
  json.object([
    #("contents", json.string(contents)),
  ])
}

pub type Id {
  Id(Int)
}

pub type PartyModel {
  PartyModel(
    clients: dict.Dict(Id, process.Subject(ToClientMessage)),
    next_id: Int,
  )
}

pub type ToPartyMessage {
  Join(process.Subject(ToClientMessage), process.Subject(Id))
  FromClientMessage(
    DirectWebsocketMessage,
    reply_to: process.Subject(ToClientMessage),
  )
}

pub type DirectWebsocketMessage {
  SendMessage(contents: String)
}

pub fn direct_websocket_message_decoder() -> decode.Decoder(
  DirectWebsocketMessage,
) {
  use contents <- decode.field("contents", decode.string)
  decode.success(SendMessage(contents:))
}

pub type PartyActor =
  actor.Started(process.Subject(ToPartyMessage))

pub fn new() -> Result(
  actor.Started(process.Subject(ToPartyMessage)),
  actor.StartError,
) {
  actor.new(PartyModel(clients: dict.new(), next_id: 0))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  party: PartyModel,
  message: ToPartyMessage,
) -> actor.Next(PartyModel, ToPartyMessage) {
  case message {
    Join(client, reply_to) -> {
      let new_clients = dict.insert(party.clients, Id(party.next_id), client)
      process.send(reply_to, Id(party.next_id))

      actor.continue(PartyModel(
        clients: new_clients,
        next_id: party.next_id + 1,
      ))
    }
    FromClientMessage(SendMessage(message), _reply_to) -> {
      dict.each(party.clients, fn(_id, member) {
        process.send(member, ChatMessageSent(message))
      })

      actor.continue(party)
    }
  }
}

pub fn join(party: PartyActor, client: process.Subject(ToClientMessage)) {
  actor.call(party.data, 1000, Join(client, _))
}

pub fn handle_ws_message(
  party: PartyActor,
  message: DirectWebsocketMessage,
  reply_to: process.Subject(ToClientMessage),
) -> Nil {
  actor.send(party.data, FromClientMessage(message, reply_to))
}

pub fn decode_direct_ws_message(
  text: String,
) -> Result(DirectWebsocketMessage, a) {
  todo
}
