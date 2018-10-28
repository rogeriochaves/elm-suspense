module MovieList exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (..)
import Json.Decode as Decode
import Suspense exposing (CmdHtml, fromView, getFromCache, mapCmdView, mapCmdViewList, snapshot, timeout)
import Types exposing (..)
import Url


view : Model -> CmdHtml Msg
view model =
    mapCmdView
        (timeout model.suspenseModel
            { ms = 400, fallback = text "Loading...", key = "moviesListTimeout" }
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
                                , ul [] resultView_
                                ]
                        )

                Err _ ->
                    fromView <| text "error loading movies"
        )


resultView : Model -> Movie -> CmdHtml Msg
resultView model result =
    let
        imgSrc =
            "https://image.tmdb.org/t/p/w92" ++ result.posterPath
    in
    getFromCache model.suspenseModel
        { cache = model.suspenseModel.imgsCache
        , key = imgSrc
        , load = loadImg imgSrc
        }
        (\data ->
            fromView <|
                li []
                    [ img [ src imgSrc ] []
                    , text result.name
                    ]
        )


loadImg : String -> Cmd Msg
loadImg src =
    Http.send
        (always <| SuspenseMsg <| Suspense.ImgLoaded src)
        (Http.get src (Decode.succeed ()))


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
            |> Decode.map (List.take 3)
        )
