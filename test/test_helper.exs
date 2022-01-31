Mox.defmock(HttpClientMock, for: HTTPoison.Base)
Application.put_env(:dealer_scraper, :http_client, HttpClientMock)

ExUnit.start()
