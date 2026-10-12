package org.maxold1985.tahoma2d.pegbarpreview;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.ArrayDeque;

/**
 * Standalone Android touch demonstration. This is not the entire Tahoma2D
 * editor or a replacement for its Qt/C++ Peg Bar implementation.
 */
public final class MainActivity extends Activity {
    private PegCanvas canvas;
    private TextView description;

    @Override
    public void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        getWindow().setStatusBarColor(Color.rgb(24, 32, 47));
        getWindow().setNavigationBarColor(Color.rgb(24, 32, 47));

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.rgb(24, 32, 47));

        TextView title = new TextView(this);
        title.setText("Tahoma2D · Japanese Registration Peg Bar");
        title.setTextColor(Color.WHITE);
        title.setTextSize(18);
        title.setPadding(dp(12), dp(12), dp(12), dp(8));
        root.addView(title);

        LinearLayout controls = new LinearLayout(this);
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        scroll.addView(controls);
        root.addView(scroll);
        canvas = new PegCanvas();

        button(controls, "Previous", () -> select(0));
        button(controls, "Current", () -> select(1));
        button(controls, "Next", () -> select(2));
        button(controls, "Ghosts", () -> canvas.toggleGhosts());
        button(controls, "Undo", () -> canvas.undo());
        button(controls, "Redo", () -> canvas.redo());
        button(controls, "Reset", () -> canvas.reset());

        root.addView(canvas, new LinearLayout.LayoutParams(-1, 0, 1));
        description = new TextView(this);
        description.setTextColor(Color.rgb(225, 235, 249));
        description.setPadding(dp(12), dp(10), dp(12), dp(14));
        root.addView(description);
        setContentView(root);
        updateDescription();
    }

    private int dp(float d) {
        return Math.round(d * getResources().getDisplayMetrics().density);
    }

    private void button(LinearLayout controls, String text, Runnable action) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        controls.addView(button, new LinearLayout.LayoutParams(-2, dp(56)));
        button.setOnClickListener(v -> action.run());
    }

    private void select(int index) {
        canvas.selected = index;
        canvas.invalidate();
        updateDescription();
    }

    private void updateDescription() {
        final String[] names = {"Previous", "Current", "Next"};
        description.setText(names[canvas.selected] + " · Touch or S Pen to move · "
                + "Two fingers to rotate. This APK is a Peg Bar preview, "
                + "not the full Tahoma2D editor.");
    }

    private static final class Bar {
        float x, y, rotation;
    }

    private static final class Snapshot {
        final float[] x = new float[3], y = new float[3], rotation = new float[3];
        Snapshot(Bar[] bars) {
            for (int i = 0; i < 3; i++) {
                x[i] = bars[i].x; y[i] = bars[i].y; rotation[i] = bars[i].rotation;
            }
        }
        void apply(Bar[] bars) {
            for (int i = 0; i < 3; i++) {
                bars[i].x = x[i]; bars[i].y = y[i]; bars[i].rotation = rotation[i];
            }
        }
        boolean differs(Bar[] bars) {
            for (int i = 0; i < 3; i++)
                if (bars[i].x != x[i] || bars[i].y != y[i] ||
                        bars[i].rotation != rotation[i]) return true;
            return false;
        }
    }

    private final class PegCanvas extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Bar[] bars = {new Bar(), new Bar(), new Bar()};
        private final int[] colors = {0xff47b875, 0xff2885ff, 0xfff55861};
        private final String[] labels = {"PREVIOUS", "CURRENT", "NEXT"};
        private final ArrayDeque<Snapshot> undo = new ArrayDeque<>();
        private final ArrayDeque<Snapshot> redo = new ArrayDeque<>();
        int selected = 1;
        boolean ghosts = true, ready, dragging;
        int previousCount;
        float previousX, previousY, previousAngle;
        Snapshot gestureStart;

        PegCanvas() {
            super(MainActivity.this);
            setBackgroundColor(Color.rgb(32, 43, 60));
            setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        }

        @Override
        protected void onSizeChanged(int w, int h, int oldW, int oldH) {
            super.onSizeChanged(w, h, oldW, oldH);
            if (!ready) {
                for (int i = 0; i < 3; i++) {
                    bars[i].x = w * 0.5f;
                    bars[i].y = Math.max(dp(105), h * 0.35f) + (i - 1) * dp(75);
                }
                ready = true;
            } else {
                for (Bar b : bars) {
                    b.x += (w - oldW) * 0.5f;
                    b.y += (h - oldH) * 0.5f;
                }
            }
        }

        @Override
        protected void onDraw(Canvas c) {
            super.onDraw(c);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(1));
            paint.setColor(0x204a6688);
            for (int x = 0; x < getWidth(); x += dp(32))
                c.drawLine(x, 0, x, getHeight(), paint);
            for (int y = 0; y < getHeight(); y += dp(32))
                c.drawLine(0, y, getWidth(), y, paint);

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.WHITE);
            paint.setTextSize(dp(14));
            c.drawText("Peg Bar · Android interaction preview", dp(12), dp(30), paint);

            for (int i = 0; i < 3; i++) {
                if (!ghosts && i != 1) continue;
                Bar b = bars[i];
                c.save();
                c.translate(b.x, b.y);
                c.rotate(b.rotation);
                float half = Math.min(getWidth() * 0.38f, dp(175));
                paint.setColor((colors[i] & 0x00ffffff) |
                        ((i == selected ? 245 : i == 1 ? 195 : 100) << 24));
                c.drawRoundRect(new RectF(-half, -dp(16), half, dp(16)),
                        dp(7), dp(7), paint);
                paint.setColor(Color.rgb(22, 34, 50));
                c.drawCircle(-half * 0.68f, 0, dp(5), paint);
                c.drawCircle(half * 0.68f, 0, dp(5), paint);
                paint.setColor(Color.WHITE);
                c.drawCircle(0, 0, dp(4), paint);
                paint.setTextSize(dp(12));
                paint.setTextAlign(Paint.Align.CENTER);
                c.drawText(labels[i], 0, -dp(25), paint);
                paint.setTextAlign(Paint.Align.LEFT);
                c.restore();
            }
        }

        @Override
        public boolean onTouchEvent(MotionEvent e) {
            int act = e.getActionMasked();
            if (act == MotionEvent.ACTION_DOWN) {
                dragging = true;
                gestureStart = new Snapshot(bars);
                previousCount = e.getPointerCount();
                previousX = cx(e); previousY = cy(e); previousAngle = angle(e);
                return true;
            }
            if (act == MotionEvent.ACTION_POINTER_DOWN ||
                    act == MotionEvent.ACTION_POINTER_UP) {
                previousCount = 0; // Ignore first sample after changing finger count.
                return true;
            }
            if (act == MotionEvent.ACTION_MOVE && dragging) {
                int count = e.getPointerCount();
                float x = cx(e), y = cy(e), a = angle(e);
                if (count == previousCount) {
                    Bar b = bars[selected];
                    b.x += x - previousX;
                    b.y += y - previousY;
                    if (count >= 2) {
                        float delta = a - previousAngle;
                        while (delta > 180) delta -= 360;
                        while (delta < -180) delta += 360;
                        b.rotation += delta;
                    } else if ((e.getButtonState() &
                            MotionEvent.BUTTON_STYLUS_PRIMARY) != 0) {
                        b.rotation += (x - previousX) * 0.5f;
                    }
                    invalidate();
                }
                previousCount = count;
                previousX = x; previousY = y; previousAngle = a;
                return true;
            }
            if (act == MotionEvent.ACTION_UP || act == MotionEvent.ACTION_CANCEL) {
                if (dragging && gestureStart != null) {
                    if (act == MotionEvent.ACTION_CANCEL) gestureStart.apply(bars);
                    else if (gestureStart.differs(bars)) {
                        undo.addLast(gestureStart);
                        if (undo.size() > 100) undo.removeFirst();
                        redo.clear();
                    }
                }
                dragging = false; gestureStart = null;
                invalidate();
                return true;
            }
            return true;
        }

        private float cx(MotionEvent e) {
            float sum = 0;
            for (int i = 0; i < e.getPointerCount(); i++) sum += e.getX(i);
            return sum / Math.max(1, e.getPointerCount());
        }
        private float cy(MotionEvent e) {
            float sum = 0;
            for (int i = 0; i < e.getPointerCount(); i++) sum += e.getY(i);
            return sum / Math.max(1, e.getPointerCount());
        }
        private float angle(MotionEvent e) {
            if (e.getPointerCount() < 2) return 0;
            return (float) Math.toDegrees(Math.atan2(
                    e.getY(1) - e.getY(0), e.getX(1) - e.getX(0)));
        }

        void undo() {
            if (undo.isEmpty()) return;
            redo.addLast(new Snapshot(bars));
            undo.removeLast().apply(bars);
            invalidate();
        }
        void redo() {
            if (redo.isEmpty()) return;
            undo.addLast(new Snapshot(bars));
            redo.removeLast().apply(bars);
            invalidate();
        }
        void toggleGhosts() { ghosts = !ghosts; invalidate(); }
        void reset() {
            if (!ready) return;
            undo.addLast(new Snapshot(bars));
            redo.clear();
            for (int i = 0; i < 3; i++) {
                bars[i].x = getWidth() * 0.5f;
                bars[i].y = Math.max(dp(105), getHeight() * 0.35f)
                        + (i - 1) * dp(75);
                bars[i].rotation = 0;
            }
            invalidate();
        }
    }
}
