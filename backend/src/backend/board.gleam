import backend/player
import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import iv.{type Array}

pub type Board {
  Board(
    contents: Array(Array(Tile)),
    divisions: List(Division),
    coordinate_owner_map: dict.Dict(Coordinate, player.Id),
  )
}

pub type Tile {
  Tile(Int)
}

pub type Coordinate {
  Coordinate(x: Int, y: Int)
}

pub type Division {
  Division(
    start_x: Int,
    start_y: Int,
    end_x: Int,
    end_y: Int,
    player: player.Id,
  )
}

pub type BoardError {
  OutOfBounds
}

fn get_tile(location: Coordinate, board: Board) -> Result(Tile, BoardError) {
  let Coordinate(x:, y:) = location
  use row <- result.try(
    result.map_error(iv.get(board.contents, y), fn(_) { OutOfBounds }),
  )
  use tile <- result.try(
    result.map_error(iv.get(row, x), fn(_) { OutOfBounds }),
  )
  Ok(tile)
}

pub fn swap_tiles(
  location1: Coordinate,
  location2: Coordinate,
  board: Board,
) -> Result(Board, BoardError) {
  let tile1_owner = dict.get(board.coordinate_owner_map, location1)
  let tile2_owner = dict.get(board.coordinate_owner_map, location2)
  todo
}

pub fn new(players: List(player.Id)) -> Board {
  let total_players = list.length(players)
  let #(divisions, coordinate_owner_map) =
    list.index_fold(
      over: players,
      from: #([], dict.new()),
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
          [division, ..total_divisions],
          dict.merge(coordinate_owner_map, submap),
        )
      },
    )
  Board(
    contents: iv.repeat(iv.repeat(Tile(1), 4), 2 * total_players),
    divisions:,
    coordinate_owner_map:,
  )
}

fn create_divisions(
  start_x start_x: Int,
  start_y start_y: Int,
  end_x end_x: Int,
  end_y end_y: Int,
  player player: player.Id,
) -> #(dict.Dict(Coordinate, player.Id), Division) {
  let division = Division(start_x, start_y, end_x, end_y, player)
  let submap =
    int.range(from: end_y, to: start_y, with: dict.new(), run: fn(acc, y) {
      let row =
        int.range(from: end_x, to: start_x, with: [], run: fn(acc, x) {
          [#(Coordinate(x:, y:), player), ..acc]
        })
      dict.merge(acc, dict.from_list(row))
    })
  #(submap, division)
}
