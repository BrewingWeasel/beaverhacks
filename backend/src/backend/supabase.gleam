import envoy
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json

fn supabase_request(path: String) {
  let assert Ok(supabase_url) = envoy.get("SUPABASE_URL")
  let assert Ok(supabase_key) = envoy.get("SUPABASE_KEY")
  let assert Ok(req) = request.to(supabase_url <> "/rest/v1/" <> path)
  req
  |> request.set_header("apikey", supabase_key)
  |> request.set_header("Authorization", "Bearer " <> supabase_key)
}

pub fn create_party_row(id: String, building: String) {
  let body =
    json.object([
      #("id", json.string(id)),
      #("building", json.string(building)),
    ])
    |> json.to_string

  let assert Ok(_) =
    supabase_request("parties")
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_header("Prefer", "return=representation")
    |> request.set_body(body)
    |> httpc.send
  Nil
}

pub fn delete_party_row(id: String) {
  let assert Ok(_) =
    supabase_request("parties?id=eq." <> id)
    |> request.set_method(http.Delete)
    |> httpc.send
  Nil
}

pub fn clear_party_rows() {
  let assert Ok(_) =
    supabase_request("parties?created_at=gte.1970-01-01")
    |> request.set_method(http.Delete)
    |> httpc.send
  Nil
}

pub fn increment_dorm_score(dorm: String, amount: Int) {
  let body =
    json.object([
      #("p_name", json.string(dorm)),
      #("p_amount", json.int(amount)),
    ])
    |> json.to_string

  let assert Ok(_) =
    supabase_request("rpc/increment_score")
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(body)
    |> httpc.send
  Nil
}
