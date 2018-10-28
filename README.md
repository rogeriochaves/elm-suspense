# elm-suspense

This is a proof-of-concept project trying to port React Suspense features to Elm. There are some features that I felt specially useful:

### Data load co-located with the view

Usually in Elm the data fetching is at the router or some other place far from the view, having them together can make it easier to follow where the data is going and also move a view around in a more "plug-and-play" manner

### Suspend and timeout for loading pattern in fast connections

For slow internet speeds we usually show a "Loading" message for the users, which is great and [elm helps us a lot not forgetting that](http://blog.jenkster.com/2016/06/how-elm-slays-a-ui-antipattern.html). But, for fast internet connections, a "Loading" flicking really quick all the time can be very annoying.

We do not have to decide between one case or the other though, we can make the experience great for **both** at the same time, and suspend helps with that with the timeout component, that shows a "Loading" message only after some miliseconds

### Preloading of images

On the web its common to render the html as soon as we get it, and different pieces like images load one after another, from top to bottom, causing a lot of layout changes until everything is in place, but we could have a better experience than that. With suspense, we can wait util everything is fully ready before rendering the screen for the use

## Demo

### Without Suspense Features

#### Fast internet connection

Notice how everything flicks all the time, blinks of "Loading..." with very fast layout changes all the time

<img src="https://user-images.githubusercontent.com/792201/47619622-3e266300-dae1-11e8-8054-6f10cbc317f2.gif" alt="fast-connection-no-suspense" width="386" />

#### Slow internet connection

With a slow internet the "Loading..." is ok, but the images load little by little, causing a little bit of agony

<img src="https://user-images.githubusercontent.com/792201/47619620-3e266300-dae1-11e8-8542-bb378d7f0d94.gif" alt="slow-connection-no-suspense" width="388" />

### With Suspense Features

#### Fast internet connection

Everything looks instant now, no more screen flickings or layout change

<img src="https://user-images.githubusercontent.com/792201/47619623-3e266300-dae1-11e8-9bc9-521e68b59b7d.gif" alt="fast-connection-with-suspense" width="384" />

#### Slow internet connection

The user now knows it's loading, but does not receive a broken experience anymore, we wait util everything is ready to show

<img src="https://user-images.githubusercontent.com/792201/47619624-3e266300-dae1-11e8-93dd-b35b9d81d54e.gif" alt="slow-connection-with-suspense" width="384" />

## How it works

### Loading data

In order for all this to work, I had to subvert the elm-architecture a little bit to be able to return Cmds while rendering, which means that you can load data, but that's nicely wrapper around the idea of caches to your date. If you have a view that needs to load some data, you can do it like this:

```elm
myView : Model -> String -> CmdHtml Msg
myView model id =
    getFromCache model.suspenseModel
        { cache = model.myCache
        , key = id
        , load = someHttpRequest id -- this is the actual request
        }
        (\data ->
            div []
              [ ...render it here...
              ]
        )
```

### Adding a timeout

On the example above, the view won't render until the data is ready, but sometimes you want to render at least something to give feedback to the user, you can do that using the `timeout` function, in which you can specify a fallback and a time for it to show. You can also replace this with the `suspense` function if you don't want to have any fallbacks.

The interesting part is that this function can be many parents above with many levels of suspended or regular views inside it, it's not directly bound to the data loading.

```elm
waitForMyView : Model -> String -> CmdHtml Msg
waitForMyView model id =
    (timeout model.suspenseModel
        { ms = 500, fallback = text "Loading...", key = "myViewTimeout" }
        (myView model id)
    )
```

### Preloading images

You can use the function `preloadImg` to render a view only after a image is loaded, it's as simple as this:

```elm
myViewWithImg : Model -> CmdHtml Msg
myViewWithImg model =
    preloadImg model.suspenseModel
        { src = "myimg.png" }
        (div [ ]
            [ img [ src "myimg.png" ] []
            , text "the image is ready!"
            ]
        )
```

### Other details

There are also other helper functions like `mapCmdView` and `mapCmdViewList` to help you wrapping the html inside the suspense features, and you also need to add some boilerplate on your main `Msg`, `Model` and `Update` for all this architectural change to work. Check the `src/` folder for more examples.

## Run it yourself

You can just clone the project and run `elm reactor`

Suggestions and PRs are welcome!
