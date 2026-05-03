import envoy
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json

pub fn create_party_row(id: String, building: String) {
  let body =
    json.object([
      #("id", json.string(id)),
      #("building", json.string(building)),
    ])
    |> json.to_string

  let assert Ok(supabase_url) = envoy.get("SUPABASE_URL")
  let assert Ok(supabase_key) = envoy.get("SUPABASE_KEY")

  let assert Ok(req) = request.to(supabase_url <> "/rest/v1/parties")

  let assert Ok(_) =
    req
    |> request.set_method(http.Post)
    |> request.set_header("apikey", supabase_key)
    |> request.set_header("Authorization", "Bearer " <> supabase_key)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_header("Prefer", "return=representation")
    |> request.set_body(body)
    |> httpc.send

  Nil
}

pub fn delete_party_row(id: String) {
  let assert Ok(supabase_url) = envoy.get("SUPABASE_URL")
  let assert Ok(supabase_key) = envoy.get("SUPABASE_KEY")

  let assert Ok(req) =
    request.to(supabase_url <> "/rest/v1/parties?id=eq." <> id)

  let assert Ok(_) =
    req
    |> request.set_method(http.Delete)
    |> request.set_header("apikey", supabase_key)
    |> request.set_header("Authorization", "Bearer " <> supabase_key)
    |> httpc.send

  Nil
}
