module Evergreen.V1.Toggl exposing (..)

import Effect.Http
import Time


type TogglWorkspaceId
    = TogglWorkspaceId Int


type alias TogglWorkspace =
    { id : TogglWorkspaceId
    , name : String
    , organizationId : Int
    }


type TogglProjectId
    = TogglProjectId Int


type alias TogglProject =
    { id : TogglProjectId
    , workspaceId : TogglWorkspaceId
    , name : String
    , color : String
    }


type TimeEntryId
    = TimeEntryId Int


type alias WebhookPayload =
    { id : TimeEntryId
    , projectId : Maybe TogglProjectId
    , workspaceId : TogglWorkspaceId
    , description : Maybe String
    , start : Time.Posix
    , stop : Maybe Time.Posix
    , duration : Int
    }


type TogglApiError
    = HttpError Effect.Http.Error
    | RateLimited
        { secondsUntilReset : Int
        , message : String
        }


type alias TimeEntry =
    { id : TimeEntryId
    , projectId : Maybe TogglProjectId
    , description : Maybe String
    , start : Time.Posix
    , stop : Maybe Time.Posix
    , duration : Int
    }
