import backend/supabase
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

pub type PartyManagerActor = actor.Started(process.Subject(Message))

pub fn start() -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  actor.new(Model(parties: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.start
}

pub type PartyId {
  PartyId(id: String)
}

pub type Message {
  NewParty(building: String, description: String, reply_to: process.Subject(party.PartyActor))
  JoinParty(PartyId, reply_to: process.Subject(Result(party.PartyActor, Nil)))
}

fn handle_message(model: Model, messsage: Message) -> actor.Next(Model, a) {
  case messsage {
    NewParty(building, _description, reply_to) -> {
      let party_id = PartyId(uuid.to_string(uuid.v7()))
      let assert Ok(party) = party.new()
      supabase.create_party_row(party_id.id, building)
      process.send(reply_to, party)

      let parties = dict.insert(model.parties, party_id, party)
      actor.continue(Model(parties:))
    }
    JoinParty(id, reply_to) -> {
      case dict.get(model.parties, id) {
        Ok(party) -> { process.send(reply_to, Ok(party)) actor.continue(model) }
        Error(Nil) -> actor.continue(model)
      }
    }
  }
}

pub fn new_party(party_manager: PartyManagerActor, building: String, description: String) -> party.PartyActor {
  actor.call(party_manager.data, 1000, NewParty(building, description, _))
}

pub fn join_party(party_manager: PartyManagerActor, id: PartyId) -> Result(party.PartyActor, Nil) {
  actor.call(party_manager.data, 1000, JoinParty(id, _))
}
