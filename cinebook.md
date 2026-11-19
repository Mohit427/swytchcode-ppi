# CineBook through Swytchcode

CineBook is my team's movie booking app (FastAPI and PostgreSQL). Its web pages
return HTML and use a session cookie, so I added a JSON API under `/api` on the
`swytchcode-json-api` branch of the CineBook repo and wrote a Wrekenfile for it here.

| File | Purpose |
|---|---|
| `.swytchcode/integrations/CineBook/api/1.0.0/wrekenfile.yaml` | 11 operations and the data shapes they use |
| `.swytchcode/integrations/CineBook/api/1.0.0/methods.json` | The operation IDs |
| `.swytchcode/integrations/manifest.json` | Base URL `http://localhost:8000`, timeouts, no retries |

## Operations

| ID | Request | Login needed |
|---|---|---|
| `cinebook.health.get` | `GET /api/health` | No |
| `cinebook.auth.login` | `POST /api/auth/login` | No |
| `cinebook.auth.me` | `GET /api/auth/me` | Yes |
| `cinebook.movies.list` | `GET /api/movies` | No |
| `cinebook.movies.get` | `GET /api/movies/{movie_id}` | No |
| `cinebook.shows.list` | `GET /api/shows` | No |
| `cinebook.shows.seats` | `GET /api/shows/{show_id}/seats` | No |
| `cinebook.bookings.create` | `POST /api/bookings` | Yes |
| `cinebook.bookings.list` | `GET /api/bookings/me` | Yes |
| `cinebook.bookings.get` | `GET /api/bookings/{booking_id}` | Yes |
| `cinebook.bookings.cancel` | `POST /api/bookings/{booking_id}/cancel` | Yes |

Errors always come back as `{"detail": "...", "code": "..."}`, for example
`409 SEAT_TAKEN` or `409 TOO_LATE`.

## Login

The API uses a JWT that expires after 30 minutes. `swy auth connect` stores
credentials for registry providers, so for this hand-written provider I log in
with `cinebook.auth.login` and pass the token on each call:

```powershell
--header "Authorization=Bearer <token>"
```

`--dry-run` and `--verbose` show this header as `[REDACTED]`.

## Run it

1. Start CineBook's database and server (from the CineBook repo, `swytchcode-json-api` branch):

```powershell
docker run -d --name cinebook-swy-db -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=cinebook -p 5433:5432 postgres:16
Get-Content db\seed.sql  | docker exec -i cinebook-swy-db psql -U postgres -d cinebook
Get-Content db\views.sql | docker exec -i cinebook-swy-db psql -U postgres -d cinebook
cd backend
# .env: DATABASE_URL=postgresql://postgres:postgres@localhost:5433/cinebook and your own JWT_SECRET
.\venv\Scripts\python -m uvicorn main:app --port 8000
```

2. Call it through Swytchcode (from this repo):

```powershell
swy exec cinebook.health.get
swy exec cinebook.movies.list --input genre=Action --input limit=3
swy exec cinebook.shows.list --input city=Chennai
swy exec cinebook.shows.seats --input show_id=18

# Log in with a sample account (password123 is the seed data's documented password)
'{"email":"mohit@cinebook.in","password":"password123"}' | Set-Content login.json
$token = (swy exec cinebook.auth.login --body login.json --json | ConvertFrom-Json).data.token
Remove-Item login.json

'{"show_id":18,"seat_ids":[1,2],"payment_method":"UPI"}' | Set-Content book.json
swy exec cinebook.bookings.create --body book.json --header "Authorization=Bearer $token"
swy exec cinebook.bookings.list --header "Authorization=Bearer $token"
swy exec cinebook.bookings.cancel --input booking_id=<id> --header "Authorization=Bearer $token"
```

Show and seat IDs depend on the seed data and the date, so pick them from the
`shows.list` and `shows.seats` output.

## Tested

All through `swy exec` against the local server:

- Health, movie search with a genre filter, upcoming shows in Chennai, and a seat map (57 of 60 seats free).
- Login, then `auth.me` with the token. Without the token: `401 UNAUTHORIZED`, `retryable: false`.
- Booked seats A-1 and A-2 for show 18: `201`, booking 33, Rs 500, payment `SUCCESS`.
- Booked the same seats again: `409 SEAT_TAKEN`.
- Cancelled booking 33: 2 tickets cancelled, Rs 500 refunded. Cancelled again: `400 NOT_CONFIRMED`.
- The web pages still work and still return HTML.

## Notes

- `max_retries` is `0` because booking is not idempotent. A retried booking
  after a timeout could book twice, or fail with `SEAT_TAKEN` even though the
  first attempt worked.
- `localhost:8000` only works on this machine. A deployed CineBook would only
  need a new `production_endpoint` in `manifest.json`.
