# DealerScraper

Requirements:

- Elixir 1.13 / Erlang OTP 24

Usage:

- `mix deps.get`
- `mix compile`
- `mix scrape` to print the output to the console.
- `mix test` to test

The output is json.

More documentation:

The criteria for the top three "overly positive" endorsements:

1. A review with a higher average employee rating is preferred (i.e., is more severe).
2. If there is a tie for (1), a review with a higher number rated employees is preferred. That is, if two reviews have an average of 5.0, then the review with more reviewed employees is preferred. The idea being that the KGB don't want their employees tagged publicly.



