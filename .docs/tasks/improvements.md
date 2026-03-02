# Improvements

## API Response Consistency
- Unify JSON response shape across auth and contacts endpoints (success/data/error/meta).
- Prefer a shared response helper in ApplicationController or a dedicated concern.

## JWT Handling & Authentication
- Centralize JWT encode/decode in a small utility (e.g. JwtEncoder) instead of in controllers and specs.
- Ensure Authenticatable concern handles all auth errors with a consistent error object (code/message/details).

## Contacts Delete Semantics
- Decide whether DELETE /contacts/{id} should be idempotent (always 200) or strict (404 when not found/forbidden).
- Align implementation and RSwag docs/tests with the chosen behavior.

## Domain Modeling Polish
- Consider removing redundant validates :user_id, presence: true since belongs_to :user is required by default.
- If trust-level logic grows, introduce intention-revealing predicates or a dedicated abstraction around User#trust_level.

## Error Codes Abstraction
- Replace bare error strings in controllers/services with well-named constants or symbols.
- Centralize mapping from error codes to HTTP status and JSON error payload to avoid drift between code and specs.
