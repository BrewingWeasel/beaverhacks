import gleam/string
import logging
import backend/board
import backend/player
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/result
import iv

pub type ToClientMessage {
  ChatMessageSent(contents: String)
  TileUpdated(coordinate: board.LocalCoordinate, new_tile: board.Tile)
  BoardCreated(
    full_board: List(List(board.Tile)),
    local_board: List(List(board.Tile)),
  )
  BoardSolved
}

pub fn to_client_message_to_json(
  to_client_message: ToClientMessage,
) -> json.Json {
  case to_client_message {
    ChatMessageSent(contents:) ->
      json.object([
        #("type", json.string("chat_message_sent")),
        #("contents", json.string(contents)),
      ])
    TileUpdated(coordinate:, new_tile:) ->
      json.object([
        #("type", json.string("tile_updated")),
        #("coordinate", board.coordinate_to_json(coordinate)),
        #("new_tile", board.tile_to_json(new_tile)),
      ])
    BoardCreated(full_board:, local_board:) ->
      json.object([
        #("type", json.string("board_created")),
        #(
          "full_board",
          json.array(full_board, json.array(_, board.tile_to_json)),
        ),
        #(
          "local_board",
          json.array(local_board, json.array(_, board.tile_to_json)),
        ),
      ])
    BoardSolved ->
      json.object([
        #("type", json.string("board_solved")),
      ])
  }
}

pub type PartyMode {
  Lobby
  InGame(board.Board)
}

pub type PartyModel {
  PartyModel(
    clients: dict.Dict(player.Id, process.Subject(ToClientMessage)),
    current_mode: PartyMode,
    next_id: Int,
  )
}

pub type ToPartyMessage {
  Join(process.Subject(ToClientMessage), process.Subject(player.Id))
  FromClientMessage(
    DirectWebsocketMessage,
    reply_to: process.Subject(ToClientMessage),
    id: player.Id,
  )
}

pub type DirectWebsocketMessage {
  SendMessage(contents: String)
  SwapTile(from: board.LocalCoordinate, direction: board.Direction)
  StartGame
}

pub fn direct_websocket_message_decoder() -> decode.Decoder(
  DirectWebsocketMessage,
) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "send_message" -> {
      use contents <- decode.field("contents", decode.string)
      decode.success(SendMessage(contents:))
    }
    "swap_tile" -> {
      use from <- decode.field("from", board.coordinate_decoder())
      use direction <- decode.field("direction", board.direction_decoder())
      decode.success(SwapTile(from:, direction:))
    }
    "start_game" -> decode.success(StartGame)
    _ -> decode.failure(SendMessage(contents: ""), "DirectWebsocketMessage")
  }
}

pub type PartyActor =
  actor.Started(process.Subject(ToPartyMessage))

pub fn new() -> Result(
  actor.Started(process.Subject(ToPartyMessage)),
  actor.StartError,
) {
  actor.new(PartyModel(clients: dict.new(), next_id: 0, current_mode: Lobby))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn assume_board_open(
  party: PartyModel,
  continue: fn(board.Board) -> actor.Next(PartyModel, ToPartyMessage),
) {
  case party.current_mode {
    Lobby -> actor.continue(party)
    InGame(board) -> continue(board)
  }
}

fn try_board(board_result, party, continue) {
  case board_result {
    Ok(board) -> continue(board)
    Error(e) -> { 
      logging.log(logging.Warning, "Received invalid board operation: " <> string.inspect(e))
      actor.continue(party) 
    }
  }
}

fn handle_message(
  party: PartyModel,
  message: ToPartyMessage,
) -> actor.Next(PartyModel, ToPartyMessage) {
  case message {
    Join(client, reply_to) -> {
      let new_clients =
        dict.insert(party.clients, player.Id(party.next_id), client)
      process.send(reply_to, player.Id(party.next_id))

      actor.continue(
        PartyModel(..party, clients: new_clients, next_id: party.next_id + 1),
      )
    }
    FromClientMessage(SendMessage(message), _reply_to, _id) -> {
      dict.each(party.clients, fn(_id, member) {
        process.send(member, ChatMessageSent(message))
      })

      actor.continue(party)
    }
    FromClientMessage(StartGame, _reply_to, _id) -> {
      let board = board.new(dict.keys(party.clients))

      let board_contents = iv.to_list(iv.map(board.desired_contents, iv.to_list))

      let local_boards = board.get_local_boards(board)
      let assert Ok(_) =
        list.try_each(local_boards, fn(local_board) {
          let #(player, board) = local_board
          use client <- result.try(dict.get(party.clients, player))
          process.send(client, BoardCreated(board_contents, board))
          Ok(Nil)
        })

      actor.continue(PartyModel(..party, current_mode: InGame(board)))
    }
    FromClientMessage(SwapTile(from_local_position, direction), _reply_to, id) -> {
      echo from_local_position
      use board <- assume_board_open(party)
      echo board
      use from <- try_board(
        board.local_to_global(board, id, from_local_position),
        party,
      )

      logging.log(logging.Debug, "Swapping from " <> string.inspect(from))

      use to_position <- try_board(
        board.get_neighbor(board, from, direction),
        party,
      )

      logging.log(logging.Debug, "Swapping tile to " <> string.inspect(to_position))

      use #(board, updated1, updated2) <- try_board(
        board.swap_tiles(board, from, to_position),
        party,
      )
      echo board
      let send_updated_message = fn(updated: board.UpdatedTiles) {
        use client <- result.try(dict.get(party.clients, updated.player))
        process.send(client, TileUpdated(updated.location, updated.tile))
        Ok(Nil)
      }

      let assert Ok(_) = send_updated_message(updated1)
      let assert Ok(_) = send_updated_message(updated2)

      case board.is_solved(board) {
        True -> {
          dict.each(party.clients, fn(_id, member) {
            process.send(member, BoardSolved)
          })
        }
        False -> Nil
      }

      actor.continue(PartyModel(..party, current_mode: InGame(board)))
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
  id: player.Id,
) -> Nil {
  actor.send(party.data, FromClientMessage(message, reply_to, id))
}
