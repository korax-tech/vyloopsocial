-- Centralize strict date parsing and adult-age calculation for signup.
create or replace function private.validate_adult_birth_date(p_birth_date_text text)
returns date
language plpgsql
stable
set search_path = ''
as $function$
declare
  birth_date date;
begin
  if p_birth_date_text is null
     or p_birth_date_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'A valid date of birth is required to register.';
  end if;

  begin
    birth_date := p_birth_date_text::date;
  exception when others then
    raise exception 'A valid date of birth is required to register.';
  end;

  if birth_date::text <> p_birth_date_text then
    raise exception 'A valid date of birth is required to register.';
  end if;

  if birth_date > current_date then
    raise exception 'Date of birth cannot be in the future.';
  end if;

  if extract(year from age(current_date, birth_date)) < 18 then
    raise exception 'VYLOOP SOCIAL is for users aged 18 and over.';
  end if;

  return birth_date;
end;
$function$;

revoke all on function private.validate_adult_birth_date(text) from public, anon, authenticated, service_role;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  base_username text;
  birth_date date;
begin
  birth_date := private.validate_adult_birth_date(new.raw_user_meta_data ->> 'date_of_birth');

  insert into private.user_birth_dates (user_id, date_of_birth)
  values (new.id, birth_date);

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
