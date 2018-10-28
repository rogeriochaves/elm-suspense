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

![fast-connection-no-suspense](https://user-images.githubusercontent.com/792201/47619622-3e266300-dae1-11e8-8054-6f10cbc317f2.gif)

#### Slow internet connection

With a slow internet the "Loading..." is ok, but the images load little by little, causing a little bit of agony

![slow-connection-no-suspense](https://user-images.githubusercontent.com/792201/47619620-3e266300-dae1-11e8-8542-bb378d7f0d94.gif)

### With Suspense Features

#### Fast internet connection

Everything looks instant now, no more screen flickings or layout change

![fast-connection-with-suspense](https://user-images.githubusercontent.com/792201/47619623-3e266300-dae1-11e8-9bc9-521e68b59b7d.gif)

#### Slow internet connection

The user now knows it's loading, but does not receive a broken experience anymore, we wait util everything is ready to show

![slow-connection-with-suspense](https://user-images.githubusercontent.com/792201/47619624-3e266300-dae1-11e8-93dd-b35b9d81d54e.gif)

## Run it yourself

You can just clone the project and run `elm reactor`
