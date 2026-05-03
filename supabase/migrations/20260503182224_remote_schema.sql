
  create table "public"."dorm_leaderboard" (
    "name" text not null,
    "score" bigint default '0'::bigint
      );


alter table "public"."dorm_leaderboard" enable row level security;


  create table "public"."parties" (
    "created_at" timestamp with time zone not null default now(),
    "building" text not null,
    "id" uuid not null
      );


alter table "public"."parties" enable row level security;

CREATE UNIQUE INDEX dorm_leaderboard_pkey ON public.dorm_leaderboard USING btree (name);

CREATE UNIQUE INDEX parties_pkey ON public.parties USING btree (id);

alter table "public"."dorm_leaderboard" add constraint "dorm_leaderboard_pkey" PRIMARY KEY using index "dorm_leaderboard_pkey";

alter table "public"."parties" add constraint "parties_pkey" PRIMARY KEY using index "parties_pkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.increment_dorm_score(row_name text, amount integer)
 RETURNS void
 LANGUAGE sql
AS $function$insert into dorm_leaderboard (name, score)
  values (row_name, amount)
  on conflict (row_name) do update
    set score = coalesce(dorm_leaderboard.score, 0) + amount;$function$
;

CREATE OR REPLACE FUNCTION public.increment_player_score(player_id uuid, amount integer)
 RETURNS void
 LANGUAGE sql
AS $function$
  update profiles set total_score = coalesce(total_score, 0) + amount where id = player_id;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_score(p_name text, p_amount integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
begin
  insert into dorm_leaderboard (name, score)
  values (p_name, p_amount)
  on conflict (name) do update
    set score = coalesce(dorm_leaderboard.score, 0) + p_amount;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$begin
  insert into public.profiles (id, building, username)
  values (new.id, new.raw_user_meta_data->>'building', new.raw_user_meta_data->>'username');
  return new;
end;$function$
;

grant delete on table "public"."dorm_leaderboard" to "anon";

grant insert on table "public"."dorm_leaderboard" to "anon";

grant references on table "public"."dorm_leaderboard" to "anon";

grant select on table "public"."dorm_leaderboard" to "anon";

grant trigger on table "public"."dorm_leaderboard" to "anon";

grant truncate on table "public"."dorm_leaderboard" to "anon";

grant update on table "public"."dorm_leaderboard" to "anon";

grant delete on table "public"."dorm_leaderboard" to "authenticated";

grant insert on table "public"."dorm_leaderboard" to "authenticated";

grant references on table "public"."dorm_leaderboard" to "authenticated";

grant select on table "public"."dorm_leaderboard" to "authenticated";

grant trigger on table "public"."dorm_leaderboard" to "authenticated";

grant truncate on table "public"."dorm_leaderboard" to "authenticated";

grant update on table "public"."dorm_leaderboard" to "authenticated";

grant delete on table "public"."dorm_leaderboard" to "service_role";

grant insert on table "public"."dorm_leaderboard" to "service_role";

grant references on table "public"."dorm_leaderboard" to "service_role";

grant select on table "public"."dorm_leaderboard" to "service_role";

grant trigger on table "public"."dorm_leaderboard" to "service_role";

grant truncate on table "public"."dorm_leaderboard" to "service_role";

grant update on table "public"."dorm_leaderboard" to "service_role";

grant delete on table "public"."parties" to "anon";

grant insert on table "public"."parties" to "anon";

grant references on table "public"."parties" to "anon";

grant select on table "public"."parties" to "anon";

grant trigger on table "public"."parties" to "anon";

grant truncate on table "public"."parties" to "anon";

grant update on table "public"."parties" to "anon";

grant delete on table "public"."parties" to "authenticated";

grant insert on table "public"."parties" to "authenticated";

grant references on table "public"."parties" to "authenticated";

grant select on table "public"."parties" to "authenticated";

grant trigger on table "public"."parties" to "authenticated";

grant truncate on table "public"."parties" to "authenticated";

grant update on table "public"."parties" to "authenticated";

grant delete on table "public"."parties" to "service_role";

grant insert on table "public"."parties" to "service_role";

grant references on table "public"."parties" to "service_role";

grant select on table "public"."parties" to "service_role";

grant trigger on table "public"."parties" to "service_role";

grant truncate on table "public"."parties" to "service_role";

grant update on table "public"."parties" to "service_role";


  create policy "Enable insert for authenticated users only"
  on "public"."parties"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Enable select for authenticated users only"
  on "public"."parties"
  as permissive
  for select
  to authenticated
using (true);



