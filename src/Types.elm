module Types exposing (Model, Movie, Msg(..))

import Html exposing (..)
import Http
import Suspense exposing (..)


type alias Model =
    { view : Html Msg
    , searchInput : String
    , moviesCache : Cache (Result Http.Error (List Movie))
    , suspenseModel : Suspense.Model
    }


type alias Movie =
    { name : String
    , posterPath : String
    }


type Msg
    = UpdateSearch String
    | MoviesLoaded String (Result Http.Error (List Movie))
    | SuspenseMsg Suspense.Msg
