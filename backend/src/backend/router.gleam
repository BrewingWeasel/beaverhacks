import backend/party
import backend/player
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/option
import gleam/string
import logging
import mist
import wisp
import wisp/wisp_mist

pub fn mist_router(
  request: request.Request(mist.Connection),
  party: party.PartyActor,
) -> response.Response(mist.ResponseData) {
  let secret_key_base = wisp.random_string(64)
  case request.path_segments(request) {
    ["ws"] -> upgrade_to_websockets(request, party)
    _ -> wisp_mist.handler(wisp_handle_request, secret_key_base)(request)
  }
}

fn wisp_handle_request(_request) {
  wisp.not_found()
}

type WebsocketState {
  WebsocketState(
    to_client_message_subject: process.Subject(party.ToClientMessage),
    party_connection: party.PartyActor,
    id: player.Id,
  )
}

fn upgrade_to_websockets(req, party) {
  mist.websocket(
    req,
    on_init: init_websocket(_, party),
    handler: handle_websocket_message,
    on_close: close_websocket_connection,
  )
}

fn init_websocket(
  _websocket_connection: mist.WebsocketConnection,
  party,
) -> #(WebsocketState, option.Option(process.Selector(party.ToClientMessage))) {
  let to_client_subject: process.Subject(party.ToClientMessage) =
    process.new_subject()
  let id = party.join(party, to_client_subject)
  let selector = process.new_selector()
  let selector = process.select(selector, to_client_subject)

  #(WebsocketState(to_client_subject, party, id), option.Some(selector))
}

fn handle_websocket_message(
  state: WebsocketState,
  message: mist.WebsocketMessage(party.ToClientMessage),
  connection: mist.WebsocketConnection,
) -> mist.Next(WebsocketState, party.ToClientMessage) {
  case message {
    mist.Text("ping") -> {
      logging.log(logging.Info, "Client connected")
      mist.continue(state)
    }
    mist.Text(text) -> {
      logging.log(logging.Info, "Received message " <> text)
      case json.parse(text, party.direct_websocket_message_decoder()) {
        Ok(message) -> {
          party.handle_ws_message(
            state.party_connection,
            message,
            state.to_client_message_subject,
            state.id,
          )
          mist.continue(state)
        }
        Error(_) -> {
          logging.log(logging.Warning, "Received invalid message " <> text)
          mist.continue(state)
        }
      }
    }
    mist.Binary(binary) -> {
      logging.log(
        logging.Warning,
        "Ignoring received binary message: " <> string.inspect(binary),
      )
      mist.continue(state)
    }
    mist.Custom(server_message) -> {
      logging.log(logging.Debug, "Sent message: " <> string.inspect(message))
      let encoded =
        server_message |> party.to_client_message_to_json |> json.to_string()

      case mist.send_text_frame(connection, encoded) {
        Error(_) ->
          logging.log(
            logging.Warning,
            "Failed to encode message: " <> string.inspect(server_message),
          )
        Ok(Nil) -> Nil
      }
      mist.continue(state)
    }
    mist.Closed | mist.Shutdown -> {
      logging.log(
        logging.Info,
        "shutting down connection [" <> string.inspect(process.self()) <> "]",
      )
      mist.stop()
    }
  }
}

fn close_websocket_connection(_websocket_state: WebsocketState) -> Nil {
  Nil
}
