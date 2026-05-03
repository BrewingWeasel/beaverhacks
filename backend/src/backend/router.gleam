import backend/party
import backend/party_manager
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

pub type RouterParams {
  RouterParams(party_manager: party_manager.PartyManagerActor)
}

pub fn mist_router(
  request: request.Request(mist.Connection),
  router_params: RouterParams,
) -> response.Response(mist.ResponseData) {
  let secret_key_base = wisp.random_string(64)
  case request.path_segments(request) {
    ["ws"] -> upgrade_to_websockets(request, router_params)
    _ -> wisp_mist.handler(wisp_handle_request, secret_key_base)(request)
  }
}

fn wisp_handle_request(_request) {
  wisp.not_found()
}

type WebsocketState {
  WebsocketState(
    to_client_message_subject: process.Subject(party.ToClientMessage),
    party_info: option.Option(PartyInfo),
    party_manager: party_manager.PartyManagerActor,
  )
}

type PartyInfo {
  PartyInfo(
    party_id: party_manager.PartyId,
    party_connection: party.PartyActor,
    id: player.Id,
    is_leader: Bool,
  )
}

fn upgrade_to_websockets(req, router_params) {
  mist.websocket(
    req,
    on_init: init_websocket(_, router_params),
    handler: handle_websocket_message,
    on_close: close_websocket_connection,
  )
}

fn init_websocket(
  _websocket_connection: mist.WebsocketConnection,
  router_params: RouterParams,
) -> #(WebsocketState, option.Option(process.Selector(party.ToClientMessage))) {
  let to_client_subject: process.Subject(party.ToClientMessage) =
    process.new_subject()
  let selector = process.new_selector()
  let selector = process.select(selector, to_client_subject)

  #(
    WebsocketState(
      to_client_subject,
      option.None,
      party_manager: router_params.party_manager,
    ),
    option.Some(selector),
  )
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
        Ok(party.CreateParty(building, description)) -> {
          case state.party_info {
            option.Some(_) -> {
              logging.log(logging.Warning, "Ignoring create_party after join")
              mist.continue(state)
            }
            option.None -> {
              let created =
                party_manager.new_party(
                  state.party_manager,
                  building,
                  description,
                )
              let id =
                party.join(created.party, state.to_client_message_subject)
              let player.Id(player_id) = id
              process.send(
                state.to_client_message_subject,
                party.PartyCreated(created.id.id, player_id),
              )
              mist.continue(
                WebsocketState(
                  ..state,
                  party_info: option.Some(PartyInfo(
                    party_id: created.id,
                    party_connection: created.party,
                    id:,
                    is_leader: True,
                  )),
                ),
              )
            }
          }
        }
        Ok(party.JoinParty(id)) -> {
          case state.party_info {
            option.Some(_) -> {
              logging.log(logging.Warning, "Ignoring join_party after join")
              mist.continue(state)
            }
            option.None -> {
              case
                party_manager.join_party(
                  state.party_manager,
                  party_manager.PartyId(id),
                )
              {
                Ok(party_connection) -> {
                  let player_id =
                    party.join(
                      party_connection,
                      state.to_client_message_subject,
                    )
                  let player.Id(raw_player_id) = player_id
                  process.send(
                    state.to_client_message_subject,
                    party.PartyJoined(id, raw_player_id),
                  )
                  mist.continue(
                    WebsocketState(
                      ..state,
                      party_info: option.Some(PartyInfo(
                        party_id: party_manager.PartyId(id),
                        party_connection:,
                        id: player_id,
                        is_leader: False,
                      )),
                    ),
                  )
                }
                Error(Nil) -> {
                  logging.log(
                    logging.Warning,
                    "Tried to join unknown party " <> id,
                  )
                  mist.continue(state)
                }
              }
            }
          }
        }
        Ok(message) -> {
          case state.party_info {
            option.Some(party_info) ->
              party.handle_ws_message(
                party_info.party_connection,
                message,
                state.to_client_message_subject,
                party_info.id,
              )
            option.None ->
              logging.log(logging.Warning, "Ignoring party message before join")
          }
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
      case server_message {
        party.PartyClosed -> mist.stop()
        _ -> mist.continue(state)
      }
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

fn close_websocket_connection(websocket_state: WebsocketState) -> Nil {
  case websocket_state.party_info {
    option.None -> Nil
    option.Some(party_info) -> {
      case party_info.is_leader {
        True ->
          party_manager.delete_party(
            websocket_state.party_manager,
            party_info.party_id,
          )
        False -> party.leave(party_info.party_connection, party_info.id)
      }
    }
  }
}
