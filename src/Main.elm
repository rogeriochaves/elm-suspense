module Main exposing (main)

import Browser
import Html exposing (..)
import MovieList
import Suspense exposing (..)
import Types exposing (..)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = .view
        , update = \msg model -> updateView <| update msg model
        , subscriptions = always Sub.none
        }


init : () -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { view = text ""
            , searchInput = ""
            , searchResult = Empty
            }
    in
    updateView ( model, Cmd.none )


view : Model -> CmdHtml Msg
view =
    MovieList.view


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateSearch search ->
            ( { model | searchInput = search }, Cmd.none )

        SearchMovies query result ->
            ( { model | searchResult = Cached query result }, Cmd.none )


updateView : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
updateView ( model_, updateCmd ) =
    let
        updatedView =
            view model_
    in
    case updatedView of
        Render view_ ->
            ( { model_ | view = view_ }, updateCmd )

        Suspend viewCmd ->
            ( { model_
                | view = text "Warning: nobody recovered from a suspended view"
              }
            , Cmd.batch [ viewCmd, updateCmd ]
            )

        Resume viewCmd view_ ->
            ( { model_ | view = view_ }, Cmd.batch [ viewCmd, updateCmd ] )
