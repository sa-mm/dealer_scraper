defmodule DealerScraperTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Mox

  doctest DealerScraper

  setup :verify_on_exit!

  @pages_to_scrap 1
  @retries 3

  describe "get_reviews_of_interest/1 should return" do
    test "non-empty list" do
      do_expect()

      assert [_ | _] = DealerScraper.get_reviews_of_interest(@pages_to_scrap)
    end

    test "reviewer names, text, and ratings" do
      do_expect()

      assert [_ | _] =
               DealerScraper.get_reviews_of_interest(@pages_to_scrap)
               |> Enum.map(fn %{
                                "review_text" => review_text,
                                "reviewer" => reviewer,
                                "ratings" => %{} = ratings
                              } ->
                 assert is_number(ratings["avg_employee_rating"])
                 assert is_number(ratings["employee_ratings_count"])
                 refute review_text == ""
                 refute reviewer == ""
               end)
    end

    test "give up after three retries" do
      do_expect(1 + @retries, error: true)

      assert capture_log(fn ->
               assert {:error, _} = DealerScraper.get_reviews_of_interest(@pages_to_scrap)
             end) =~ "HTTP client failure: :nxdomain"
    end
  end

  describe "sort_by_highest_rated_employees/1 should return" do
    test "error if given error tuple" do
      error = {:error, "error"}
      assert ^error = DealerScraper.sort_by_highest_rated_employees(error)
    end

    test "reviews with highest avg employee rating first" do
      highest_avg_rating = %{
        "ratings" => %{
          "avg_employee_rating" => 5,
          "employee_ratings_count" => 2
        }
      }

      lower_avg = %{
        "ratings" => %{
          "avg_employee_rating" => 4,
          "employee_ratings_count" => 4
        }
      }

      reviews = [lower_avg, highest_avg_rating, lower_avg]

      assert [^highest_avg_rating | _] = DealerScraper.sort_by_highest_rated_employees(reviews)
    end

    test "reviews with more employee ratings first if avg is the same" do
      highest_review_count = %{
        "ratings" => %{
          "avg_employee_rating" => 5,
          "employee_ratings_count" => 4
        }
      }

      reviews = [
        %{
          "ratings" => %{
            "avg_employee_rating" => 5,
            "employee_ratings_count" => 2
          }
        },
        highest_review_count,
        %{
          "ratings" => %{
            "avg_employee_rating" => 5,
            "employee_ratings_count" => 3
          }
        }
      ]

      assert [^highest_review_count | _] = DealerScraper.sort_by_highest_rated_employees(reviews)
    end
  end

  describe "take_top_3_reviews/1 should return" do
    test "error if given error tuple" do
      error = {:error, "reason"}

      assert ^error = DealerScraper.take_top_3_reviews(error)
    end

    test "only three reviews if more than three present" do
      reviews = [%{}, %{}, %{}, %{}]
      assert [_, _, _] = DealerScraper.take_top_3_reviews(reviews)
    end
  end

  defp do_expect(http_calls \\ 1, opts \\ []) do
    client_error = Keyword.get(opts, :error, false)

    for _n <- 1..http_calls do
      expect(HttpClientMock, :get, fn _url ->
        if client_error do
          {:error, %HTTPoison.Error{reason: :nxdomain}}
        else
          {:ok, %HTTPoison.Response{body: File.read!("test/support/page1.html")}}
        end
      end)
    end
  end
end
