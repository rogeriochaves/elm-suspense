module MovieList exposing (view)

import Html exposing (..)
import Html.Events exposing (..)
import Http exposing (..)
import Json.Decode as Decode
import Suspense exposing (CmdHtml, Context, getFromCache, mapCmdView, timeout)
import Types exposing (..)
import Url


view : Context Msg -> Model -> CmdHtml Msg
view context model =
    mapCmdView
        (timeout context
            { ms = 400, fallback = text "Loading..." }
            (resultsView model)
        )
        (\resultsView_ ->
            div []
                [ text "Movie Search"
                , br [] []
                , input [ onInput UpdateSearch ] []
                , br [] []
                , resultsView_
                ]
        )


resultsView : Model -> CmdHtml Msg
resultsView model =
    getFromCache
        { cache = model.searchResult
        , key = model.searchInput
        , load = loadMovies model.searchInput
        }
        (\data ->
            case data of
                Ok movies ->
                    div []
                        [ text "Results:"
                        , br [] []
                        , ul []
                            (List.map
                                (\{ name } -> li [] [ text name ])
                                movies
                            )
                        ]

                Err _ ->
                    text "error loading movies"
        )


loadMovies : String -> Cmd Msg
loadMovies query =
    let
        url =
            "https://api.themoviedb.org/3/search/movie?api_key=762954999d09f9db6ffc6c0e6f37d509&query="
                ++ Url.percentEncode query
    in
    Http.send
        (MoviesLoaded query)
        (Http.get url moviesDecoder)


moviesDecoder : Decode.Decoder (List Movie)
moviesDecoder =
    Decode.field "results"
        (Decode.list
            (Decode.field "title" Decode.string
                |> Decode.map Movie
            )
        )
