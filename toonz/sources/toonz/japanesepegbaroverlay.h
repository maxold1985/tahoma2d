#pragma once

#ifndef JAPANESE_REGISTRATION_PEGBAR_OVERLAY_H
#define JAPANESE_REGISTRATION_PEGBAR_OVERLAY_H

#include <QColor>
#include <QEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QResizeEvent>
#include <QWidget>
#include <QtMath>

// Viewer-only registration guides.  These do not modify the Xsheet, stage
// objects or scene files; animation transformations remain the tool's job.
class JapaneseRegistrationPegBar final : public QWidget {
public:
  enum Frame { Previous = 0, Current = 1, Next = 2 };

  explicit JapaneseRegistrationPegBar(QWidget *viewer, Frame frame)
      : QWidget(viewer), m_frame(frame) {
    setObjectName(QStringLiteral("JapaneseRegistrationPegBar%1").arg(frame));
    setAttribute(Qt::WA_TranslucentBackground);
    setMouseTracking(true);
    setCursor(Qt::OpenHandCursor);
    setFixedSize(350, 50);
    m_opacity = frame == Current ? 100 : 35;
    viewer->installEventFilter(this);
    resetPosition();
    hide();
  }

  void resetPosition() {
    QWidget *viewer = parentWidget();
    if (!viewer) return;
    move((viewer->width() - width()) / 2, 15 + int(m_frame) * 54);
    update();
  }

  void resetRotation() {
    m_rotation = 0.0;
    update();
  }

  void setRotation(double degrees) {
    m_rotation = degrees;
    update();
  }

  double rotation() const { return m_rotation; }

  void setBarOpacity(int percent) {
    m_opacity = qBound(0, percent, 100);
    update();
  }

  int barOpacity() const { return m_opacity; }

protected:
  bool eventFilter(QObject *watched, QEvent *event) override {
    if (watched == parentWidget() && event->type() == QEvent::Resize) {
      // Preserve the guide's offset from the viewer center on resize.
      const auto *resize = static_cast<QResizeEvent *>(event);
      const int dx = (resize->size().width() - resize->oldSize().width()) / 2;
      if (resize->oldSize().isValid()) move(x() + dx, y());
    }
    return QWidget::eventFilter(watched, event);
  }

  void paintEvent(QPaintEvent *) override {
    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.translate(width() / 2.0, height() / 2.0);
    painter.rotate(m_rotation);

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
    if (event->button() != Qt::LeftButton) {
      QWidget::mousePressEvent(event);
      return;
    }
    m_dragging = true;
    m_dragOrigin = event->globalPos();
    m_widgetOrigin = pos();
    m_startRotation = m_rotation;
    m_rotate = event->modifiers().testFlag(Qt::ShiftModifier);
    setCursor(m_rotate ? Qt::CrossCursor : Qt::ClosedHandCursor);
    event->accept();
  }

  void mouseMoveEvent(QMouseEvent *event) override {
    if (!m_dragging) {
      QWidget::mouseMoveEvent(event);
      return;
    }
    const QPoint delta = event->globalPos() - m_dragOrigin;
    if (m_rotate)
      setRotation(m_startRotation + delta.x() * 0.5);
    else
      move(m_widgetOrigin + delta);
    event->accept();
  }

  void mouseReleaseEvent(QMouseEvent *event) override {
    if (event->button() == Qt::LeftButton && m_dragging) {
      m_dragging = false;
      setCursor(Qt::OpenHandCursor);
      event->accept();
      return;
    }
    QWidget::mouseReleaseEvent(event);
  }

private:
  Frame m_frame;
  int m_opacity = 100;
  double m_rotation = 0.0;
  bool m_dragging = false;
  bool m_rotate = false;
  double m_startRotation = 0.0;
  QPoint m_dragOrigin;
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
