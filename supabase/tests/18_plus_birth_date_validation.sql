-- Run with the Supabase SQL editor or psql against the VYLOOP project.
-- This test exercises the same private validator called by the auth.users trigger.
-- It creates no Auth users and does not modify application data.

do $test$
declare
  v_valid date;
  v_error text;
begin
  v_valid := private.validate_adult_birth_date((current_date - interval '18 years')::date::text);
  if v_valid <> (current_date - interval '18 years')::date then
    raise exception 'TEST FAILED: valid 18-year-old date did not pass';
  end if;

  begin
    perform private.validate_adult_birth_date((current_date - interval '17 years')::date::text);
    raise exception 'TEST FAILURE: under-18 date was accepted';
  exception when others then
    get stacked diagnostics v_error = message_text;
    if v_error = 'TEST FAILURE: under-18 date was accepted' then raise; end if;
    if position('18 and over' in v_error) = 0 then
      raise exception 'TEST FAILED: wrong underage error: %', v_error;
    end if;
  end;

  begin
    perform private.validate_adult_birth_date(null);
    raise exception 'TEST FAILURE: missing date was accepted';
  exception when others then
    get stacked diagnostics v_error = message_text;
    if v_error = 'TEST FAILURE: missing date was accepted' then raise; end if;
    if position('valid date of birth is required' in lower(v_error)) = 0 then
      raise exception 'TEST FAILED: wrong missing-date error: %', v_error;
    end if;
  end;

  begin
    perform private.validate_adult_birth_date('not-a-date');
    raise exception 'TEST FAILURE: malformed date was accepted';
  exception when others then
    get stacked diagnostics v_error = message_text;
    if v_error = 'TEST FAILURE: malformed date was accepted' then raise; end if;
    if position('valid date of birth is required' in lower(v_error)) = 0 then
      raise exception 'TEST FAILED: wrong malformed-date error: %', v_error;
    end if;
  end;

  begin
    perform private.validate_adult_birth_date('2026-02-31');
    raise exception 'TEST FAILURE: impossible calendar date was accepted';
  exception when others then
    get stacked diagnostics v_error = message_text;
    if v_error = 'TEST FAILURE: impossible calendar date was accepted' then raise; end if;
    if position('valid date of birth is required' in lower(v_error)) = 0 then
      raise exception 'TEST FAILED: wrong impossible-date error: %', v_error;
    end if;
  end;

  begin
    perform private.validate_adult_birth_date((current_date + 1)::text);
    raise exception 'TEST FAILURE: future date was accepted';
  exception when others then
    get stacked diagnostics v_error = message_text;
    if v_error = 'TEST FAILURE: future date was accepted' then raise; end if;
    if position('future' in lower(v_error)) = 0 then
      raise exception 'TEST FAILED: wrong future-date error: %', v_error;
    end if;
  end;
end;
$test$;


-- Assert the DOB hand-off is sanitized in a BEFORE INSERT trigger, so the Auth
-- INSERT ... RETURNING row is already clean. The private FK is deferred only
-- within the signup transaction; it still cascades on Auth-user deletion.
do $privacy$
declare
  v_before_trigger_count integer;
  v_after_profile_count integer;
  v_fk_deferrable boolean;
begin
  select count(*) into v_before_trigger_count
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_proc p on p.oid = t.tgfoid
  join pg_namespace pn on pn.oid = p.pronamespace
  where n.nspname = 'auth'
    and c.relname = 'users'
    and t.tgname = 'on_auth_user_created_vyloop'
    and not t.tgisinternal
    and (t.tgtype & 2) = 2
    and (t.tgtype & 4) = 4
    and pn.nspname = 'private'
    and p.proname = 'handle_new_user';

  if v_before_trigger_count <> 1 then
    raise exception 'TEST FAILED: private DOB validation must run exactly once before Auth INSERT';
  end if;

  select count(*) into v_after_profile_count
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = n.oid
  join pg_proc p on p.oid = t.tgfoid
  join pg_namespace pn on pn.oid = p.pronamespace
  where n.nspname = 'auth'
    and c.relname = 'users'
    and t.tgname = 'on_auth_user_created_vyloop_profile'
    and not t.tgisinternal
    and (t.tgtype & 2) = 0
    and (t.tgtype & 4) = 4
    and pn.nspname = 'private'
    and p.proname = 'handle_new_user_profile';

  if v_after_profile_count <> 1 then
    raise exception 'TEST FAILED: public profile creation must run after Auth INSERT';
  end if;

  select condeferrable into v_fk_deferrable
  from pg_constraint
  where conrelid = 'private.user_birth_dates'::regclass
    and conname = 'user_birth_dates_user_id_fkey';

  if not coalesce(v_fk_deferrable, false) then
    raise exception 'TEST FAILED: private DOB FK must be deferrable for the BEFORE trigger';
  end if;

  if has_schema_privilege('anon', 'private', 'USAGE')
     or has_schema_privilege('authenticated', 'private', 'USAGE')
     or has_table_privilege('anon', 'private.user_birth_dates', 'SELECT')
     or has_table_privilege('authenticated', 'private.user_birth_dates', 'SELECT') then
    raise exception 'TEST FAILED: client roles can access the private DOB table';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'date_of_birth'
  ) then
    raise exception 'TEST FAILED: public profiles must not contain DOB';
  end if;

  if exists (
    select 1 from auth.users
    where coalesce(raw_user_meta_data, '{}'::jsonb) ? 'date_of_birth'
  ) then
    raise exception 'TEST FAILED: Auth metadata still contains DOB';
  end if;
end;
$privacy$;
