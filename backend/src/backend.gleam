import backend/party_manager
import backend/router
import envoy
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import logging
import mist
import simplifile

pub fn main() {
  logging.set_level(logging.Info)
  load_env()

  let assert Ok(party_manager) = party_manager.start()

  let assert Ok(_) =
    router.mist_router(_, router.RouterParams(party_manager))
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

fn load_env() {
  let assert Ok(env_file) = simplifile.read(".env.local")

  string.split(env_file, "\n")
  |> list.filter(fn(line) { line != "" })
  |> list.each(fn(line) {
    // sometimes can be more than one = in the line
    let splited_line = string.split(line, "=")
    let key =
      list.first(splited_line)
      |> result.unwrap("")
      |> string.trim()

    // so for those cases we need to join the rest of the line
    // and split again
    let value =
      list.drop(splited_line, 1)
      |> string.join("=")
      |> string.trim()

    envoy.set(key, value)
  })
}
