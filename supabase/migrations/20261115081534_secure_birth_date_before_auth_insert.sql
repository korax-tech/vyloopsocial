-- Keep the DOB out of the Auth row returned by GoTrue.
-- A BEFORE INSERT trigger sanitizes NEW before INSERT ... RETURNING.
-- A deferred FK lets the trigger create the private DOB row before auth.users exists.
alter table private.user_birth_dates
  alter constraint user_birth_dates_user_id_fkey
  deferrable initially deferred;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  birth_date date;
begin
  birth_date := private.validate_adult_birth_date(new.raw_user_meta_data ->> 'date_of_birth');

  insert into private.user_birth_dates (user_id, date_of_birth)
  values (new.id, birth_date);

  -- Remove DOB from NEW itself, before Auth stores or returns the row.
  new.raw_user_meta_data := coalesce(new.raw_user_meta_data, '{}'::jsonb) - 'date_of_birth';

  return new;
end;
$function$;

create or replace function private.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  base_username text;
begin
  base_username := lower(
    regexp_replace(
      coalesce(new.raw_user_meta_data ->> 'username', split_part(coalesce(new.email, 'user'), '@', 1)),
      '[^a-zA-Z0-9_]',
      '',
      'g'
    )
  );

  if length(base_username) < 3 then
    base_username := 'user' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    left(base_username, 20) || '_' || substr(replace(new.id::text, '-', ''), 1, 6),
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      ''
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$function$;

revoke all on function private.handle_new_user() from public, anon, authenticated, service_role;
revoke all on function private.handle_new_user_profile() from public, anon, authenticated, service_role;

drop trigger if exists on_auth_user_created_vyloop on auth.users;
drop trigger if exists on_auth_user_created_vyloop_profile on auth.users;

create trigger on_auth_user_created_vyloop
before insert on auth.users
for each row execute function private.handle_new_user();

create trigger on_auth_user_created_vyloop_profile
after insert on auth.users
for each row execute function private.handle_new_user_profile();
