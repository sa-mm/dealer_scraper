defmodule DealerScraper do
  @moduledoc """

  This module implements the business logic for the application.
  """

  require Logger

  @type reviews :: list(map())
  @type error :: {:error, binary()}

  @url "https://www.dealerrater.com/dealer/McKaig-Chevrolet-Buick-A-Dealer-For-The-People-dealer-reviews-23685/"
  @pages_to_scrape 5
  @max_retries 3
  @base_retry_interval 20
  defp http_client, do: Application.get_env(:dealer_scraper, :http_client, HTTPoison)

  @spec get_reviews_of_interest(integer) :: reviews() | error
  def get_reviews_of_interest(pages_to_scrape \\ @pages_to_scrape) do
    results =
      pages_to_scrape
      |> make_requests()
      |> get_reviews()
      |> sort_by_highest_rated_employees()
      |> take_top_3_reviews()

    case results do
      {:error, _} = error -> error
      reviews -> reviews
    end
  end

  defp make_requests(pages) do
    responses =
      Enum.reduce_while(1..pages, [], fn page_number, acc ->
        case make_request(page_number) do
          {:error, _} = error -> {:halt, error}
          body -> {:cont, [body | acc]}
        end
      end)

    case responses do
      {:error, _} = error -> error
      responses -> Enum.reverse(responses)
    end
  end

  defp make_request(page_number, retry \\ 0) do
    with {:ok, %HTTPoison.Response{body: body}} <- http_client().get(@url <> "page#{page_number}") do
      body
    else
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP client failure: #{inspect(reason)}")

        cond do
          retry < @max_retries ->
            new_retry = retry + 1
            backoff = Integer.pow(@base_retry_interval, new_retry)
            Process.sleep(backoff)

            make_request(page_number, new_retry)

          true ->
            {:error,
             "Error requesting page #{page_number} from site. Reason: #{inspect(reason)}. Retries exceeded."}
        end
    end
  end

  @spec get_reviews(error() | list()) :: error() | reviews()
  def get_reviews({:error, _} = error), do: error

  def get_reviews(reviews_data) do
    maybe_reviews =
      reviews_data
      |> Enum.map(&Floki.parse_document!/1)
      |> Enum.map(&Floki.find(&1, ".review-entry"))
      |> Enum.reduce_while([], fn review_entries_for_one_page, acc ->
        maybe_reviews =
          Enum.reduce_while(review_entries_for_one_page, [], fn review, acc ->
            case gather_review_information(review) do
              {:error, _} = error -> {:halt, error}
              review -> {:cont, [review | acc]}
            end
          end)

        case maybe_reviews do
          {:error, _} = error -> {:halt, error}
          reviews -> {:cont, [Enum.reverse(reviews) | acc]}
        end
      end)

    case maybe_reviews do
      {:error, _} = error ->
        error

      all_reviews ->
        all_reviews
        |> Enum.reverse()
        |> List.flatten()
    end
  end

  defp gather_review_information({_tag, _attributes, child_nodes} = _review_entry) do
    with ratings = %{} <- parse_ratings(child_nodes),
         reviewer when is_binary(reviewer) <- parse_reviewer_name(child_nodes) do
      review_text = parse_reviewer_text(child_nodes)

      %{
        "reviewer" => reviewer,
        "ratings" => ratings,
        "review_text" => review_text
      }
    else
      {:error, _} = error -> error
    end
  end

  defp parse_reviewer_name(child_nodes) do
    text =
      Floki.find(child_nodes, ".notranslate")
      |> Floki.text()

    name_re = ~r/by\s(?<name>.*)[\s\r\n\t]/

    case Regex.named_captures(name_re, text) do
      %{"name" => name} ->
        String.trim(name)

      _ ->
        Logger.error("Reviewer name not found: #{inspect(text)}")
        {:error, "Reviewer name not found"}
    end
  end

  defp parse_ratings(child_nodes) do
    ratings =
      Floki.find(child_nodes, ".employee-rating-badge-sm")
      |> Enum.map(fn {_, _, child_nodes} ->
        child_nodes
        |> Floki.text()
        |> parse_string_rating(:float)
      end)

    errors = Enum.filter(ratings, &match?({:error, _}, &1))

    case errors do
      [_ | _] ->
        {:error, "Errors were found when parsing employee ratings."}

      _ ->
        ratings_count = Enum.count(ratings)
        ratings_sum = Enum.sum(ratings)

        avg =
          cond do
            ratings_count == 0 -> 0
            true -> ratings_sum / ratings_count
          end

        %{
          "avg_employee_rating" => avg,
          "employee_ratings_count" => ratings_count
        }
    end
  end

  defp parse_string_rating(str, :float) do
    String.to_float(str)
  rescue
    _ ->
      parse_string_rating(str, :integer)
  end

  defp parse_string_rating(str, :integer) do
    String.to_integer(str) / 1.0
  rescue
    _ ->
      Logger.error("Problem parsing rating: #{inspect(str)}")
      {:error, str}
  end

  defp parse_reviewer_text(child_nodes) do
    start =
      child_nodes
      |> Enum.map(fn child_node ->
        child_node
        |> Floki.find(".review-title")
        |> Floki.text()
        |> String.trim()
      end)
      |> Enum.reject(&match?("", &1))

    rest =
      child_nodes
      |> Enum.map(fn child_node ->
        child_node
        |> Floki.find(".review-whole")
        |> Floki.text()
        |> String.trim()
      end)
      |> Enum.reject(&match?("", &1))

    Enum.join(start ++ rest)
  end

  @spec sort_by_highest_rated_employees(error() | reviews()) ::
          error() | reviews()
  def sort_by_highest_rated_employees({:error, _} = error), do: error

  def sort_by_highest_rated_employees(reviews) do
    reviews
    |> Enum.sort(fn %{
                      "ratings" => %{
                        "avg_employee_rating" => avg_employee_rating1,
                        "employee_ratings_count" => ratings_count1
                      }
                    },
                    %{
                      "ratings" => %{
                        "avg_employee_rating" => avg_employee_rating2,
                        "employee_ratings_count" => ratings_count2
                      }
                    } ->
      cond do
        avg_employee_rating1 > avg_employee_rating2 ->
          true

        avg_employee_rating1 == avg_employee_rating2 ->
          ratings_count1 >= ratings_count2

        true ->
          false
      end
    end)
  end

  @spec take_top_3_reviews(error() | reviews()) :: error() | reviews()
  def take_top_3_reviews({:error, _} = error), do: error

  def take_top_3_reviews(reviews) do
    Enum.take(reviews, 3)
  end
end
