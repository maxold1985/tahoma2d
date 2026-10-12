#pragma once

#ifndef JAPANESE_REGISTRATION_PEGBAR_OVERLAY_H
#define JAPANESE_REGISTRATION_PEGBAR_OVERLAY_H

#include <QColor>
#include <QContextMenuEvent>
#include <QCoreApplication>
#include <QEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QRegion>
#include <QResizeEvent>
#include <QTabletEvent>
#include <QTouchEvent>
#include <QTransform>
#include <QWidget>
#include <QtMath>

#include <cmath>
#include <functional>
#include <utility>

// Interactive registration guide for mouse, pen and touchscreen.
// Its widget mask follows the rotated ruler so that the rest of the
// animation viewer continues to receive pointer and multi-touch events.
class JapaneseRegistrationPegBar final : public QWidget {
public:
  enum Frame { Previous = 0, Current = 1, Next = 2 };

  explicit JapaneseRegistrationPegBar(QWidget *viewer, Frame frame)
      : QWidget(viewer), m_frame(frame) {
    setObjectName(QStringLiteral("JapaneseRegistrationPegBar%1").arg(int(frame)));
    setAttribute(Qt::WA_TranslucentBackground);
    setAttribute(Qt::WA_AcceptTouchEvents);
    setMouseTracking(true);
    setCursor(Qt::OpenHandCursor);
    m_opacity = frame == Current ? 100 : 35;
    setFixedSize(guideExtent(viewer), guideExtent(viewer));
    viewer->installEventFilter(this);
    resetPosition();
    updateHitMask();
    hide();
  }

  void resetPosition() {
    QWidget *viewer = parentWidget();
    if (!viewer) return;
    const int step = useTouchLayout() ? 66 : 54;
    const int centerY = (useTouchLayout() ? 49 : 34) + int(m_frame) * step;
    move((viewer->width() - width()) / 2, centerY - height() / 2);
    update();
  }

  void resetRotation() { setRotation(0.0); }

  void setRotation(double degrees) {
    m_rotation = degrees;
    updateHitMask();
    update();
  }

  double rotation() const { return m_rotation; }

  void commitRotation(double degrees) {
    const double change = degrees - m_rotation;
    setRotation(degrees);
    if (m_onTransformCommitted && qAbs(change) > 0.001)
      m_onTransformCommitted(QPoint(), change);
  }

  void setTransformCommitted(std::function<void(const QPoint &, double)> fn) {
    m_onTransformCommitted = std::move(fn);
  }

  void setBarOpacity(int percent) {
    m_opacity = qBound(0, percent, 100);
    update();
  }

  int barOpacity() const { return m_opacity; }

protected:
  bool eventFilter(QObject *watched, QEvent *event) override {
    if (watched == parentWidget() && event->type() == QEvent::Resize) {
      auto *resize = static_cast<QResizeEvent *>(event);
      const QSize oldSize = resize->oldSize();
      const int oldExtent = width();
      const int newExtent = guideExtent(parentWidget());
      if (newExtent != oldExtent) setFixedSize(newExtent, newExtent);
      updateHitMask();
      if (oldSize.isValid() && !m_dragging) {
        move(x() + (resize->size().width() - oldSize.width() +
                     oldExtent - newExtent) / 2,
             y() + (oldExtent - newExtent) / 2);
      }
    }
    return QWidget::eventFilter(watched, event);
  }

  bool event(QEvent *event) override {
    switch (event->type()) {
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::TouchCancel:
      if (handleTouch(static_cast<QTouchEvent *>(event))) {
        event->accept();
        return true;
      }
      break;
    default:
      break;
    }
    return QWidget::event(event);
  }

  void paintEvent(QPaintEvent *) override {
    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.translate(width() / 2.0, height() / 2.0);
    painter.rotate(m_rotation);
    painter.scale(width() / 350.0, height() / 350.0);

    QColor fill = m_frame == Current ? QColor(40, 133, 255)
                : m_frame == Previous ? QColor(71, 184, 117)
                                      : QColor(245, 88, 97);
    fill.setAlphaF(m_opacity / 100.0);

    painter.setPen(QPen(fill.darker(145), 1.5));
    painter.setBrush(fill);
    painter.drawRoundedRect(QRectF(-151, -13, 302, 26), 4, 4);

    painter.setPen(QPen(QColor(25, 33, 42), 2));
    painter.setBrush(QColor(245, 250, 255, 230));
    painter.drawRoundedRect(QRectF(-116, -3.5, 31, 7), 3, 3);
    painter.drawRoundedRect(QRectF(85, -3.5, 31, 7), 3, 3);
    painter.setBrush(QColor(25, 33, 42));
    painter.drawEllipse(QPointF(0, 0), 4, 4);
  }

  void mousePressEvent(QMouseEvent *event) override {
    if (m_touchActive || m_tabletActive) {
      event->accept();
      return;
    }
    if (event->button() != Qt::LeftButton) {
      QWidget::mousePressEvent(event);
      return;
    }
    beginDrag(event->globalPos(), event->modifiers().testFlag(Qt::ShiftModifier));
    event->accept();
  }

  void mouseMoveEvent(QMouseEvent *event) override {
    if (m_touchActive || m_tabletActive) {
      event->accept();
      return;
    }
    if (m_dragging) {
      updatePointerDrag(event->globalPos());
      event->accept();
      return;
    }
    QWidget::mouseMoveEvent(event);
  }

  void mouseReleaseEvent(QMouseEvent *event) override {
    if (m_touchActive || m_tabletActive) {
      event->accept();
      return;
    }
    if (event->button() == Qt::LeftButton && m_dragging) {
      finishDrag(false);
      event->accept();
      return;
    }
    QWidget::mouseReleaseEvent(event);
  }

  void tabletEvent(QTabletEvent *event) override {
    if (event->pointerType() == QTabletEvent::Eraser) {
      event->ignore();
      return;
    }
    switch (event->type()) {
    case QEvent::TabletPress:
      if (m_touchActive || m_dragging) {
        event->ignore();
        return;
      }
      m_tabletActive = true;
      beginDrag(event->globalPos(),
                event->modifiers().testFlag(Qt::ShiftModifier) ||
                    event->button() == Qt::RightButton);
      event->accept();
      return;
    case QEvent::TabletMove:
      if (m_tabletActive && m_dragging) {
        updatePointerDrag(event->globalPos());
        event->accept();
        return;
      }
      break;
    case QEvent::TabletRelease:
      if (m_tabletActive) {
        m_tabletActive = false;
        finishDrag(false);
        event->accept();
        return;
      }
      break;
    default:
      break;
    }
    QWidget::tabletEvent(event);
  }

  void contextMenuEvent(QContextMenuEvent *event) override {
    // Stylus side-button / right click over a bar opens the viewer menu.
    if (QWidget *viewer = parentWidget()) {
      QContextMenuEvent forwarded(event->reason(),
                                  mapTo(viewer, event->pos()),
                                  event->globalPos(), event->modifiers());
      QCoreApplication::sendEvent(viewer, &forwarded);
      event->accept();
      return;
    }
    QWidget::contextMenuEvent(event);
  }

private:
  static bool useTouchLayout() {
#if defined(Q_OS_ANDROID)
    return true;
#else
    return qgetenv("TAHOMA_PEG_TOUCH_UI") == "1";
#endif
  }

  static int guideExtent(const QWidget *viewer) {
    // QWidget dimensions are device-independent pixels, also on Android.
    return qMax(100, qMin(350, viewer->width() - 24));
  }

  void updateHitMask() {
    const double scale = width() / 350.0;
    QPainterPath path;
    // Wider hit band than the drawn ruler for fingers and S Pen.
    path.addRoundedRect(QRectF(-154, useTouchLayout() ? -24 : -19,
                               308, useTouchLayout() ? 48 : 38), 5, 5);
    QTransform transform;
    transform.translate(width() * 0.5, height() * 0.5);
    transform.rotate(m_rotation);
    transform.scale(scale, scale);
    setMask(QRegion(transform.map(path).toFillPolygon().toPolygon()));
  }

  void beginDrag(const QPointF &global, bool rotate) {
    m_dragging = true;
    m_rotate = rotate;
    m_dragOrigin = global;
    m_widgetOrigin = pos();
    m_startRotation = m_rotation;
    setCursor(m_rotate ? Qt::CrossCursor : Qt::ClosedHandCursor);
  }

  void updatePointerDrag(const QPointF &global) {
    if (!m_dragging) return;
    const QPointF delta = global - m_dragOrigin;
    if (m_rotate)
      setRotation(m_startRotation + delta.x() * 0.5);
    else
      move(m_widgetOrigin + QPoint(qRound(delta.x()), qRound(delta.y())));
  }

  void finishDrag(bool cancel) {
    if (!m_dragging) return;
    m_dragging = false;
    setCursor(Qt::OpenHandCursor);
    if (cancel) {
      move(m_widgetOrigin);
      setRotation(m_startRotation);
    } else if (m_onTransformCommitted) {
      const QPoint moveDelta = pos() - m_widgetOrigin;
      const double rotationDelta = m_rotation - m_startRotation;
      if (!moveDelta.isNull() || qAbs(rotationDelta) > 0.001)
        m_onTransformCommitted(moveDelta, rotationDelta);
    }
    m_lastTouchCount = 0;
    m_touchTranslation = QPointF();
  }

  bool handleTouch(QTouchEvent *event) {
    const auto points = event->touchPoints();
    if (event->type() == QEvent::TouchCancel) {
      if (m_touchActive) finishDrag(true);
      m_touchActive = false;
      return true;
    }
    if (event->type() == QEvent::TouchEnd) {
      if (m_touchActive) finishDrag(false);
      m_touchActive = false;
      return true;
    }
    if (m_tabletActive) return false;

    QList<QTouchEvent::TouchPoint> active;
    for (const auto &point : points) {
      if (!(point.state() & Qt::TouchPointReleased)) active.append(point);
    }
    if (active.isEmpty()) return false;

    QPointF center;
    for (const auto &point : active) center += point.screenPos();
    center /= active.size();

    double angle = 0;
    if (active.size() >= 2) {
      const QPointF vector = active[1].screenPos() - active[0].screenPos();
      angle = qRadiansToDegrees(std::atan2(vector.y(), vector.x()));
    }

    if (!m_touchActive && event->type() == QEvent::TouchBegin) {
      if (m_dragging) return false;
      m_touchActive = true;
      beginDrag(center, false);
      m_lastTouchCenter = center;
      m_lastTouchAngle = angle;
      m_lastTouchCount = active.size();
      return true;
    }
    if (!m_touchActive) return false;

    if (active.size() == m_lastTouchCount) {
      m_touchTranslation += center - m_lastTouchCenter;
      move(m_widgetOrigin +
           QPoint(qRound(m_touchTranslation.x()), qRound(m_touchTranslation.y())));
      if (active.size() >= 2) {
        double deltaAngle = angle - m_lastTouchAngle;
        while (deltaAngle > 180.0) deltaAngle -= 360.0;
        while (deltaAngle < -180.0) deltaAngle += 360.0;
        setRotation(m_rotation + deltaAngle);
      }
    }
    // Do not jump when a second finger enters or leaves the gesture.
    m_lastTouchCenter = center;
    m_lastTouchAngle = angle;
    m_lastTouchCount = active.size();
    return true;
  }

  std::function<void(const QPoint &, double)> m_onTransformCommitted;
  Frame m_frame;
  int m_opacity = 100;
  double m_rotation = 0.0;
  bool m_dragging = false;
  bool m_rotate = false;
  bool m_touchActive = false;
  bool m_tabletActive = false;
  int m_lastTouchCount = 0;
  double m_startRotation = 0.0;
  double m_lastTouchAngle = 0.0;
  QPointF m_dragOrigin;
  QPointF m_lastTouchCenter;
  QPointF m_touchTranslation;
  QPoint m_widgetOrigin;
};

inline JapaneseRegistrationPegBar *registrationPegBar(
    QWidget *viewer, JapaneseRegistrationPegBar::Frame frame) {
  const QString name =
      QStringLiteral("JapaneseRegistrationPegBar%1").arg(int(frame));
  auto *bar = viewer->findChild<JapaneseRegistrationPegBar *>(name);
  if (!bar) bar = new JapaneseRegistrationPegBar(viewer, frame);
  return bar;
}

#endif  // JAPANESE_REGISTRATION_PEGBAR_OVERLAY_H
