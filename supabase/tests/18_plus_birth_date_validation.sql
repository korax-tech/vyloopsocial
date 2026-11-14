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
