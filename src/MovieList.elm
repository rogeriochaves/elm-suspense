module MovieList exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (..)
import Json.Decode as Decode
import Suspense exposing (CmdHtml, CmdView(..), Context, getFromCache, mapCmdView, timeout)
import Types exposing (..)
import Url


view : Context Msg -> Model -> CmdHtml Msg
view context model =
    mapCmdView
        (timeout context
            { ms = 400, fallback = text "Loading..." }
            (resultsView context model)
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


resultsView : Context Msg -> Model -> CmdHtml Msg
resultsView context model =
    getFromCache context
        { cache = model.moviesCache
        , key = model.searchInput
        , load = loadMovies model.searchInput
        }
        (\data ->
            Resume Cmd.none <|
                case data of
                    Ok movies ->
                        div []
                            [ text "Results:"
                            , br [] []
                            , ul []
                                (List.map resultView movies)
                            ]

                    Err _ ->
                        text "error loading movies"
        )


resultView : Movie -> Html Msg
resultView result =
    li []
        [ img [ src <| "https://image.tmdb.org/t/p/w92" ++ result.posterPath ] []
        , text result.name
        ]


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
            (Decode.map2 Movie
                (Decode.field "title" Decode.string)
                (Decode.oneOf
                    [ Decode.field "poster_path" Decode.string
                    , Decode.succeed ""
                    ]
                )
            )
        )
