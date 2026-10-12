// Standalone smoke test for the Peg Bar overlay's mouse and touch paths.
// This does NOT test or build the complete Tahoma2D Android application.
#include "../toonz/sources/toonz/japanesepegbaroverlay.h"

#include <QApplication>
#include <QDebug>
#include <QTouchDevice>

static void failIf(bool condition, const char *message) {
  if (condition) qFatal("%s", message);
}

static QTouchEvent::TouchPoint touchPoint(int id, Qt::TouchPointState state,
                                          const QPointF &screen) {
  QTouchEvent::TouchPoint point(id);
  point.setState(state);
  point.setScreenPos(screen);
  point.setPos(screen);
  return point;
}

int main(int argc, char **argv) {
  QApplication app(argc, argv);
  QWidget viewer;
  viewer.resize(800, 600);
  viewer.show();

  auto *previous = registrationPegBar(
      &viewer, JapaneseRegistrationPegBar::Previous);
  auto *current = registrationPegBar(
      &viewer, JapaneseRegistrationPegBar::Current);
  auto *next = registrationPegBar(
      &viewer, JapaneseRegistrationPegBar::Next);

  failIf(previous == current || current == next,
         "Each frame must have a separate guide");
  failIf(current->barOpacity() != 100 || previous->barOpacity() != 35 ||
             next->barOpacity() != 35,
         "Default opacities differ from registration guide specification");
  failIf(current->mask().isEmpty(), "Rotating ruler must have a hit mask");

  current->show();
  QApplication::processEvents();

  int commits = 0;
  QPoint lastDelta;
  double lastRotation = 0.0;
  current->setTransformCommitted([&](const QPoint &delta, double angle) {
    ++commits;
    lastDelta = delta;
    lastRotation = angle;
  });

  const QPoint initial = current->pos();
  const QPoint local(current->width() / 2, current->height() / 2);
  const QPoint global = current->mapToGlobal(local);

  QMouseEvent mouseDown(QEvent::MouseButtonPress, local, global,
                        Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
  QApplication::sendEvent(current, &mouseDown);
  QMouseEvent mouseMove(QEvent::MouseMove, local + QPoint(24, 0),
                        global + QPoint(24, 0), Qt::NoButton, Qt::LeftButton,
                        Qt::NoModifier);
  QApplication::sendEvent(current, &mouseMove);
  QMouseEvent mouseUp(QEvent::MouseButtonRelease, local + QPoint(24, 0),
                      global + QPoint(24, 0), Qt::LeftButton, Qt::NoButton,
                      Qt::NoModifier);
  QApplication::sendEvent(current, &mouseUp);

  failIf(commits != 1 || current->pos() - initial != QPoint(24, 0) ||
             lastDelta != QPoint(24, 0),
         "Mouse drag must commit a single displacement");

  current->resetPosition();

  QMouseEvent shiftDown(QEvent::MouseButtonPress, local,
                        current->mapToGlobal(local), Qt::LeftButton,
                        Qt::LeftButton, Qt::ShiftModifier);
  QApplication::sendEvent(current, &shiftDown);
  QMouseEvent shiftMove(QEvent::MouseMove, local + QPoint(40, 0),
                        current->mapToGlobal(local) + QPoint(40, 0),
                        Qt::NoButton, Qt::LeftButton, Qt::ShiftModifier);
  QApplication::sendEvent(current, &shiftMove);
  QMouseEvent shiftUp(QEvent::MouseButtonRelease, local + QPoint(40, 0),
                      current->mapToGlobal(local) + QPoint(40, 0),
                      Qt::LeftButton, Qt::NoButton, Qt::ShiftModifier);
  QApplication::sendEvent(current, &shiftUp);
  failIf(commits != 2 || qAbs(lastRotation - 20.0) > 0.01,
         "Shift-drag must rotate and commit a single change");

  current->resetPosition();
  current->resetRotation();

  QTouchDevice device;
  device.setType(QTouchDevice::TouchScreen);
  device.setCapabilities(QTouchDevice::Position);

  const QPointF p = current->mapToGlobal(local);
  QTouchEvent begin(QEvent::TouchBegin, &device, Qt::NoModifier,
                    Qt::TouchPointPressed,
                    {touchPoint(0, Qt::TouchPointPressed, p)});
  QApplication::sendEvent(current, &begin);
  QTouchEvent update(QEvent::TouchUpdate, &device, Qt::NoModifier,
                     Qt::TouchPointMoved,
                     {touchPoint(0, Qt::TouchPointMoved, p + QPointF(30, 10))});
  QApplication::sendEvent(current, &update);
  QTouchEvent end(QEvent::TouchEnd, &device, Qt::NoModifier,
                  Qt::TouchPointReleased,
                  {touchPoint(0, Qt::TouchPointReleased, p + QPointF(30, 10))});
  QApplication::sendEvent(current, &end);

  failIf(commits != 3 || lastDelta != QPoint(30, 10),
         "One-finger move must commit displacement exactly once");

  current->resetPosition();
  current->resetRotation();
  const QPointF c = current->mapToGlobal(local);
  QTouchEvent multiBegin(
      QEvent::TouchBegin, &device, Qt::NoModifier, Qt::TouchPointPressed,
      {touchPoint(0, Qt::TouchPointPressed, c + QPointF(-40, 0)),
       touchPoint(1, Qt::TouchPointPressed, c + QPointF(40, 0))});
  QApplication::sendEvent(current, &multiBegin);
  QTouchEvent multiRotate(
      QEvent::TouchUpdate, &device, Qt::NoModifier, Qt::TouchPointMoved,
      {touchPoint(0, Qt::TouchPointMoved, c + QPointF(0, -40)),
       touchPoint(1, Qt::TouchPointMoved, c + QPointF(0, 40))});
  QApplication::sendEvent(current, &multiRotate);
  QTouchEvent multiEnd(
      QEvent::TouchEnd, &device, Qt::NoModifier, Qt::TouchPointReleased,
      {touchPoint(0, Qt::TouchPointReleased, c + QPointF(0, -40)),
       touchPoint(1, Qt::TouchPointReleased, c + QPointF(0, 40))});
  QApplication::sendEvent(current, &multiEnd);

  failIf(commits != 4 || qAbs(lastRotation - 90.0) > 1.0,
         "Two-finger rotation must commit a 90 degree change");

  const int committed = commits;
  current->resetPosition();
  current->resetRotation();
  QTouchEvent cancelBegin(QEvent::TouchBegin, &device, Qt::NoModifier,
                          Qt::TouchPointPressed,
                          {touchPoint(0, Qt::TouchPointPressed, p)});
  QApplication::sendEvent(current, &cancelBegin);
  QTouchEvent cancelMove(QEvent::TouchUpdate, &device, Qt::NoModifier,
                         Qt::TouchPointMoved,
                         {touchPoint(0, Qt::TouchPointMoved,
                                     p + QPointF(21, 0))});
  QApplication::sendEvent(current, &cancelMove);
  QTouchEvent cancel(QEvent::TouchCancel, &device);
  QApplication::sendEvent(current, &cancel);
  failIf(commits != committed || current->rotation() != 0,
         "Canceled Android gesture must not alter the scene");

  qInfo() << "Japanese Registration Peg Bar mouse/touch smoke test passed";
  return 0;
}
