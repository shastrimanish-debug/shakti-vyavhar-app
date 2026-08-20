# Bhavya — Leena/Lena speech fix

Speech-to-text may transcribe the person's name **Leena** as **lena**.
The previous sanitizer removed `lena` as a command word, so Bhavya lost the
actual name and behaved incorrectly.

The new logic:
- preserves `lena` as a candidate long enough to resolve it against known suppliers;
- if a known supplier is Leena, resolves the spoken `lena` to the stored name;
- if the phrase is ambiguous and no known supplier matches, asks for confirmation
  instead of creating a bogus supplier;
- explicit phrases such as `Leena ko supplier jodo` are accepted.
