module SDict exposing (..)

import GenericDict exposing (Dict)
import Id


idToString : Id.Id String resource -> String
idToString id =
    Id.to id


get : Id.Id String resource -> Dict (Id.Id String resource) v -> Maybe v
get =
    GenericDict.get idToString


member : Id.Id String resource -> Dict (Id.Id String resource) v -> Bool
member =
    GenericDict.member idToString


empty : Dict k v
empty =
    GenericDict.empty


insert : Id.Id String resource -> v -> Dict (Id.Id String resource) v -> Dict (Id.Id String resource) v
insert =
    GenericDict.insert idToString


remove : Id.Id String resource -> Dict (Id.Id String resource) v -> Dict (Id.Id String resource) v
remove =
    GenericDict.remove idToString


map : (k -> a -> b) -> Dict k a -> Dict k b
map =
    GenericDict.map


filter : (k -> a -> Bool) -> Dict k a -> Dict k a
filter =
    GenericDict.filter


fromList : List ( Id.Id String resource, v ) -> Dict (Id.Id String resource) v
fromList =
    GenericDict.fromList idToString


fold : (k -> v -> b -> b) -> b -> Dict k v -> b
fold =
    GenericDict.fold


values : Dict k v -> List v
values =
    GenericDict.values


union : Dict k v -> Dict k v -> Dict k v
union =
    GenericDict.union


type alias SDict k v =
    Dict k v
