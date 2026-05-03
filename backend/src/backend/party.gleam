import backend/board
import backend/player
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import iv
import logging

const score_power: Float = 1.1

const milliseconds_gained: Int = 15_000

const initial_time_left: Int = 20_000

pub type ToClientMessage {
  PartyCreated(id: String, player_id: Int)
  PartyJoined(id: String, player_id: Int)
  PartyClosed
  ChatMessageSent(contents: String)
  TileUpdated(coordinate: board.LocalCoordinate, new_tile: board.Tile)
  BoardCreated(
    full_board: List(List(board.Tile)),
    local_board: List(List(board.Tile)),
    division: board.Division,
    score: Int,
    time_left: Int,
  )
  RanOutOfTime(score: Int)
  BoardSolved
}

pub fn to_client_message_to_json(
  to_client_message: ToClientMessage,
) -> json.Json {
  case to_client_message {
    PartyCreated(id:, player_id:) ->
      json.object([
        #("type", json.string("party_created")),
        #("id", json.string(id)),
        #("player_id", json.int(player_id)),
      ])
    PartyJoined(id:, player_id:) ->
      json.object([
        #("type", json.string("party_joined")),
        #("id", json.string(id)),
        #("player_id", json.int(player_id)),
      ])
    PartyClosed ->
      json.object([
        #("type", json.string("party_closed")),
      ])
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
    BoardCreated(full_board:, local_board:, division:, score:, time_left:) ->
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
        #("division", board.division_to_json(division)),
        #("score", json.int(score)),
        #("time_left", json.int(time_left)),
      ])
    BoardSolved ->
      json.object([
        #("type", json.string("board_solved")),
      ])
    RanOutOfTime(score:) ->
      json.object([
        #("type", json.string("ran_out_of_time")),
        #("score", json.int(score)),
      ])
  }
}

pub type PartyMode {
  Lobby
  InGame(board: board.Board, timer_process: process.Pid)
}

pub type PartyModel {
  PartyModel(
    clients: dict.Dict(player.Id, process.Subject(ToClientMessage)),
    subject: process.Subject(ToPartyMessage),
    current_mode: PartyMode,
    remaining_time: Int,
    next_id: Int,
    score: Int,
    level: Int,
    round_start_time: timestamp.Timestamp,
  )
}

pub type ToPartyMessage {
  Join(process.Subject(ToClientMessage), process.Subject(player.Id))
  Leave(player.Id)
  Close
  FromClientMessage(
    DirectWebsocketMessage,
    reply_to: process.Subject(ToClientMessage),
    id: player.Id,
  )
  PartyTimeUp
}

pub type DirectWebsocketMessage {
  SendMessage(contents: String)
  CreateParty(building: String, description: String)
  JoinParty(id: String)
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
    "create_party" -> {
      use building <- decode.field("building", decode.string)
      use description <- decode.field("description", decode.string)
      decode.success(CreateParty(building:, description:))
    }
    "join_party" -> {
      use id <- decode.field("id", decode.string)
      decode.success(JoinParty(id:))
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
  actor.new_with_initialiser(1000, fn(subject: process.Subject(ToPartyMessage)) {
    let selector = process.new_selector() |> process.select(subject)
    actor.initialised(PartyModel(
      clients: dict.new(),
      remaining_time: initial_time_left,
      next_id: 0,
      current_mode: Lobby,
      score: 0,
      level: 1,
      round_start_time: timestamp.system_time(),
      subject:,
    ))
    |> actor.returning(subject)
    |> actor.selecting(selector)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

fn assume_board_open(
  party: PartyModel,
  continue: fn(#(board.Board, process.Pid)) ->
    actor.Next(PartyModel, ToPartyMessage),
) {
  case party.current_mode {
    Lobby -> actor.continue(party)
    InGame(board, timer_pid) -> continue(#(board, timer_pid))
  }
}

fn try_board(board_result, party, continue) {
  case board_result {
    Ok(board) -> continue(board)
    Error(e) -> {
      logging.log(
        logging.Warning,
        "Received invalid board operation: " <> string.inspect(e),
      )
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
    Leave(id) -> {
      actor.continue(
        PartyModel(..party, clients: dict.delete(party.clients, id)),
      )
    }
    Close -> {
      dict.each(party.clients, fn(_id, member) {
        process.send(member, PartyClosed)
      })
      case party.current_mode {
        Lobby -> Nil
        InGame(_, timer_pid) -> process.kill(timer_pid)
      }
      actor.continue(
        PartyModel(..party, clients: dict.new(), current_mode: Lobby),
      )
    }
    FromClientMessage(SendMessage(message), _reply_to, _id) -> {
      dict.each(party.clients, fn(_id, member) {
        process.send(member, ChatMessageSent(message))
      })

      actor.continue(party)
    }
    PartyTimeUp -> {
      dict.each(party.clients, fn(_id, member) {
        process.send(member, RanOutOfTime(party.score))
      })
      actor.continue(PartyModel(..party, current_mode: Lobby))
    }
    FromClientMessage(StartGame, _reply_to, _id) -> {
      start_board(party)
    }
    FromClientMessage(SwapTile(from_local_position, direction), _reply_to, id) -> {
      echo from_local_position
      use #(board, timer_pid) <- assume_board_open(party)
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

      logging.log(
        logging.Debug,
        "Swapping tile to " <> string.inspect(to_position),
      )

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
          process.kill(timer_pid)
          process.sleep(1000)
          let assert Ok(score_multipler) =
            float.power(score_power, int.to_float(party.level))

          let round_completion_time =
            timestamp.difference(
              party.round_start_time,
              timestamp.system_time(),
            )

          let time_penalty =
            float.min(duration.to_seconds(round_completion_time), 30.0)
          let updated_party =
            PartyModel(
              ..party,
              score: party.score
                + float.round({ 100.0 -. time_penalty } *. score_multipler),
              level: party.level + 1,
              remaining_time: party.remaining_time
                - duration.to_milliseconds(round_completion_time)
                + milliseconds_gained,
            )
          start_board(updated_party)
        }
        False ->
          actor.continue(
            PartyModel(..party, current_mode: InGame(board, timer_pid)),
          )
      }
    }
    // hacky but whatever
    FromClientMessage(CreateParty(..), _, _) -> actor.continue(party)
    FromClientMessage(JoinParty(..), _, _) -> actor.continue(party)
  }
}

fn start_board(party: PartyModel) {
  let board = board.new(dict.keys(party.clients))
  let timer_pid =
    process.spawn_unlinked(fn() {
      process.sleep(party.remaining_time)
      process.send(party.subject, PartyTimeUp)
    })

  let board_contents = iv.to_list(iv.map(board.desired_contents, iv.to_list))

  let local_boards = board.get_local_boards(board)
  let round_start_time = timestamp.system_time()
  let assert Ok(_) =
    list.try_each(local_boards, fn(local_board) {
      let #(player, division, board) = local_board
      use client <- result.try(dict.get(party.clients, player))
      process.send(
        client,
        BoardCreated(
          board_contents,
          board,
          division,
          party.score,
          time_left: party.remaining_time,
        ),
      )

      Ok(Nil)
    })

  actor.continue(
    PartyModel(
      ..party,
      current_mode: InGame(board, timer_pid),
      round_start_time:,
    ),
  )
}

pub fn join(party: PartyActor, client: process.Subject(ToClientMessage)) {
  actor.call(party.data, 1000, Join(client, _))
}

pub fn leave(party: PartyActor, id: player.Id) -> Nil {
  actor.send(party.data, Leave(id))
}

pub fn close(party: PartyActor) -> Nil {
  actor.send(party.data, Close)
}

pub fn handle_ws_message(
  party: PartyActor,
  message: DirectWebsocketMessage,
  reply_to: process.Subject(ToClientMessage),
  id: player.Id,
) -> Nil {
  actor.send(party.data, FromClientMessage(message, reply_to, id))
}
