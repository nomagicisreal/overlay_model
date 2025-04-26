# Overlay Model

you can find the example below in `example/overlay_model_example.dart`.

without this library, this is how we create overlay by `OverlayEntry` and `OverlayState`:

```dart
class _SampleState extends State<Sample> {
  Widget buildOverlay(BuildContext context) =>
      Center(
        child: SizedBox.square(
          dimension: 100,
          child: ColoredBox(
            color: Colors.red.shade200,
            child: TextButton(
              onPressed: _toggle,
              child: Text('remove overlay'),
            ),
          ),
        ),
      );

  OverlayEntry? entry;

  void _toggle() {
    OverlayEntry? entry = this.entry;
    if (entry == null) {
      entry = OverlayEntry(builder: buildOverlay);
      this.entry = entry;
      Overlay.of(context).insert(entry);
      return;
    }
    entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: _toggle,
        child: Text('insert new overlay'),
      ),
    );
  }
}
```

with this library, we can create overlay by a mixin without holding `OverlayEntry` instance:

```dart
class _SampleState extends State<Sample> with OverlayMixin<Sample> {
  // ...
  void _toggle() =>
      overlays.isEmpty
          ? overlayInsert(
        OverlayPlan(
          isRemovable: true,
          isUpdatable: false,
          builder: buildOverlay,
        ),
      )
          : overlays.first.remove();

// ...
}
```

Not only we don't have to create an overlay entry instance,
but we also have more control on overlay insertion, update, removal by `OverlayPlan` and
`OverlayModel`.\n
Not just `OverlayMixin`, there are also `OverlayFutureMixin` and `OverlayStreamMixin` !

take `OverlayFutureMixin` for example:

```dart
class _SampleState extends State<Sample> with OverlayMixin<Sample>, OverlayFutureMixin<Sample> {
  void toggle() =>
      overlayWaitingFuture(
        future: Future.delayed(Duration(seconds: 1)),
        plan: OverlayPlan(
          isRemovable: true,
          builder: buildOverlay,
        ),
        after: (model) {
          if (overlays.isEmpty) return;
          model.remove();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('overlay is removed after future')),
          );
        },
      );

  Widget buildOverlay(BuildContext context) =>
      Center(
        child: SizedBox.square(
          dimension: 50,
          child: CircularProgressIndicator(),
        ),
      );
// ...
}
```

take `OverlayStreamMixin` for example:

```dart
class _SampleState extends State<Sample>
    with OverlayMixin<Sample>, OverlayFutureMixin<Sample>, OverlayStreamMixin<Sample> {
  Stream<int> stream() async* {
    for (var i = 0; i < 6; i++) {
      yield i;
      await Future.delayed(Duration(milliseconds: 2500));
    }
  }

  void toggle() =>
      overlayListenStream(
        stream: stream(),
        planFor: (data) {
          if (data % 2 == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('received $data and insert overlay'),
                duration: Duration(seconds: 1),
              ),
            );
            return OverlayPlan.model(
              isRemovable: true,
              builder: (context, model) => buildOverlay(context, model, data),
            );
          }
          overlays.first.remove();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('previous overlay is removed'),
              duration: Duration(seconds: 1),
            ),
          );
          return null;
        },
      );

  Widget buildOverlay(BuildContext context, OverlayModel model, int data) =>
      Center(
        child: SizedBox.square(
          dimension: 50,
          child: Material(
            textStyle: TextStyle(color: Colors.red),
            shape: CircleBorder(side: BorderSide(color: Colors.black)),
            child: Center(child: Text('data: $data')),
          ),
        ),
      );
// ...
}
```

see the comment above `lib/overlay_model.dart` to understand how it works !
hopes you have fun in programming !
