/*
 * Copyright (C) 2019-present Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

import 'package:kraken/rendering.dart';
import 'package:kraken/gesture.dart';
import 'package:kraken/dom.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';

class GestureManager {

  static GestureManager? _instance;
  GestureManager._();

  factory GestureManager.instance() {
    if (_instance == null) {
      _instance = GestureManager._();

      _instance!.gestures[EVENT_CLICK] = ClickGestureRecognizer();
      (_instance!.gestures[EVENT_CLICK] as ClickGestureRecognizer).onClick = _instance!.onClick;

      _instance!.gestures[EVENT_SWIPE] = SwipeGestureRecognizer();
      (_instance!.gestures[EVENT_SWIPE] as SwipeGestureRecognizer).onSwipe = _instance!.onSwipe;

      _instance!.gestures[EVENT_PAN] = PanGestureRecognizer();
      (_instance!.gestures[EVENT_PAN] as PanGestureRecognizer).onStart = _instance!.onPanStart;
      (_instance!.gestures[EVENT_PAN] as PanGestureRecognizer).onUpdate = _instance!.onPanUpdate;
      (_instance!.gestures[EVENT_PAN] as PanGestureRecognizer).onEnd = _instance!.onPanEnd;

      _instance!.gestures[EVENT_LONG_PRESS] = LongPressGestureRecognizer();
      (_instance!.gestures[EVENT_LONG_PRESS] as LongPressGestureRecognizer).onLongPressEnd = _instance!.onLongPressEnd;

      _instance!.gestures[EVENT_SCALE] = ScaleGestureRecognizer();
      (_instance!.gestures[EVENT_SCALE] as ScaleGestureRecognizer).onStart = _instance!.onScaleStart;
      (_instance!.gestures[EVENT_SCALE] as ScaleGestureRecognizer).onUpdate = _instance!.onScaleUpdate;
      (_instance!.gestures[EVENT_SCALE] as ScaleGestureRecognizer).onEnd = _instance!.onScaleEnd;
    }
    return _instance!;
  }

  final Map<String, GestureRecognizer> gestures = <String, GestureRecognizer>{};

  List<RenderBox> _hitTestList = [];

  Map<int, PointerEvent> eventByPointer = Map();

  Map<int, RenderPointerListenerMixin> targetByPointer = Map();

  List<int> points = [];

  void addTargetToList(RenderBox target) {
    _hitTestList.add(target);
  }

  void clearTargetList() {
    _hitTestList = [];
  }

  void addPointer(PointerEvent event) {
    // Collect the events in the hitTest.
    List<String> events = [];
    for (int i = 0; i < _hitTestList.length; i++) {
      RenderBox renderBox = _hitTestList[i];
      Map<String, List<EventHandler>> eventHandlers = {};
      if (renderBox is RenderPointerListenerMixin && renderBox.getEventHandlers != null) {
        eventHandlers = renderBox.getEventHandlers!();
      }

      if (!eventHandlers.keys.isEmpty) {
        if (!events.contains(EVENT_CLICK) && eventHandlers.containsKey(EVENT_CLICK)) {
          events.add(EVENT_CLICK);
        }
        if (!events.contains(EVENT_SWIPE) && eventHandlers.containsKey(EVENT_SWIPE)) {
          events.add(EVENT_SWIPE);
        }
        if (!events.contains(EVENT_PAN) && eventHandlers.containsKey(EVENT_PAN)) {
          events.add(EVENT_PAN);
        }
        if (!events.contains(EVENT_LONG_PRESS) && eventHandlers.containsKey(EVENT_LONG_PRESS)) {
          events.add(EVENT_LONG_PRESS);
        }
        if (!events.contains(EVENT_SCALE) && eventHandlers.containsKey(EVENT_SCALE)) {
          events.add(EVENT_SCALE);
        }
      }
    }

    String touchType = '';

    if (event is PointerDownEvent) {
      touchType = EVENT_TOUCH_START;
      eventByPointer[event.pointer] = event;
      points.add(event.pointer);

      // Add pointer to gestures then register the gesture recognizer to the arena.
      gestures.forEach((key, gesture) {
        // Register the recognizer that needs to be monitored.
        if (events.contains(key)) {
          gesture.addPointer(event as PointerDownEvent);
        }
      });

      // The target node triggered by the gesture is the bottom node of hitTest.
      // The scroll element needs to be judged by isScrollingContentBox to find the real element upwards.
      if (_hitTestList.isNotEmpty) {
        for (int i = 0; i < _hitTestList.length; i++) {
          RenderBox renderBox = _hitTestList[i];
          if ((renderBox is RenderBoxModel && !renderBox.isScrollingContentBox) || renderBox is RenderViewportBox) {
            targetByPointer[event.pointer] = renderBox as RenderPointerListenerMixin;
            break;
          }
        }
      }
    } else if (event is PointerMoveEvent) {
      touchType = EVENT_TOUCH_MOVE;
      eventByPointer[event.pointer] = event;
    } else if (event is PointerUpEvent) {
      touchType = EVENT_TOUCH_END;
      points.remove(event.pointer);
      eventByPointer.remove(event.pointer);
    }

    if (targetByPointer[event.pointer] != null) {
      RenderPointerListenerMixin currentTarget = targetByPointer[event.pointer] as RenderPointerListenerMixin;

      TouchEvent e = TouchEvent(touchType);
      var pointerEventOriginal = event.original;
      // Use original event, prevent to be relative coordinate
      if (pointerEventOriginal != null) event = pointerEventOriginal;

      for (int i = 0; i < points.length; i++) {
        int pointer = points[i];
        PointerEvent point = eventByPointer[pointer] as PointerEvent;
        RenderPointerListenerMixin target = targetByPointer[pointer] as RenderPointerListenerMixin;

        EventTarget node = target.getEventTarget!();

        Touch touch = Touch(
          identifier: point.pointer,
          target: node,
          screenX: point.position.dx,
          screenY: point.position.dy,
          clientX: point.localPosition.dx,
          clientY: point.localPosition.dy,
          pageX: point.localPosition.dx,
          pageY: point.localPosition.dy,
          radiusX: point.radiusMajor,
          radiusY: point.radiusMinor,
          rotationAngle: point.orientation,
          force: point.pressure,
        );

        e.changedTouches.append(touch);
        e.targetTouches.append(touch);
        e.touches.append(touch);
      }

      if (currentTarget.dispatchEvent != null) {
        currentTarget.dispatchEvent!(e);
      }

      //
      // if (currentTarget.onPointerDown != null && event is PointerDownEvent)
      //   currentTarget.onPointerDown!(event);
      // if (currentTarget.onPointerMove != null && event is PointerMoveEvent)
      //   currentTarget.onPointerMove!(event);
      // if (currentTarget.onPointerUp != null && event is PointerUpEvent)
      //   currentTarget.onPointerUp!(event);
      // if (currentTarget.onPointerCancel != null && event is PointerCancelEvent)
      //   currentTarget.onPointerCancel!(event);
      // if (currentTarget.onPointerSignal != null && event is PointerSignalEvent)
      //   currentTarget.onPointerSignal!(event);
    }
  }

  void onClick(String eventType, { PointerDownEvent? down, PointerUpEvent? up }) {
    if (targetByPointer[down?.pointer] != null) {
      RenderPointerListenerMixin target = targetByPointer[down?.pointer] as RenderPointerListenerMixin;
      if (target.onClick != null) {
        target.onClick!(eventType, up: up);
      }
    }
  }

  void onSwipe(Event event) {
    // if (targetByPointer[event?.pointer] != null) {
    //   RenderPointerListenerMixin target = targetByPointer[down?.pointer] as RenderPointerListenerMixin;
    //   if (target!.onSwipe != null) {
    //     target!.onSwipe!(event);
    //   }
    // }
  }

  void onPanStart(DragStartDetails details) {
    // if (_target != null && _target!.onPan != null) {
    //   _target!.onPan!(
    //       GestureEvent(
    //           EVENT_PAN,
    //           GestureEventInit(
    //               state: EVENT_STATE_START,
    //               deltaX: details.globalPosition.dx,
    //               deltaY: details.globalPosition.dy
    //           )
    //       )
    //   );
    // }
  }

  void onPanUpdate(DragUpdateDetails details) {
    // if (_target != null && _target!.onPan != null) {
    //   _target!.onPan!(
    //       GestureEvent(
    //           EVENT_PAN,
    //           GestureEventInit(
    //               state: EVENT_STATE_UPDATE,
    //               deltaX: details.globalPosition.dx,
    //               deltaY: details.globalPosition.dy
    //           )
    //       )
    //   );
    // }
  }

  void onPanEnd(DragEndDetails details) {
    // if (_target != null && _target!.onPan != null) {
    //   _target!.onPan!(
    //       GestureEvent(
    //           EVENT_PAN,
    //           GestureEventInit(
    //               state: EVENT_STATE_END,
    //               velocityX: details.velocity.pixelsPerSecond.dx,
    //               velocityY: details.velocity.pixelsPerSecond.dy
    //           )
    //       )
    //   );
    // }
  }

  void onScaleStart(ScaleStartDetails details) {
    // if (_target != null && _target!.onScale != null) {
    //   _target!.onScale!(
    //       GestureEvent(
    //           EVENT_SCALE,
    //           GestureEventInit( state: EVENT_STATE_START )
    //       )
    //   );
    // }
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    // if (_target != null && _target!.onScale != null) {
    //   _target!.onScale!(
    //       GestureEvent(
    //           EVENT_SCALE,
    //           GestureEventInit(
    //               state: EVENT_STATE_UPDATE,
    //               rotation: details.rotation,
    //               scale: details.scale
    //           )
    //       )
    //   );
    // }
  }

  void onScaleEnd(ScaleEndDetails details) {
    // if (_target != null && _target!.onScale != null) {
    //   _target!.onScale!(
    //       GestureEvent(
    //           EVENT_SCALE,
    //           GestureEventInit( state: EVENT_STATE_END )
    //       )
    //   );
    // }
  }

  void onLongPressEnd(LongPressEndDetails details) {
    // if (_target != null && _target!.onLongPress != null) {
    //   _target!.onLongPress!(
    //       GestureEvent(
    //           EVENT_LONG_PRESS,
    //           GestureEventInit(
    //               deltaX: details.globalPosition.dx,
    //               deltaY: details.globalPosition.dy
    //           )
    //       )
    //   );
    // }
  }
}
