# Uniques

Uniques (a.k.a. resources) are useful when you know there will only ever be a single instance of some component.  
In that case there is no need to attach the component to an entity. It also works well as global data while still being safe.

As opposed to other storages, uniques have to be initialized with `add_unique`. We can then access it with [`UniqueView`](https://docs.rs/shipyard/0.5.0/shipyard/struct.UniqueView.html) and [`UniqueViewMut`](https://docs.rs/shipyard/0.5.0/shipyard/struct.UniqueViewMut.html).

```rust, noplaypen
let world = World::new();

world.add_unique(Camera::new()).unwrap();

world
    .run(|camera: UniqueView<Camera>| {
        // -- snip --
    })
    .unwrap();
```
