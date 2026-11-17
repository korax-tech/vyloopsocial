const test = require('node:test');
const assert = require('node:assert/strict');
const {
  localDateInputValue,
  parseBirthDateOnly,
  validateBirthDate
} = require('../auth-validation.js');

test('uses the UTC calendar date to match the database eligibility clock', () => {
  assert.equal(localDateInputValue(new Date('2026-11-16T00:15:00.000Z')), '2026-11-16');
});

test('accepts someone exactly 18 on their birthday', () => {
  assert.deepEqual(validateBirthDate('2008-11-16', '2026-11-16'), { ok: true, age: 18 });
});

test('rejects someone one day before turning 18', () => {
  const result = validateBirthDate('2008-11-17', '2026-11-16');
  assert.equal(result.ok, false);
  assert.match(result.message, /18 and over/i);
});

test('accepts someone one day after turning 18', () => {
  assert.deepEqual(validateBirthDate('2008-11-15', '2026-11-16'), { ok: true, age: 18 });
});

test('rejects missing, malformed, impossible and future dates', () => {
  assert.match(validateBirthDate('', '2026-11-16').message, /required/i);
  assert.match(validateBirthDate('not-a-date', '2026-11-16').message, /valid date/i);
  assert.match(validateBirthDate('2026-02-31', '2026-11-16').message, /valid date/i);
  assert.match(validateBirthDate('2026-11-17', '2026-11-16').message, /future/i);
});

test('handles leap-day birthdays consistently with PostgreSQL age()', () => {
  assert.equal(validateBirthDate('2008-02-29', '2026-02-28').ok, false);
  assert.deepEqual(validateBirthDate('2008-02-29', '2026-03-01'), { ok: true, age: 18 });
});

test('parses early four-digit years without JavaScript year remapping', () => {
  assert.deepEqual(parseBirthDateOnly('0001-01-01'), { year: 1, month: 1, day: 1 });
  assert.equal(parseBirthDateOnly('0000-01-01'), null);
});

test('strictly parses canonical ISO dates and rejects non-canonical input', () => {
  assert.deepEqual(parseBirthDateOnly('2008-11-16'), { year: 2008, month: 11, day: 16 });
  assert.equal(parseBirthDateOnly('2008-2-16'), null);
  assert.equal(parseBirthDateOnly('2008-02-31'), null);
});
