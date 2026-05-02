import backend/party
import backend/router
import gleam/erlang/process
import logging
import mist

pub fn main() {
  logging.set_level(logging.Debug)

  let assert Ok(party) = party.new()

  let assert Ok(_) =
    router.mist_router(_, party)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}
