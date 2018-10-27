module Main exposing (main)

import Browser
import Html exposing (..)
import MovieList
import Suspense exposing (Cache(..), CmdHtml, CmdView(..))
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
            , suspenseModel = Suspense.init
            }
    in
    updateView ( model, Cmd.none )


view : Model -> CmdHtml Msg
view model =
    MovieList.view
        { msg = SuspenseMsg, model = model.suspenseModel }
        model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateSearch search ->
            ( { model | searchInput = search }, Cmd.none )

        MoviesLoaded query result ->
            if model.searchInput == query then
                ( { model | searchResult = Cached query result }, Cmd.none )

            else
                ( model, Cmd.none )

        SuspenseMsg msg_ ->
            let
                ( model_, cmd ) =
                    Suspense.update msg_ model.suspenseModel
            in
            ( { model | suspenseModel = model_ }, Cmd.map SuspenseMsg cmd )


updateView : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
updateView ( model_, updateCmd ) =
    let
        updatedView =
            view model_
    in
    case updatedView of
        Render view_ ->
            ( { model_ | view = view_ }, updateCmd )

        Suspend _ viewCmd view_ ->
            case view_ of
                Just previousView ->
                    ( { model_ | view = previousView }, Cmd.batch [ viewCmd, updateCmd ] )

                Nothing ->
                    ( { model_ | view = text "Warning: nobody recovered from a suspended view and there was no previous state, so we have nothing to render" }
                    , Cmd.batch [ viewCmd, updateCmd ]
                    )

        Resume viewCmd view_ ->
            ( { model_ | view = view_ }, Cmd.batch [ viewCmd, updateCmd ] )
