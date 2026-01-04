module IDict exposing (..)

-- CURRENT WORK: Trying to convert my usages of Dict to IDict to avoid some annoying boilerplate in the rest of the code
--  Want to simplify by just having all the Ids represented by a String
-- i forgot that some of my IDs are defined like "Toggl ID or Rize ID". So I need a slightly different approach.
--
-- i think I have uncovered why the other generic dict solution uses code gen. I can imagine a way to make this work
-- with a bunch of repetitive code... would need to do the below for each type of Id that I want
--
-- we need to use Ints as the keys here because the Toggl API demands Ints. It helps avoid impossible state (string
--  keys that don't convert to Ints)

import GenericDict exposing (Dict)
import Id


intIdToString : Id.Id Int resource -> String
intIdToString id =
    String.fromInt (Id.to id)


get : Id.Id Int resource -> Dict (Id.Id Int resource) v -> Maybe v
get =
    GenericDict.get intIdToString


member : Id.Id Int resource -> Dict (Id.Id Int resource) v -> Bool
member =
    GenericDict.member intIdToString


empty : Dict k v
empty =
    GenericDict.empty


insert : Id.Id Int resource -> v -> Dict (Id.Id Int resource) v -> Dict (Id.Id Int resource) v
insert =
    GenericDict.insert intIdToString


remove : Id.Id Int resource -> Dict (Id.Id Int resource) v -> Dict (Id.Id Int resource) v
remove =
    GenericDict.remove intIdToString


map : (k -> a -> b) -> Dict k a -> Dict k b
map =
    GenericDict.map


filter : (k -> a -> Bool) -> Dict k a -> Dict k a
filter =
    GenericDict.filter


fromList : List ( Id.Id Int resource, v ) -> Dict (Id.Id Int resource) v
fromList =
    GenericDict.fromList intIdToString


fold : (k -> v -> b -> b) -> b -> Dict k v -> b
fold =
    GenericDict.fold


values : Dict k v -> List v
values =
    GenericDict.values


union : Dict k v -> Dict k v -> Dict k v
union =
    GenericDict.union


type alias IDict k v =
    Dict k v
