module MovieList exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (..)
import Json.Decode as Decode
import Suspense exposing (CmdHtml, fromView, getFromCache, mapCmdView, mapCmdViewList, preloadImg, timeout)
import Types exposing (..)
import Url


view : Model -> CmdHtml Msg
view model =
    mapCmdView
        (timeout model.suspenseModel
            { ms = 500, fallback = text "Loading...", key = "moviesListTimeout" }
            (resultsView model)
        )
        (\resultsView_ ->
            div [ style "max-width" "500px", style "width" "100%" ]
                [ text "Movie Search"
                , br [] []
                , input [ onInput UpdateSearch ] []
                , br [] []
                , resultsView_
                ]
        )


resultsView : Model -> CmdHtml Msg
resultsView model =
    if String.isEmpty model.searchInput then
        fromView (text "")

    else
        getFromCache model.suspenseModel
            { cache = model.moviesCache
            , key = model.searchInput
            , load = loadMovies model.searchInput
            }
            (\data ->
                case data of
                    Ok movies ->
                        mapCmdViewList
                            (List.map (resultView model) movies)
                            (\resultView_ ->
                                div
                                    []
                                    [ text "Results:"
                                    , br [] []
                                    , ul
                                        [ style "list-style" "none"
                                        , style "padding" "0"
                                        ]
                                        resultView_
                                    ]
                            )

                    Err _ ->
                        fromView <| text "error loading movies"
            )


resultView : Model -> Movie -> CmdHtml Msg
resultView model movie =
    let
        imgSrc =
            "https://image.tmdb.org/t/p/w92" ++ movie.posterPath
    in
    preloadImg model.suspenseModel
        { src = imgSrc }
        (li
            [ onClick (ShowMovieDetails movie)
            , style "display" "flex"
            , style "align-items" "center"
            , style "border" "1px solid #666"
            , style "margin-bottom" "-1px"
            ]
            [ img
                [ src imgSrc
                , style "padding-right" "10px"
                ]
                []
            , text movie.title
            ]
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
            (Decode.map3 Movie
                (Decode.field "id" Decode.int)
                (Decode.field "title" Decode.string)
                (Decode.oneOf
                    [ Decode.field "poster_path" Decode.string
                    , Decode.succeed ""
                    ]
                )
            )
            |> Decode.map (List.take 3)
        )
