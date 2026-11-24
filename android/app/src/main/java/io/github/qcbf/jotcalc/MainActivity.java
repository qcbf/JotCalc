package io.github.qcbf.jotcalc;

import android.os.Build;
import androidx.core.view.WindowCompat;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    public void onPostResume() {
        super.onPostResume();
        // Flutter's edge-to-edge mode starts at Android 10.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                && Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        }
    }
}
