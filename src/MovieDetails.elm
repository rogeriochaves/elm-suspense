module MovieDetails exposing (view)

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
    case model.selectedMovie of
        Just movie ->
            mapCmdView
                (detailsView model movie)
                (\detailsView_ ->
                    div []
                        [ button [ onClick BackToSearch ] [ text "Back" ]
                        , br [] []
                        , h1 [] [ text movie.title ]
                        , br [] []
                        , detailsView_
                        ]
                )

        Nothing ->
            fromView (text "")


detailsView : Model -> Movie -> CmdHtml Msg
detailsView model movie =
    let
        movieId =
            String.fromInt movie.id
    in
    getFromCache model.suspenseModel
        { cache = model.movieDetailsCache
        , key = movieId
        , load = loadMovie movieId
        }
        (\data ->
            fromView <|
                case data of
                    Ok movieDetails ->
                        p [] [ text movieDetails.overview ]

                    Err _ ->
                        text "error loading movie details"
        )


loadMovie : String -> Cmd Msg
loadMovie id =
    let
        url =
            "https://api.themoviedb.org/3/movie/" ++ id ++ "?api_key=762954999d09f9db6ffc6c0e6f37d509"
    in
    Http.send
        (MovieDetailsLoaded id)
        (Http.get url movieDetailsDecoder)


movieDetailsDecoder : Decode.Decoder MovieDetails
movieDetailsDecoder =
    Decode.map MovieDetails
        (Decode.field "overview" Decode.string)
