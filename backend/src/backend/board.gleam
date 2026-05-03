import logging
import gleam/string
import backend/player
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import iv.{type Array}

pub type LocalInfo {
  LocalInfo(owner: player.Id, coordinate: LocalCoordinate)
}

pub type Board {
  Board(
    contents: Array(Array(Tile)),
    desired_contents: Array(Array(Tile)),
    divisions: dict.Dict(player.Id, Division),
    coordinate_owner_map: dict.Dict(Coordinate, LocalInfo),
    height: Int,
    width: Int,
  )
}

pub type Tile {
  Tile(tile_id: Int)
}

pub fn tile_to_json(tile: Tile) -> json.Json {
  let Tile(tile_id:) = tile
  json.int(tile_id)
}

pub type Coordinate {
  Coordinate(x: Int, y: Int)
}

pub type LocalCoordinate {
  LocalCoordinate(Coordinate)
}

pub fn coordinate_to_json(coordinate: LocalCoordinate) -> json.Json {
  let LocalCoordinate(Coordinate(x:, y:)) = coordinate
  json.object([
    #("x", json.int(x)),
    #("y", json.int(y)),
  ])
}

pub fn coordinate_decoder() -> decode.Decoder(LocalCoordinate) {
  use x <- decode.field("x", decode.int)
  use y <- decode.field("y", decode.int)
  decode.success(LocalCoordinate(Coordinate(x:, y:)))
}

pub type Direction {
  Up
  Down
  Left
  Right
}

pub fn direction_decoder() -> decode.Decoder(Direction) {
  use variant <- decode.then(decode.string)
  case variant {
    "up" -> decode.success(Up)
    "down" -> decode.success(Down)
    "left" -> decode.success(Left)
    "right" -> decode.success(Right)
    _ -> decode.failure(Up, "Direction")
  }
}

pub type Division {
  Division(start_x: Int, start_y: Int, end_x: Int, end_y: Int)
}

pub fn division_to_json(division: Division) -> json.Json {
  let Division(start_x:, start_y:, end_x:, end_y:) = division
  json.object([
    #("start_x", json.int(start_x)),
    #("start_y", json.int(start_y)),
    #("end_x", json.int(end_x)),
    #("end_y", json.int(end_y)),
  ])
}

pub type BoardError {
  OutOfBounds
}

fn try(
  result: Result(t, e),
  error: BoardError,
  continue,
) -> Result(new_t, BoardError) {
  result.try(result.map_error(result, fn(_) { error }), continue)
}

fn get_tile(location: Coordinate, board: Board) -> Result(Tile, BoardError) {
  let Coordinate(x:, y:) = location
  use row <- try(iv.get(board.contents, y), OutOfBounds)
  use tile <- try(iv.get(row, x), OutOfBounds)
  Ok(tile)
}

fn set_tile(
  location: Coordinate,
  board: Board,
  tile: Tile,
) -> Result(Board, BoardError) {
  let Coordinate(x:, y:) = location
  use existing_row <- try(iv.get(board.contents, y), OutOfBounds)
  use updated_row <- try(iv.set(existing_row, x, tile), OutOfBounds)
  use updated_contents <- try(
    iv.set(board.contents, y, updated_row),
    OutOfBounds,
  )
  Ok(Board(..board, contents: updated_contents))
}

pub fn get_neighbor(
  board: Board,
  location: Coordinate,
  direction: Direction,
) -> Result(Coordinate, BoardError) {
  let Coordinate(x:, y:) = echo location
  echo direction
  case direction {
    Up if y - 1 >= 0 -> Ok(Coordinate(x:, y: y - 1))
    Down if y <= board.height -> Ok(Coordinate(x:, y: y + 1))
    Right if x <= board.width -> Ok(Coordinate(x: x + 1, y:))
    Left if x - 1 >= 0 -> Ok(Coordinate(x: x - 1, y:))
    _ -> Error(OutOfBounds)
  }
}

pub fn local_to_global(
  board: Board,
  player: player.Id,
  local_coordinate: LocalCoordinate,
) -> Result(Coordinate, BoardError) {
  use division <- try(dict.get(board.divisions, player), OutOfBounds)
  let Division(start_x:, start_y:, ..) = division
  let LocalCoordinate(Coordinate(x: local_x, y: local_y)) = local_coordinate
  Ok(Coordinate(x: start_x + local_x, y: start_y + local_y))
}

pub type UpdatedTiles {
  UpdatedTiles(location: LocalCoordinate, player: player.Id, tile: Tile)
}

pub fn swap_tiles(
  board: Board,
  location1: Coordinate,
  location2: Coordinate,
) -> Result(#(Board, UpdatedTiles, UpdatedTiles), BoardError) {
  echo board.coordinate_owner_map
  use tile1_info <- try(
    dict.get(board.coordinate_owner_map, location1),
    OutOfBounds,
  )
  use tile2_info <- try(
    dict.get(board.coordinate_owner_map, location2),
    OutOfBounds,
  )
  logging.log(logging.Debug, "Owner of tile1 " <> string.inspect(tile1_info.owner))
  logging.log(logging.Debug, "Owner of tile2 " <> string.inspect(tile1_info.owner))

  use tile1 <- result.try(get_tile(location1, board))
  use tile2 <- result.try(get_tile(location2, board))
  logging.log(logging.Debug, "Got tiles")
  use board <- result.try(set_tile(location1, board, tile2))
  use board <- result.try(set_tile(location2, board, tile1))
  logging.log(logging.Debug, "Set tiles")
  Ok(#(
    board,
    UpdatedTiles(tile1_info.coordinate, tile1_info.owner, tile2),
    UpdatedTiles(tile2_info.coordinate, tile2_info.owner, tile1),
  ))
}

pub fn new(players: List(player.Id)) -> Board {
  let total_players = list.length(players)
  let #(divisions, coordinate_owner_map) =
    list.index_fold(
      over: players,
      from: #(dict.new(), dict.new()),
      with: fn(acc, player, index) {
        let #(total_divisions, coordinate_owner_map) = acc
        let #(submap, division) =
          create_divisions(
            start_x: 0,
            end_x: 3,
            start_y: index * 2,
            end_y: index * 2 + 1,
            player:,
          )
        #(
          dict.insert(total_divisions, player, division),
          dict.merge(coordinate_owner_map, submap),
        )
      },
    )

  let width = 4
  let height = 2 * total_players
  let desired_contents = create_board(total_players)

  let contents = shuffle_board(desired_contents, width)
  echo contents

  Board(
    contents:,
    desired_contents:,
    divisions:,
    coordinate_owner_map:,
    width:,
    height:,
  )
}

fn create_board(total_players: Int) {
  int.range(0, 2 * total_players, with: iv.new(), run: fn(acc, _y) {
    let row =
      int.range(0, 4, with: iv.new(), run: fn(acc, x) {
        iv.append(acc, Tile(x % 3))
      })
    iv.append(acc, row)
  })
}

pub fn is_solved(board: Board) -> Bool {
  iv.equal(board.contents, board.desired_contents)
}

fn shuffle_board(board: Array(Array(Tile)), width) -> Array(Array(Tile)) {
  board
  |> iv.flatten
  |> iv.to_list
  |> list.shuffle
  |> list.sized_chunk(width)
  |> list.map(iv.from_list)
  |> iv.from_list
}

fn create_divisions(
  start_x start_x: Int,
  start_y start_y: Int,
  end_x end_x: Int,
  end_y end_y: Int,
  player player: player.Id,
) -> #(dict.Dict(Coordinate, LocalInfo), Division) {
  let division = Division(start_x, start_y, end_x, end_y)
  let submap =
    int.range(from: start_y, to: end_y + 1, with: dict.new(), run: fn(acc, y) {
      let row =
        int.range(from: start_x, to: end_x + 1, with: [], run: fn(acc, x) {
          let local_x = x - start_x
          let local_y = y - start_y
          [
            #(
              Coordinate(x:, y:),
              LocalInfo(player, LocalCoordinate(Coordinate(local_x, local_y))),
            ),
            ..acc
          ]
        })
      dict.merge(acc, dict.from_list(row))
    })
  echo submap
  #(submap, division)
}

pub fn get_local_boards(board: Board) -> List(#(player.Id, Division, List(List(Tile)))) {
  dict.fold(board.divisions, [], fn(acc, player, division) {
    let assert Ok(rows) =
      iv.slice(
        board.contents,
        division.start_y,
        division.end_y - division.start_y + 1,
      )
    echo rows

    let tiles =
      rows
      |> iv.map(fn(row) {
        echo row
        let assert Ok(row) =
          iv.slice(row, division.start_x, division.end_x - division.start_x + 1)
        iv.to_list(row)
      })
      |> iv.to_list()

    [#(player, division, tiles), ..acc]
  })
}
