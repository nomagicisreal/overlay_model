library;

import 'dart:async';

import 'package:flutter/material.dart'
    show
        StatefulWidget,
        State,
        Widget,
        WidgetBuilder,
        Overlay,
        OverlayState,
        OverlayEntry,
        OverlayPortal,
        OverlayPortalController,
        BuildContext;

///
///
/// In tradition, there are two way to insert overlay within a widget, both of them make code dirty:
///   1. parenting [OverlayPortal] and invoke [OverlayPortalController.toggle]
///     A. we have to parenting [OverlayPortal] above widget tree. deeper tree makes code much more complex.
///     B. we have to instance an [OverlayPortalController] for passing it to [OverlayPortal.controller]
///   2. invoke [OverlayState.insert] through [Overlay.of] by [State.context]
///     A. we have to instance [OverlayEntry]s to [OverlayEntry.markNeedsBuild], [OverlayEntry.remove].
///     B. we hove to implement some replicate code over different widgets.
///
/// with [OverlayMixin],
///   1. we don't have to parent our child widget.
///   2. we don't have to define overlay instance each time within different widget state only for basic logic
///   3. we can access more functionality of overlay by only a mixin
///     1. access to current overlays by getter [overlays]
///     2. directly insert overlay by function [overlayInsert]
/// See Also:
///   * [OverlayFutureMixin] implement [OverlayMixin] for common usage about [Future] with overlay
///   * [OverlayStreamMixin] implement [OverlayMixin] for common usage about [Stream] with overlay
///   * [OverlayModel] enable advance overlay entry operation in stateful widget [State]
///   * [OverlayPlan] helps [OverlayMixin.overlayInsert] to create concrete [OverlayModel]
///
///
mixin OverlayMixin<T extends StatefulWidget> implements State<T> {
  ///
  /// [_overlays] is a private list,
  /// empowering subclass to simultaneously control many overlay,
  /// preventing subclass from danger modification without proper overlay logic,
  ///
  final List<OverlayModel> _overlays = [];

  ///
  /// [overlays] is a subclass-proof, read only list.
  /// preventing subclass from performing overall modification on exist overlays list;
  /// instead, subclass can only perform modification for each overlay item by accessing [OverlayModel],
  ///
  List<OverlayModel> get overlays => List.of(_overlays, growable: false);

  ///
  /// [overlayInsert] is a delegate for replicate implementation for [OverlayState.insert].
  /// Excluding the insertion performed in [overlayInsert],
  /// for removal, naming as a function is a bad practice for entry required update before remove.
  /// for update, naming as a function is unnecessary to entry required instant removal without any update.
  /// Instead of naming functions be like "overlayUpdate" or "overlayRemove".
  /// it's better to integrate update, remove function during overlay initialization.
  /// See [OverlayModel] for implementation about update, removal.
  ///
  OverlayModel overlayInsert(
    OverlayPlan plan, {
    OverlayModel? below,
    OverlayModel? above,
  }) {
    final model = OverlayModel._from(plan, this, below?._entry, above?._entry);
    model._entry = plan._entryFrom(model);
    Overlay.of(
      context,
    ).insert(model._entry!, below: below?._entry, above: above?._entry);
    _overlays.add(model);
    return model;
  }
}

///
///
///
mixin OverlayFutureMixin<T extends StatefulWidget> on State<T>
    implements OverlayMixin<T> {
  Future<S> overlayWaitingFuture<S>({
    required Future<S> future,
    required OverlayPlan plan,
    required void Function(OverlayModel model) after,
    OverlayModel? below,
    OverlayModel? above,
  }) async {
    final model = overlayInsert(plan, below: below, above: above);
    final result = await future;
    after(model);
    return result;
  }
}

///
///
///
mixin OverlayStreamMixin<T extends StatefulWidget> on State<T>
    implements OverlayMixin<T> {
  StreamSubscription<S> overlayListenStream<S>({
    required Stream<S> stream,
    required OverlayPlan? Function(S data) planFor,
    OverlayModel? below,
    OverlayModel? above,
  }) => stream.listen((data) {
    final plan = planFor(data);
    if (plan == null) return;
    overlayInsert(plan, below: below, above: above);
  });
}

///
///
/// In tradition, we have to create an [OverlayEntry] passing into [OverlayState.insert],
/// and perform advance modification by [OverlayEntry.markNeedsBuild] or [OverlayEntry.remove], basically.
/// it's hard to distinguish the capability for each [OverlayEntry] when there is 2 or more entries,
/// we cannot defined an [OverlayEntry] is removable, updatable, or insertable?
/// it's possible that we just [OverlayEntry.remove] and find out the entry shouldn't be removed,
/// or we just [OverlayEntry.markNeedsBuild] and find out the entry have nothing to be updated.
/// it's danger to remove or update if we don't want to.
///
/// [OverlayModel] is safer than [OverlayEntry].
/// there are three main methods, [OverlayModel.insert], [OverlayModel.update], [OverlayModel.remove],
/// with 2^3 concrete implementation empowering safe overlay modification within widget.
/// See Also
///   * [OverlayMixin.overlayInsert] to know where [OverlayModel] been created.
///   * [OverlayPlan] to know how [OverlayModel] intended to be created.
///   * [_OverlayModelRemovableMixin], [_OverlayModelUpdatableMixin], [_OverlayModelInsertableMixin]
///   * [_OmR], ... [_OmRU], ..., [_OmRUI] are the other concrete [OverlayModel] implementations
///
final class OverlayModel {
  final OverlayMixin _owner;
  OverlayEntry? _below; // only for insertion
  OverlayEntry? _above; // only for insertion
  OverlayEntry? _entry; // for insertion and removal

  static const String _errorMessage_insert = 'cannot insert directly';
  static const String _errorMessage_update = 'cannot update directly';
  static const String _errorMessage_remove = 'cannot remove directly';

  // insert new, or insert after removal, ...
  void insert() => throw StateError('$this $_errorMessage_insert');

  // update to trigger animation, update to decide which widget to build, ...
  void update() => throw StateError('$this $_errorMessage_update');

  // remove after animation finished, remove after future, ...
  void remove() => throw Exception('$this $_errorMessage_remove');

  ///
  ///
  ///
  OverlayModel(this._owner, this._below, this._above);

  factory OverlayModel._from(
    OverlayPlan plan,
    OverlayMixin owner,
    OverlayEntry? b,
    OverlayEntry? a,
  ) {
    final removable = plan.isRemovable;
    final updatable = plan.isUpdatable;
    final insertable = plan.isInsertable;
    // 2^3 = 8
    if (removable && updatable && insertable) return _OmRUI(owner, b, a);
    if (removable && updatable && !insertable) return _OmRU(owner, b, a);
    if (removable && !updatable && insertable) return _OmRI(owner, b, a);
    if (!removable && updatable && insertable) return _OmUI(owner, b, a);
    if (removable && !updatable && !insertable) return _OmR(owner, b, a);
    if (!removable && updatable && !insertable) return _OmU(owner, b, a);
    if (!removable && !updatable && insertable) return _OmI(owner, b, a);
    return OverlayModel(owner, b, a); // !removable && !updatable && !insertable
  }
}

///
///
///
base mixin _OverlayModelUpdatableMixin on OverlayModel {
  @override
  void update() => _entry!.markNeedsBuild();
}

base mixin _OverlayModelRemovableMixin on OverlayModel {
  @override
  void remove() {
    _entry!.remove();
    _owner._overlays.remove(this);
  }
}

base mixin _OverlayModelInsertableMixin on OverlayModel {
  @override
  void insert() {
    Overlay.of(_owner.context).insert(_entry!, below: _below, above: _above);
    _owner._overlays.add(this);
  }
}

// 1
final class _OmR extends OverlayModel with _OverlayModelRemovableMixin {
  _OmR(super.owner, super._below, super._above);
}

final class _OmU extends OverlayModel with _OverlayModelUpdatableMixin {
  _OmU(super.owner, super._below, super._above);
}

final class _OmI extends OverlayModel with _OverlayModelInsertableMixin {
  _OmI(super.owner, super._below, super._above);
}

// 2
final class _OmRU extends OverlayModel
    with _OverlayModelRemovableMixin, _OverlayModelUpdatableMixin {
  _OmRU(super.owner, super._below, super._above);
}

final class _OmRI extends OverlayModel
    with _OverlayModelRemovableMixin, _OverlayModelInsertableMixin {
  _OmRI(super.owner, super._below, super._above);
}

final class _OmUI extends OverlayModel
    with _OverlayModelUpdatableMixin, _OverlayModelInsertableMixin {
  _OmUI(super.owner, super._below, super._above);
}

// 3
final class _OmRUI extends OverlayModel
    with
        _OverlayModelRemovableMixin,
        _OverlayModelUpdatableMixin,
        _OverlayModelInsertableMixin {
  _OmRUI(super.owner, super._below, super._above);
}

///
///
///
typedef OverlayModelBuilder =
    Widget Function(BuildContext context, OverlayModel modal);

///
/// See Also
///   * [OverlayMixin.overlayInsert] takes [OverlayPlan] as argument
///   * [OverlayModel] is the object [OverlayPlan] intend to create
///
final class OverlayPlan {
  // custom args
  final bool isRemovable;
  final bool isUpdatable;
  final bool isInsertable;
  final dynamic builder;

  // OverlayEntry args
  final bool opaque;
  final bool maintainState;
  final bool canSizeOverlay;

  const OverlayPlan({
    required this.isRemovable,
    this.isUpdatable = false,
    this.isInsertable = false,
    required WidgetBuilder this.builder,
    this.opaque = false,
    this.maintainState = false,
    this.canSizeOverlay = false,
  });

  const OverlayPlan.model({
    required this.isRemovable,
    this.isUpdatable = false,
    this.isInsertable = false,
    required OverlayModelBuilder this.builder,
    this.opaque = false,
    this.maintainState = false,
    this.canSizeOverlay = false,
  });

  ///
  ///
  ///
  static const String _errorState = 'unknown overlay plan';

  OverlayEntry _entryFrom(OverlayModel model) => OverlayEntry(
    opaque: opaque,
    maintainState: maintainState,
    canSizeOverlay: canSizeOverlay,
    builder: switch (builder) {
      WidgetBuilder() => builder,
      OverlayModelBuilder() => (context) => builder(context, model),
      Object() || null => throw StateError(OverlayPlan._errorState),
    },
  );
}
