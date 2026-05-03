import backend/party
import backend/supabase
import gleam/dict
import gleam/erlang/process
import gleam/otp/actor
import youid/uuid

pub type Model {
  Model(parties: dict.Dict(PartyId, party.PartyActor))
}

pub type PartyManagerActor =
  actor.Started(process.Subject(Message))

pub fn start() -> Result(
  actor.Started(process.Subject(Message)),
  actor.StartError,
) {
  actor.new(Model(parties: dict.new()))
  |> actor.on_message(handle_message)
  |> actor.start
}

pub type PartyId {
  PartyId(id: String)
}

pub type CreatedParty {
  CreatedParty(id: PartyId, party: party.PartyActor)
}

pub type Message {
  NewParty(
    building: String,
    description: String,
    reply_to: process.Subject(CreatedParty),
  )
  JoinParty(PartyId, reply_to: process.Subject(Result(party.PartyActor, Nil)))
  DeleteParty(PartyId)
}

fn handle_message(model: Model, messsage: Message) -> actor.Next(Model, a) {
  case messsage {
    NewParty(building, _description, reply_to) -> {
      let party_id = PartyId(uuid.to_string(uuid.v7()))
      let assert Ok(party) = party.new()
      supabase.create_party_row(party_id.id, building)
      process.send(reply_to, CreatedParty(id: party_id, party:))

      let parties = dict.insert(model.parties, party_id, party)
      actor.continue(Model(parties:))
    }
    JoinParty(id, reply_to) -> {
      echo model.parties
      case echo dict.get(model.parties, id) {
        Ok(party) -> {
          process.send(reply_to, Ok(party))
          actor.continue(model)
        }
        Error(Nil) -> {
          process.send(reply_to, Error(Nil))
          actor.continue(model)
        }
      }
    }
    DeleteParty(id) -> {
      case dict.get(model.parties, id) {
        Ok(party) -> party.close(party)
        Error(Nil) -> Nil
      }
      supabase.delete_party_row(id.id)
      actor.continue(Model(parties: dict.delete(model.parties, id)))
    }
  }
}

pub fn new_party(
  party_manager: PartyManagerActor,
  building: String,
  description: String,
) -> CreatedParty {
  actor.call(party_manager.data, 1000, NewParty(building, description, _))
}

pub fn join_party(
  party_manager: PartyManagerActor,
  id: PartyId,
) -> Result(party.PartyActor, Nil) {
  actor.call(party_manager.data, 1000, JoinParty(id, _))
}

pub fn delete_party(party_manager: PartyManagerActor, id: PartyId) -> Nil {
  actor.send(party_manager.data, DeleteParty(id))
}
