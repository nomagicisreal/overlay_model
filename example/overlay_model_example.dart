import 'package:flutter/material.dart';
import 'package:overlay_model/overlay_model.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: Sample()));
  }
}

class Sample extends StatefulWidget {
  const Sample({super.key});

  @override
  State<Sample> createState() => _SampleState();
}

class _SampleState extends State<Sample>
    with
        OverlayMixin<Sample>,
        OverlayFutureMixin<Sample>,
        OverlayStreamMixin<Sample>
        {
  ///
  ///
  /// comparison for old way and new way
  ///
  ///
  // OverlayEntry? entry;
  //
  // void toggle() {
  //   OverlayEntry? entry = this.entry;
  //   if (entry == null) {
  //     entry = OverlayEntry(builder: buildOverlay);
  //     this.entry = entry;
  //     Overlay.of(context).insert(entry);
  //     return;
  //   }
  //   entry.remove();
  // }

  // void toggle() =>
  //     overlays.isEmpty
  //         ? overlayInsert(
  //           OverlayPlan(
  //             isRemovable: true,
  //             builder: buildOverlay,
  //           ),
  //         )
  //         : overlays.first.remove();

  // Widget buildOverlay(BuildContext context) => Center(
  //   child: SizedBox.square(
  //     dimension: 100,
  //     child: ColoredBox(
  //       color: Colors.red.shade200,
  //       child: TextButton(
  //         onPressed: toggle,
  //         // onPressed: _newWay,
  //         child: Text('remove overlay'),
  //       ),
  //     ),
  //   ),
  // );

  ///
  /// demo future
  ///
  // void toggle() => overlayWaitingFuture(
  //   future: Future.delayed(Duration(seconds: 1)),
  //   plan: OverlayPlan(
  //     isRemovable: true,
  //     builder: buildOverlay,
  //   ),
  //   after: (model) {
  //     if (overlays.isEmpty) return;
  //     model.remove();
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('overlay is removed after future')),
  //     );
  //   },
  // );
  //
  // Widget buildOverlay(BuildContext context) => Center(
  //   child: SizedBox.square(
  //     dimension: 50,
  //     child: CircularProgressIndicator(),
  //   ),
  // );

  ///
  /// demo and stream
  ///
  Stream<int> stream() async* {
    for (var i = 0; i < 6; i++) {
      yield i;
      await Future.delayed(Duration(milliseconds: 2500));
    }
  }

  void toggle() => overlayListenStream(
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(onPressed: toggle, child: Text('insert new overlay')),
    );
  }
}
