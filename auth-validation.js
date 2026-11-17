(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.VyloopAuthValidation = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  function localDateInputValue(date) {
    // Supabase CURRENT_DATE uses the UTC calendar day; keep browser checks aligned.
    const value = date || new Date();
    const year = value.getUTCFullYear();
    const month = String(value.getUTCMonth() + 1).padStart(2, '0');
    const day = String(value.getUTCDate()).padStart(2, '0');
    return year + '-' + month + '-' + day;
  }

  function parseBirthDateOnly(value) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
    const [year, month, day] = value.split('-').map(Number);
    if (year < 1) return null;

    // setUTCFullYear avoids Date.UTC's special remapping of years 0001–0099.
    const parsed = new Date(0);
    parsed.setUTCHours(0, 0, 0, 0);
    parsed.setUTCFullYear(year, month - 1, day);
    if (
      parsed.getUTCFullYear() !== year ||
      parsed.getUTCMonth() !== month - 1 ||
      parsed.getUTCDate() !== day
    ) return null;

    return { year, month, day };
  }

  function validateBirthDate(value, todayValue) {
    if (!value) {
      return { ok: false, message: 'Date of birth is required. VYLOOP SOCIAL is for adults aged 18 and over.' };
    }

    const birth = parseBirthDateOnly(value);
    if (!birth) return { ok: false, message: 'Enter a valid date of birth.' };

    const todayText = todayValue || localDateInputValue(new Date());
    const today = parseBirthDateOnly(todayText);
    if (!today) return { ok: false, message: 'Unable to validate the current date. Please try again.' };
    if (value > todayText) return { ok: false, message: 'Date of birth cannot be in the future.' };

    let age = today.year - birth.year;
    if (today.month < birth.month || (today.month === birth.month && today.day < birth.day)) age -= 1;

    if (age < 18) {
      return {
        ok: false,
        message: 'VYLOOP SOCIAL is for adults aged 18 and over. You must be 18 or older to create an account.'
      };
    }

    return { ok: true, age };
  }

  return { localDateInputValue, parseBirthDateOnly, validateBirthDate };
});
