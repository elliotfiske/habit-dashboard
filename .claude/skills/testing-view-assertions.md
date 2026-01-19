---
name: testing-view-assertions
description: Use when writing checkView assertions and HTML selectors in lamdera/program-test
---

# View Assertions in lamdera/program-test

## checkView Signature

```elm
actions.checkView : Int -> (Query msg -> Expectation) -> Action
```

- First param: delay in milliseconds
- Second param: query function that returns an expectation

## Query Pipeline Pattern

```elm
actions.checkView 200
    (Test.Html.Query.find [ selector1, selector2 ]
        >> Test.Html.Query.has [ assertion1 ]
    )
```

## Common Selectors

```elm
-- By data-testid (most reliable)
Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" "my-element")

-- By text content
Test.Html.Selector.text "Submit"

-- By tag
Test.Html.Selector.tag "button"

-- By class
Test.Html.Selector.class "btn-primary"

-- Containing text (careful - matches parents too!)
Test.Html.Selector.containing [ Test.Html.Selector.text "some text" ]
```

## Using data-testid

**In view code:**
```elm
div
    [ Attr.attribute "data-testid" "day-2026-01-02"
    , Attr.class "day-cell"
    ]
    [ text "30" ]
```

**In test:**
```elm
actions.checkView 200
    (Test.Html.Query.find
        [ Test.Html.Selector.attribute
            (Html.Attributes.attribute "data-testid" "day-2026-01-02")
        ]
        >> Test.Html.Query.has [ Test.Html.Selector.text "30" ]
    )
```

## Dynamic Test IDs

```elm
-- In view
div [ Attr.attribute "data-testid" ("day-" ++ formatIsoDate day) ] [ ... ]
div [ Attr.attribute "data-testid" ("project-" ++ String.fromInt id) ] [ ... ]
```

## Why Avoid `containing`

**Problem:** `containing [ text "1/2" ]` matches:
- The day cell with "1/2"
- The week row containing that cell
- The calendar containing that row
- The entire page body

If you then check `.has [ text "-" ]`, it might pass because a *different* cell in the parent contains "-".

**Solution:** Use `data-testid` for precise selection.

## Multiple Assertions

```elm
actions.checkView 200
    (Test.Html.Query.find [ testIdSelector "my-element" ]
        >> Test.Html.Query.has
            [ Test.Html.Selector.text "expected text"
            , Test.Html.Selector.class "expected-class"
            ]
    )
```
