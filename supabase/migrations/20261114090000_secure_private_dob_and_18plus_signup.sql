-- VYLOOP SOCIAL: keep DOB in private.user_birth_dates only.
-- The Auth trigger is the authoritative 18+ gate; browser checks are UX only.

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  base_username text;
  birth_date date;
  birth_date_text text;
begin
  birth_date_text := new.raw_user_meta_data ->> 'date_of_birth';

  if birth_date_text is null
     or birth_date_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'A valid date of birth is required to register.';
  end if;

  begin
    birth_date := birth_date_text::date;
  exception when others then
    raise exception 'A valid date of birth is required to register.';
  end;

  if birth_date::text <> birth_date_text then
    raise exception 'A valid date of birth is required to register.';
  end if;

  if birth_date > current_date then
    raise exception 'Date of birth cannot be in the future.';
  end if;

  if extract(year from age(current_date, birth_date)) < 18 then
    raise exception 'VYLOOP SOCIAL is for users aged 18 and over.';
  end if;

  insert into private.user_birth_dates (user_id, date_of_birth)
  values (new.id, birth_date);

  -- DOB is a transient signup hand-off; remove it from persisted Auth metadata.
  update auth.users
     set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) - 'date_of_birth'
   where id = new.id
     and coalesce(raw_user_meta_data, '{}'::jsonb) ? 'date_of_birth';

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

drop trigger if exists on_auth_user_created_vyloop on auth.users;
create trigger on_auth_user_created_vyloop
after insert on auth.users
for each row execute function private.handle_new_user();

drop function if exists public.handle_new_user();

revoke all on schema private from public, anon, authenticated;
revoke all on table private.user_birth_dates from public, anon, authenticated;

drop policy if exists user_birth_dates_deny_client_access on private.user_birth_dates;
create policy user_birth_dates_deny_client_access
on private.user_birth_dates
for all
to anon, authenticated
using (false)
with check (false);

comment on table private.user_birth_dates is
  'Private VYLOOP date-of-birth records. Not exposed through the Supabase Data API.';
comment on column private.user_birth_dates.date_of_birth is
  'Private birth date used only for server-side 18+ eligibility enforcement.';

-- Existing private rows are already present; remove only matching duplicate Auth metadata.
update auth.users u
   set raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb) - 'date_of_birth'
 where coalesce(u.raw_user_meta_data, '{}'::jsonb) ? 'date_of_birth'
   and exists (
     select 1 from private.user_birth_dates b where b.user_id = u.id
   );
