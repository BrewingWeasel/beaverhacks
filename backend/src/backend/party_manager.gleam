import gleam/erlang/process
import youid/uuid
import gleam/otp/actor
import gleam/dict
import backend/party

pub type Model {
  Model(
    parties: dict.Dict(PartyId, party.PartyActor),
  )
}

pub fn start() {
  actor.new(Model(parties: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.start
}

pub type PartyId {
  PartyId(String)
}

pub type Message {
  NewParty(reply_to: process.Subject(party.PartyActor))
  JoinParty(PartyId, reply_to: process.Subject(party.PartyActor))
}

fn handle_message(model: Model, messsage: Message) -> actor.Next(Model, a) {
  case messsage {
    NewParty(reply_to) -> {
      let party_id = PartyId(uuid.to_string(uuid.v7()))
      let assert Ok(party) = party.new()
      process.send(reply_to, party)

      let parties = dict.insert(model.parties, party_id, party)
      actor.continue(Model(parties:))
    }
    JoinParty(id, reply_to) -> {
      case dict.get(model.parties, id) {
        Ok(party) -> { process.send(reply_to, party) actor.continue(model) }
        Error(Nil) -> actor.continue(model)
      }
    }
  }
}
