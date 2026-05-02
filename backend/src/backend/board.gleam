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
  json.object([
    #("tile_id", json.int(tile_id)),
  ])
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

pub fn coordinate_decoder() -> decode.Decoder(Coordinate) {
  use x <- decode.field("x", decode.int)
  use y <- decode.field("y", decode.int)
  decode.success(Coordinate(x:, y:))
}

pub type Division {
  Division(start_x: Int, start_y: Int, end_x: Int, end_y: Int)
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

pub type UpdatedTiles {
  UpdatedTiles(location: LocalCoordinate, player: player.Id, tile: Tile)
}

pub fn swap_tiles(
  board: Board,
  location1: Coordinate,
  location2: Coordinate,
) -> Result(#(Board, UpdatedTiles, UpdatedTiles), BoardError) {
  use tile1_info <- try(
    dict.get(board.coordinate_owner_map, location1),
    OutOfBounds,
  )
  use tile2_info <- try(
    dict.get(board.coordinate_owner_map, location2),
    OutOfBounds,
  )
  use tile1 <- result.try(get_tile(location1, board))
  use tile2 <- result.try(get_tile(location1, board))
  use board <- result.try(set_tile(location1, board, tile2))
  use board <- result.try(set_tile(location1, board, tile1))
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
  let desired_contents = iv.repeat(iv.repeat(Tile(1), 4), 2 * total_players)

  let contents = shuffle_board(desired_contents, width)

  Board(
    contents:,
    desired_contents:,
    divisions:,
    coordinate_owner_map:,
    width:,
    height:,
  )
}

pub fn is_solved(board: Board) -> Bool {
  iv.equal(board.contents, board.desired_contents)
}

fn shuffle_board(board: Array(Array(Tile)), width) -> Array(Array(Tile)) {
  let flattened =
    board
    |> iv.flatten
    |> iv.to_list
    |> list.shuffle
    |> iv.from_list
  iv.sized_chunk(flattened, width)
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
    int.range(from: end_y, to: start_y, with: dict.new(), run: fn(acc, y) {
      let row =
        int.range(from: end_x, to: start_x, with: [], run: fn(acc, x) {
          let local_x = start_x - x
          let local_y = start_x - x
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
  #(submap, division)
}
